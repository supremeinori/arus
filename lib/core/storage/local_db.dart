import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart' as sql;
import 'package:path/path.dart' as p;
import '../../features/auth/domain/user_model.dart';
import '../../features/catalog/domain/category_model.dart';
import '../../features/catalog/domain/product_model.dart';
import '../../features/pos/domain/pos_models.dart';
import '../utils/money_formatter.dart';

final localDbProvider = Provider<LocalDatabase>((ref) {
  return LocalDatabase.instance;
});

class LocalSessionSettings {
  final String userId;
  final String name;
  final String email;
  final String role;
  final String? avatarUrl;
  final bool biometricEnabled;
  final String displayCurrency;
  final String displayTimezone;
  final bool shakeSensorEnabled;
  final bool tiltSensorEnabled;
  final String? userJson;
  final String? accessToken;
  final String? refreshToken;

  const LocalSessionSettings({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    this.avatarUrl,
    this.biometricEnabled = false,
    this.displayCurrency = MoneyFormatter.defaultCurrency,
    this.displayTimezone = 'WIB',
    this.shakeSensorEnabled = true,
    this.tiltSensorEnabled = true,
    this.userJson,
    this.accessToken,
    this.refreshToken,
  });

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'name': name,
      'email': email,
      'role': role,
      'avatar_url': avatarUrl,
      'biometric_enabled': biometricEnabled ? 1 : 0,
      'display_currency': displayCurrency,
      'display_timezone': displayTimezone,
      'shake_sensor_enabled': shakeSensorEnabled ? 1 : 0,
      'tilt_sensor_enabled': tiltSensorEnabled ? 1 : 0,
      'user_json': userJson,
      'access_token': accessToken,
      'refresh_token': refreshToken,
    };
  }

  factory LocalSessionSettings.fromMap(Map<String, dynamic> map) {
    return LocalSessionSettings(
      userId: map['user_id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      role: map['role'] as String? ?? 'staff',
      avatarUrl: map['avatar_url'] as String?,
      biometricEnabled: (map['biometric_enabled'] as int? ?? 0) == 1,
      displayCurrency:
          map['display_currency'] as String? ?? MoneyFormatter.defaultCurrency,
      displayTimezone: map['display_timezone'] as String? ?? 'WIB',
      shakeSensorEnabled: (map['shake_sensor_enabled'] as int? ?? 1) == 1,
      tiltSensorEnabled: (map['tilt_sensor_enabled'] as int? ?? 1) == 1,
      userJson: map['user_json'] as String?,
      accessToken: map['access_token'] as String?,
      refreshToken: map['refresh_token'] as String?,
    );
  }
}

class LocalDatabase {
  LocalDatabase._();
  static final LocalDatabase instance = LocalDatabase._();

  sql.Database? _db;
  final Map<String, Map<String, dynamic>> _webSessionStore = {};
  final List<Map<String, dynamic>> _webCategoriesStore = [];
  final List<Map<String, dynamic>> _webProductsStore = [];
  final List<Map<String, dynamic>> _webTransactionsStore = [];
  final List<Map<String, dynamic>> _webOfflineTxQueue = [];

  Future<sql.Database?> get database async {
    if (kIsWeb) return null;
    if (_db != null) return _db!;
    try {
      _db = await _initDatabase();
      return _db;
    } catch (_) {
      // Fallback in-memory jika di lingkungan headless flutter test
      return null;
    }
  }

  Future<sql.Database> _initDatabase() async {
    final dbPath = await sql.getDatabasesPath();
    final path = p.join(dbPath, 'arus_local.db');

    return await sql.openDatabase(
      path,
      version: 4,
      onCreate: (db, version) async {
        // 1. Sesi User & Pengaturan Utilitas
        await db.execute('''
          CREATE TABLE local_session_settings (
            user_id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            email TEXT NOT NULL,
            role TEXT NOT NULL,
            avatar_url TEXT,
            biometric_enabled INTEGER DEFAULT 0,
            display_currency TEXT DEFAULT 'IDR',
            display_timezone TEXT DEFAULT 'WIB',
            shake_sensor_enabled INTEGER DEFAULT 1,
            tilt_sensor_enabled INTEGER DEFAULT 1,
            user_json TEXT,
            access_token TEXT,
            refresh_token TEXT
          )
        ''');

        // 2. Kategori Produk Cache
        await db.execute('''
          CREATE TABLE cached_categories (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            product_count INTEGER DEFAULT 0,
            updated_at TEXT NOT NULL
          )
        ''');

        // 3. Produk & Stok Offline Cache
        await db.execute('''
          CREATE TABLE cached_products (
            id TEXT PRIMARY KEY,
            category_id TEXT,
            category_name TEXT,
            sku TEXT NOT NULL,
            name TEXT NOT NULL,
            unit TEXT DEFAULT 'pcs',
            price_idr INTEGER NOT NULL,
            cost_idr INTEGER,
            image_url TEXT,
            is_active INTEGER DEFAULT 1,
            estimated_portions INTEGER DEFAULT 0,
            stock_quantity INTEGER DEFAULT 0,
            raw_json TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');

        // 3b. Tabel Backup Produk & Estimasi Porsi (SRS Modul 2)
        await db.execute('''
          CREATE TABLE IF NOT EXISTS backup_products (
            product_id TEXT,
            outlet_id TEXT,
            sku TEXT NOT NULL,
            name TEXT NOT NULL,
            image_url TEXT,
            category_name TEXT,
            price_idr INTEGER NOT NULL,
            estimated_portions INTEGER NOT NULL,
            last_sync_at TEXT NOT NULL,
            PRIMARY KEY (product_id, outlet_id)
          )
        ''');

        // 4. Antrean Transaksi Offline (Pending Sync Queue)
        await db.execute('''
          CREATE TABLE offline_transactions (
            id TEXT PRIMARY KEY,
            client_request_id TEXT NOT NULL UNIQUE,
            outlet_id TEXT NOT NULL,
            cashier_name TEXT,
            payment_method TEXT NOT NULL,
            paid_idr INTEGER NOT NULL,
            discount_idr INTEGER DEFAULT 0,
            subtotal_idr INTEGER NOT NULL,
            total_idr INTEGER NOT NULL,
            change_idr INTEGER DEFAULT 0,
            items_json TEXT NOT NULL,
            receipt_no TEXT NOT NULL,
            created_at TEXT NOT NULL,
            is_synced INTEGER DEFAULT 0,
            sync_error TEXT
          )
        ''');

        // 5. Riwayat Struk Terakhir (Backup & Cache 50 transaksi)
        await db.execute('''
          CREATE TABLE backup_transactions (
            transaction_id TEXT PRIMARY KEY,
            receipt_no TEXT NOT NULL,
            outlet_name TEXT NOT NULL,
            total_idr INTEGER NOT NULL,
            payment_method TEXT NOT NULL,
            data_hash TEXT,
            block_hash TEXT,
            status TEXT DEFAULT 'completed',
            raw_json TEXT,
            created_at TEXT NOT NULL
          )
        ''');

        // 6. Cache Analitik Harian & Dashboard (Offline Daily Fallback)
        await db.execute('''
          CREATE TABLE IF NOT EXISTS daily_analytics_cache (
            cache_key TEXT PRIMARY KEY,
            payload TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute('ALTER TABLE local_session_settings ADD COLUMN user_json TEXT');
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE local_session_settings ADD COLUMN access_token TEXT');
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE local_session_settings ADD COLUMN refresh_token TEXT');
          } catch (_) {}

          await db.execute('''
            CREATE TABLE IF NOT EXISTS cached_categories (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              product_count INTEGER DEFAULT 0,
              updated_at TEXT NOT NULL
            )
          ''');

          await db.execute('''
            CREATE TABLE IF NOT EXISTS cached_products (
              id TEXT PRIMARY KEY,
              category_id TEXT,
              category_name TEXT,
              sku TEXT NOT NULL,
              name TEXT NOT NULL,
              unit TEXT DEFAULT 'pcs',
              price_idr INTEGER NOT NULL,
              cost_idr INTEGER,
              image_url TEXT,
              is_active INTEGER DEFAULT 1,
              stock_quantity INTEGER DEFAULT 0,
              raw_json TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');

          await db.execute('''
            CREATE TABLE IF NOT EXISTS offline_transactions (
              id TEXT PRIMARY KEY,
              client_request_id TEXT NOT NULL UNIQUE,
              outlet_id TEXT NOT NULL,
              cashier_name TEXT,
              payment_method TEXT NOT NULL,
              paid_idr INTEGER NOT NULL,
              discount_idr INTEGER DEFAULT 0,
              subtotal_idr INTEGER NOT NULL,
              total_idr INTEGER NOT NULL,
              change_idr INTEGER DEFAULT 0,
              items_json TEXT NOT NULL,
              receipt_no TEXT NOT NULL,
              created_at TEXT NOT NULL,
              is_synced INTEGER DEFAULT 0,
              sync_error TEXT
            )
          ''');
        }

        if (oldVersion < 3) {
          try {
            await db.execute("ALTER TABLE backup_transactions ADD COLUMN status TEXT DEFAULT 'completed'");
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE backup_transactions ADD COLUMN raw_json TEXT');
          } catch (_) {}
        }

        if (oldVersion < 4) {
          // Reset antrean transaksi offline lama, struk lama, dan cache lama agar transaksi yang sudah dihapus tidak muncul atau tersinkron kembali
          try {
            await db.delete('offline_transactions');
            await db.delete('backup_transactions');
            await db.delete('cached_categories');
            await db.delete('cached_products');
            await db.delete('backup_products');
            await db.delete('daily_analytics_cache');
            await db.delete('local_session_settings');
          } catch (_) {}
        }
      },
      onOpen: (db) async {
        // Defensive self-healing check: pastikan kolom status & raw_json selalu ada
        try {
          await db.execute("ALTER TABLE backup_transactions ADD COLUMN status TEXT DEFAULT 'completed'");
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE backup_transactions ADD COLUMN raw_json TEXT');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE local_session_settings ADD COLUMN user_json TEXT');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE local_session_settings ADD COLUMN access_token TEXT');
        } catch (_) {}
        try {
          await db.execute("ALTER TABLE cached_products ADD COLUMN estimated_portions INTEGER DEFAULT 0");
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE cached_products ADD COLUMN image_url TEXT');
        } catch (_) {}
        try {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS backup_products (
              product_id TEXT,
              outlet_id TEXT,
              sku TEXT NOT NULL,
              name TEXT NOT NULL,
              image_url TEXT,
              category_name TEXT,
              price_idr INTEGER NOT NULL,
              estimated_portions INTEGER NOT NULL,
              last_sync_at TEXT NOT NULL,
              PRIMARY KEY (product_id, outlet_id)
            )
          ''');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE local_session_settings ADD COLUMN refresh_token TEXT');
        } catch (_) {}
        try {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS daily_analytics_cache (
              cache_key TEXT PRIMARY KEY,
              payload TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
        } catch (_) {}
      },
    );
  }

  // ========================================================
  // 1. SESSION & USER OPERATIONS (OFFLINE LOGIN & RESTORE)
  // ========================================================
  Future<void> saveSessionSettings(LocalSessionSettings settings) async {
    final db = await database;
    if (db == null) {
      _webSessionStore[settings.userId] = settings.toMap();
      return;
    }

    await db.insert(
      'local_session_settings',
      settings.toMap(),
      conflictAlgorithm: sql.ConflictAlgorithm.replace,
    );
  }

  Future<void> saveUserSession({
    required UserModel user,
    required String accessToken,
    String? refreshToken,
  }) async {
    final userJson = jsonEncode(user.toJson());
    final settings = LocalSessionSettings(
      userId: user.id,
      name: user.name,
      email: user.email,
      role: user.role.name,
      avatarUrl: user.avatarUrl,
      biometricEnabled: user.settings.biometricEnabled,
      displayCurrency: user.settings.displayCurrency,
      displayTimezone: user.settings.displayTimezone,
      shakeSensorEnabled: user.settings.shakeRefreshEnabled,
      tiltSensorEnabled: user.settings.tiltEnabled,
      userJson: userJson,
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
    await saveSessionSettings(settings);
  }

  Future<LocalSessionSettings?> getSessionSettings(String userId) async {
    final db = await database;
    if (db == null) {
      final map = _webSessionStore[userId];
      return map != null ? LocalSessionSettings.fromMap(map) : null;
    }

    final maps = await db.query(
      'local_session_settings',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return LocalSessionSettings.fromMap(maps.first);
  }

  Future<LocalSessionSettings?> getLatestSessionSettings() async {
    final db = await database;
    if (db == null) {
      if (_webSessionStore.isEmpty) return null;
      return LocalSessionSettings.fromMap(_webSessionStore.values.last);
    }

    final maps = await db.query(
      'local_session_settings',
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return LocalSessionSettings.fromMap(maps.first);
  }

  Future<UserModel?> getCachedUser() async {
    final session = await getLatestSessionSettings();
    if (session?.userJson != null && session!.userJson!.isNotEmpty) {
      try {
        final decoded = jsonDecode(session.userJson!) as Map<String, dynamic>;
        final user = UserModel.fromJson(decoded);
        if (user.id.isNotEmpty && user.email.isNotEmpty && user.name.isNotEmpty) {
          return user;
        }
      } catch (_) {}
    }
    return null;
  }

  Future<void> updateBiometricSetting(String userId, bool enabled) async {
    final db = await database;
    if (db == null) {
      if (_webSessionStore.containsKey(userId)) {
        _webSessionStore[userId]!['biometric_enabled'] = enabled ? 1 : 0;
        final rawUser = _webSessionStore[userId]!['user_json'] as String?;
        if (rawUser != null) {
          try {
            final decoded = jsonDecode(rawUser) as Map<String, dynamic>;
            if (decoded['settings'] is Map) {
              decoded['settings']['biometric_enabled'] = enabled;
            } else {
              decoded['settings'] = {'biometric_enabled': enabled};
            }
            _webSessionStore[userId]!['user_json'] = jsonEncode(decoded);
          } catch (_) {}
        }
      }
      return;
    }

    await db.update(
      'local_session_settings',
      {'biometric_enabled': enabled ? 1 : 0},
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    try {
      final maps = await db.query(
        'local_session_settings',
        columns: ['user_json'],
        where: 'user_id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      if (maps.isNotEmpty && maps.first['user_json'] != null) {
        final decoded = jsonDecode(maps.first['user_json'] as String) as Map<String, dynamic>;
        if (decoded['settings'] is Map) {
          decoded['settings']['biometric_enabled'] = enabled;
        } else {
          decoded['settings'] = {'biometric_enabled': enabled};
        }
        await db.update(
          'local_session_settings',
          {'user_json': jsonEncode(decoded)},
          where: 'user_id = ?',
          whereArgs: [userId],
        );
      }
    } catch (_) {}
  }

  /// Simpan preferensi mata uang tampilan untuk [userId] di cache lokal.
  ///
  /// Cache lokal hanyaCadangan offline; sumber kebenaran tetap kolom
  /// `User.display_currency` di server.
  Future<void> updateDisplayCurrencySetting(String userId, String currency) async {
    final db = await database;
    if (db == null) {
      if (_webSessionStore.containsKey(userId)) {
        final rawUser = _webSessionStore[userId]!['user_json'] as String?;
        if (rawUser != null) {
          try {
            final decoded = jsonDecode(rawUser) as Map<String, dynamic>;
            if (decoded['settings'] is Map) {
              decoded['settings']['display_currency'] = currency;
            } else {
              decoded['settings'] = {'display_currency': currency};
            }
            _webSessionStore[userId]!['user_json'] = jsonEncode(decoded);
          } catch (_) {}
        }
      }
      return;
    }

    try {
      final maps = await db.query(
        'local_session_settings',
        columns: ['user_json'],
        where: 'user_id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      if (maps.isNotEmpty && maps.first['user_json'] != null) {
        final decoded =
            jsonDecode(maps.first['user_json'] as String) as Map<String, dynamic>;
        if (decoded['settings'] is Map) {
          decoded['settings']['display_currency'] = currency;
        } else {
          decoded['settings'] = {'display_currency': currency};
        }
        await db.update(
          'local_session_settings',
          {'user_json': jsonEncode(decoded)},
          where: 'user_id = ?',
          whereArgs: [userId],
        );
      }
    } catch (_) {}
  }

  Future<void> clearLocalDatabase() async {
    final db = await database;
    _webSessionStore.clear();
    _webCategoriesStore.clear();
    _webProductsStore.clear();
    _webTransactionsStore.clear();
    _webOfflineTxQueue.clear();
    _webDailyAnalyticsCache.clear();
    if (db != null) {
      try {
        await db.delete('local_session_settings');
        await db.delete('cached_categories');
        await db.delete('cached_products');
        await db.delete('backup_products');
        await db.delete('offline_transactions');
        await db.delete('backup_transactions');
        await db.delete('daily_analytics_cache');
      } catch (_) {}
    }
  }

  Future<void> clearSession([String? userId]) async {
    final db = await database;
    if (db == null) {
      _webSessionStore.clear();
      return;
    }

    if (userId != null && userId.isNotEmpty) {
      await db.delete(
        'local_session_settings',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
    } else {
      await db.delete('local_session_settings');
    }
  }

  // ========================================================
  // 2. CATEGORIES CACHE OPERATIONS
  // ========================================================
  Future<void> cacheCategories(List<CategoryModel> categories) async {
    final db = await database;
    if (db == null) {
      _webCategoriesStore.clear();
      for (final c in categories) {
        _webCategoriesStore.add(c.toJson());
      }
      return;
    }

    final batch = db.batch();
    final now = DateTime.now().toIso8601String();
    for (final c in categories) {
      batch.insert(
        'cached_categories',
        {
          'id': c.id,
          'name': c.name,
          'product_count': c.productCount,
          'updated_at': now,
        },
        conflictAlgorithm: sql.ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<CategoryModel>> getCachedCategories() async {
    final db = await database;
    if (db == null) {
      return _webCategoriesStore.map((c) => CategoryModel.fromJson(c)).toList();
    }

    final rows = await db.query('cached_categories', orderBy: 'name ASC');
    return rows.map((r) => CategoryModel(
      id: r['id'] as String,
      name: r['name'] as String,
      productCount: r['product_count'] as int? ?? 0,
    )).toList();
  }

  // ========================================================
  // 3. PRODUCTS CACHE OPERATIONS
  // ========================================================
  Future<void> cacheProducts(List<ProductModel> products) async {
    final db = await database;
    if (db == null) {
      _webProductsStore.clear();
      for (final p in products) {
        _webProductsStore.add(p.toJson());
      }
      return;
    }

    final batch = db.batch();
    final now = DateTime.now().toIso8601String();
    for (final p in products) {
      final totalStock = p.estimatedPortions > 0 
          ? p.estimatedPortions 
          : p.outletStock.fold<int>(0, (sum, s) => sum + s.quantity);

      batch.insert(
        'cached_products',
        {
          'id': p.id,
          'category_id': p.categoryId,
          'category_name': p.categoryName,
          'sku': p.sku,
          'name': p.name,
          'unit': p.unit,
          'price_idr': p.priceIdr,
          'cost_idr': p.costIdr,
          'image_url': p.imageUrl,
          'is_active': p.isActive ? 1 : 0,
          'estimated_portions': p.estimatedPortions,
          'stock_quantity': totalStock,
          'raw_json': jsonEncode(p.toJson()),
          'updated_at': now,
        },
        conflictAlgorithm: sql.ConflictAlgorithm.replace,
      );

      batch.insert(
        'backup_products',
        {
          'product_id': p.id,
          'outlet_id': 'default',
          'sku': p.sku,
          'name': p.name,
          'image_url': p.imageUrl,
          'category_name': p.categoryName,
          'price_idr': p.priceIdr,
          'estimated_portions': p.estimatedPortions,
          'last_sync_at': now,
        },
        conflictAlgorithm: sql.ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> cacheSingleProduct(ProductModel product) async {
    final db = await database;
    if (db == null) {
      final idx = _webProductsStore.indexWhere((p) => p['id'] == product.id);
      if (idx >= 0) {
        _webProductsStore[idx] = product.toJson();
      } else {
        _webProductsStore.insert(0, product.toJson());
      }
      return;
    }

    final totalStock = product.estimatedPortions > 0
        ? product.estimatedPortions
        : product.outletStock.fold<int>(0, (sum, s) => sum + s.quantity);

    await db.insert(
      'cached_products',
      {
        'id': product.id,
        'category_id': product.categoryId,
        'category_name': product.categoryName,
        'sku': product.sku,
        'name': product.name,
        'unit': product.unit,
        'price_idr': product.priceIdr,
        'cost_idr': product.costIdr,
        'image_url': product.imageUrl,
        'is_active': product.isActive ? 1 : 0,
        'estimated_portions': product.estimatedPortions,
        'stock_quantity': totalStock,
        'raw_json': jsonEncode(product.toJson()),
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: sql.ConflictAlgorithm.replace,
    );

    try {
      await db.insert(
        'backup_products',
        {
          'product_id': product.id,
          'outlet_id': 'default',
          'sku': product.sku,
          'name': product.name,
          'image_url': product.imageUrl,
          'category_name': product.categoryName,
          'price_idr': product.priceIdr,
          'estimated_portions': product.estimatedPortions,
          'last_sync_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: sql.ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  Future<List<ProductModel>> getCachedProducts({String? categoryId, String? search}) async {
    final db = await database;
    if (db == null) {
      var list = _webProductsStore.map((p) => ProductModel.fromJson(p)).toList();
      if (categoryId != null && categoryId.isNotEmpty) {
        list = list.where((p) => p.categoryId == categoryId).toList();
      }
      if (search != null && search.trim().isNotEmpty) {
        final q = search.trim().toLowerCase();
        list = list.where((p) => p.name.toLowerCase().contains(q) || p.sku.toLowerCase().contains(q)).toList();
      }
      return list;
    }

    String? where;
    List<dynamic>? whereArgs;

    if (categoryId != null && categoryId.isNotEmpty && search != null && search.trim().isNotEmpty) {
      where = 'category_id = ? AND (name LIKE ? OR sku LIKE ?)';
      whereArgs = [categoryId, '%${search.trim()}%', '%${search.trim()}%'];
    } else if (categoryId != null && categoryId.isNotEmpty) {
      where = 'category_id = ?';
      whereArgs = [categoryId];
    } else if (search != null && search.trim().isNotEmpty) {
      where = 'name LIKE ? OR sku LIKE ?';
      whereArgs = ['%${search.trim()}%', '%${search.trim()}%'];
    }

    final rows = await db.query('cached_products', where: where, whereArgs: whereArgs, orderBy: 'name ASC');
    final products = <ProductModel>[];
    for (final r in rows) {
      try {
        final rawJson = r['raw_json'] as String?;
        if (rawJson != null && rawJson.isNotEmpty) {
          products.add(ProductModel.fromJson(jsonDecode(rawJson) as Map<String, dynamic>));
        } else {
          products.add(ProductModel(
            id: r['id'] as String,
            sku: r['sku'] as String,
            name: r['name'] as String,
            unit: r['unit'] as String? ?? 'pcs',
            priceIdr: r['price_idr'] as int? ?? 0,
            costIdr: r['cost_idr'] as int?,
            categoryId: r['category_id'] as String?,
            categoryName: r['category_name'] as String?,
            imageUrl: r['image_url'] as String?,
            isActive: (r['is_active'] as int? ?? 1) == 1,
            outletStock: [
              ProductOutletStock(
                outletId: 'local',
                outletName: 'Lokal',
                quantity: r['stock_quantity'] as int? ?? 0,
              )
            ],
          ));
        }
      } catch (_) {}
    }
    return products;
  }

  Future<void> decrementLocalStock(String productId, int quantity) async {
    final db = await database;
    if (db == null) {
      final idx = _webProductsStore.indexWhere((p) => p['id'] == productId);
      if (idx >= 0) {
        final curPortions = _webProductsStore[idx]['estimated_portions'] as int? ?? 0;
        final curStock = _webProductsStore[idx]['stock_quantity'] as int? ?? 0;
        final newPortions = curPortions > quantity ? curPortions - quantity : 0;
        final newStock = curStock > quantity ? curStock - quantity : 0;
        _webProductsStore[idx]['estimated_portions'] = newPortions;
        _webProductsStore[idx]['stock_quantity'] = newStock;
        if (_webProductsStore[idx]['inventory'] is List && (_webProductsStore[idx]['inventory'] as List).isNotEmpty) {
          (_webProductsStore[idx]['inventory'] as List).first['quantity'] = newPortions;
        }
      }
      return;
    }

    await db.rawUpdate('''
      UPDATE cached_products 
      SET estimated_portions = MAX(0, estimated_portions - ?),
          stock_quantity = MAX(0, stock_quantity - ?) 
      WHERE id = ?
    ''', [quantity, quantity, productId]);

    try {
      await db.rawUpdate('''
        UPDATE backup_products
        SET estimated_portions = MAX(0, estimated_portions - ?)
        WHERE product_id = ?
      ''', [quantity, productId]);
    } catch (_) {}
  }

  // ========================================================
  // 4. OFFLINE TRANSACTIONS & SYNC QUEUE OPERATIONS
  // ========================================================
  Future<void> saveOfflineTransaction({
    required PosTransactionModel transaction,
    required String clientRequestId,
    bool isSynced = false,
  }) async {
    final itemsJson = jsonEncode(transaction.items.map((i) => i.toJson()).toList());
    final db = await database;

    if (db == null) {
      _webOfflineTxQueue.add({
        'id': transaction.id,
        'client_request_id': clientRequestId,
        'outlet_id': transaction.outletId,
        'cashier_name': transaction.cashierName,
        'payment_method': transaction.paymentMethod,
        'paid_idr': transaction.paidIdr,
        'discount_idr': transaction.discountIdr,
        'subtotal_idr': transaction.subtotalIdr,
        'total_idr': transaction.totalIdr,
        'change_idr': transaction.changeIdr,
        'items_json': itemsJson,
        'receipt_no': transaction.receiptNo,
        'created_at': transaction.createdAt.toIso8601String(),
        'is_synced': isSynced ? 1 : 0,
      });
      for (final item in transaction.items) {
        await decrementLocalStock(item.productId, item.quantity);
      }
      await backupTransaction({
        'transaction_id': transaction.id,
        'receipt_no': transaction.receiptNo,
        'outlet_name': transaction.outletName,
        'total_idr': transaction.totalIdr,
        'payment_method': transaction.paymentMethod,
        'status': isSynced ? 'completed' : 'offline_pending',
        'raw_json': jsonEncode(transaction.toJson()),
        'created_at': transaction.createdAt.toIso8601String(),
      });
      return;
    }

    await db.insert(
      'offline_transactions',
      {
        'id': transaction.id,
        'client_request_id': clientRequestId,
        'outlet_id': transaction.outletId,
        'cashier_name': transaction.cashierName,
        'payment_method': transaction.paymentMethod,
        'paid_idr': transaction.paidIdr,
        'discount_idr': transaction.discountIdr,
        'subtotal_idr': transaction.subtotalIdr,
        'total_idr': transaction.totalIdr,
        'change_idr': transaction.changeIdr,
        'items_json': itemsJson,
        'receipt_no': transaction.receiptNo,
        'created_at': transaction.createdAt.toIso8601String(),
        'is_synced': isSynced ? 1 : 0,
      },
      conflictAlgorithm: sql.ConflictAlgorithm.replace,
    );

    // Also decrement local stock for each purchased item
    for (final item in transaction.items) {
      await decrementLocalStock(item.productId, item.quantity);
    }

    // Mirror to backup_transactions cache
    await backupTransaction({
      'transaction_id': transaction.id,
      'receipt_no': transaction.receiptNo,
      'outlet_name': transaction.outletName,
      'total_idr': transaction.totalIdr,
      'payment_method': transaction.paymentMethod,
      'status': isSynced ? 'completed' : 'offline_pending',
      'raw_json': jsonEncode(transaction.toJson()),
      'created_at': transaction.createdAt.toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getPendingOfflineTransactions() async {
    final db = await database;
    if (db == null) {
      return _webOfflineTxQueue.where((tx) => tx['is_synced'] == 0).toList();
    }

    return await db.query(
      'offline_transactions',
      where: 'is_synced = ?',
      whereArgs: [0],
      orderBy: 'created_at ASC',
    );
  }

  Future<void> markTransactionSynced({
    required String clientRequestId,
    required String serverReceiptNo,
    String? dataHash,
    String? blockHash,
  }) async {
    final db = await database;
    if (db == null) {
      final item = _webOfflineTxQueue.firstWhere(
        (tx) => tx['client_request_id'] == clientRequestId,
        orElse: () => {},
      );
      if (item.isNotEmpty) {
        item['is_synced'] = 1;
        item['receipt_no'] = serverReceiptNo;
      }
      return;
    }

    await db.update(
      'offline_transactions',
      {
        'is_synced': 1,
        'receipt_no': serverReceiptNo,
        'sync_error': null,
      },
      where: 'client_request_id = ?',
      whereArgs: [clientRequestId],
    );

    // Update backup_transactions
    await db.update(
      'backup_transactions',
      {
        'receipt_no': serverReceiptNo,
        'data_hash': dataHash,
        'block_hash': blockHash,
        'status': 'completed',
      },
      where: 'transaction_id = ? OR receipt_no = ?',
      whereArgs: [clientRequestId, serverReceiptNo],
    );
  }

  Future<void> markTransactionSyncError(String clientRequestId, String error) async {
    final db = await database;
    if (db == null) {
      final item = _webOfflineTxQueue.firstWhere(
        (tx) => tx['client_request_id'] == clientRequestId,
        orElse: () => {},
      );
      if (item.isNotEmpty) {
        item['sync_error'] = error;
      }
      return;
    }

    await db.update(
      'offline_transactions',
      {'sync_error': error},
      where: 'client_request_id = ?',
      whereArgs: [clientRequestId],
    );
  }

  // ========================================================
  // 5. BACKUP TRANSACTIONS (RECEIPT CACHE - LATEST 50)
  // ========================================================
  Future<void> backupTransaction(Map<String, dynamic> tx) async {
    final db = await database;
    if (db == null) {
      _webTransactionsStore.insert(0, tx);
      if (_webTransactionsStore.length > 50) {
        _webTransactionsStore.removeLast();
      }
      return;
    }

    await db.insert(
      'backup_transactions',
      tx,
      conflictAlgorithm: sql.ConflictAlgorithm.replace,
    );

    await db.execute('''
      DELETE FROM backup_transactions WHERE transaction_id NOT IN (
        SELECT transaction_id FROM backup_transactions ORDER BY created_at DESC LIMIT 50
      )
    ''');
  }

  Future<List<PosTransactionModel>> getBackupTransactions({String? outletId}) async {
    final db = await database;
    if (db == null) {
      var list = _webTransactionsStore.map((m) {
        if (m['raw_json'] != null) {
          return PosTransactionModel.fromJson(jsonDecode(m['raw_json'] as String));
        }
        return PosTransactionModel(
          id: m['transaction_id'] as String? ?? '',
          receiptNo: m['receipt_no'] as String? ?? '',
          outletId: '',
          outletName: m['outlet_name'] as String? ?? 'Outlet',
          cashierName: 'Kasir',
          subtotalIdr: m['total_idr'] as int? ?? 0,
          discountIdr: 0,
          totalIdr: m['total_idr'] as int? ?? 0,
          paymentMethod: m['payment_method'] as String? ?? 'cash',
          paidIdr: m['total_idr'] as int? ?? 0,
          changeIdr: 0,
          status: m['status'] as String? ?? 'completed',
          createdAt: DateTime.tryParse(m['created_at'] as String? ?? '') ?? DateTime.now(),
        );
      }).toList();
      if (outletId != null && outletId.isNotEmpty) {
        list = list.where((tx) => tx.outletId.isEmpty || tx.outletId == outletId).toList();
      }
      return list;
    }

    final rows = await db.query(
      'backup_transactions',
      orderBy: 'created_at DESC',
      limit: 50,
    );

    final result = <PosTransactionModel>[];
    for (final r in rows) {
      try {
        final raw = r['raw_json'] as String?;
        if (raw != null && raw.isNotEmpty) {
          final model = PosTransactionModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
          result.add(model);
        } else {
          result.add(PosTransactionModel(
            id: r['transaction_id'] as String? ?? '',
            receiptNo: r['receipt_no'] as String? ?? '',
            outletId: '',
            outletName: r['outlet_name'] as String? ?? 'Outlet',
            cashierName: 'Kasir',
            subtotalIdr: r['total_idr'] as int? ?? 0,
            discountIdr: 0,
            totalIdr: r['total_idr'] as int? ?? 0,
            paymentMethod: r['payment_method'] as String? ?? 'cash',
            paidIdr: r['total_idr'] as int? ?? 0,
            changeIdr: 0,
            status: r['status'] as String? ?? 'completed',
            createdAt: DateTime.tryParse(r['created_at'] as String? ?? '') ?? DateTime.now(),
          ));
        }
      } catch (_) {}
    }
    if (outletId != null && outletId.isNotEmpty) {
      return result.where((tx) => tx.outletId.isEmpty || tx.outletId == outletId).toList();
    }
    return result;
  }

  // ========================================================
  // 6. DAILY ANALYTICS & DASHBOARD CACHE (OFFLINE FALLBACK)
  // ========================================================
  final Map<String, Map<String, dynamic>> _webDailyAnalyticsCache = {};

  Future<void> saveDailyAnalyticsCache({
    required String cacheKey,
    required String payload,
  }) async {
    final now = DateTime.now().toIso8601String();
    final db = await database;
    if (db == null) {
      _webDailyAnalyticsCache[cacheKey] = {
        'cache_key': cacheKey,
        'payload': payload,
        'updated_at': now,
      };
      return;
    }

    await db.insert(
      'daily_analytics_cache',
      {
        'cache_key': cacheKey,
        'payload': payload,
        'updated_at': now,
      },
      conflictAlgorithm: sql.ConflictAlgorithm.replace,
    );
  }

  Future<String?> getDailyAnalyticsCache(String cacheKey) async {
    final db = await database;
    if (db == null) {
      return _webDailyAnalyticsCache[cacheKey]?['payload'] as String?;
    }

    final rows = await db.query(
      'daily_analytics_cache',
      where: 'cache_key = ?',
      whereArgs: [cacheKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['payload'] as String?;
  }
}
