import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart' as sql;
import 'package:path/path.dart' as p;

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

  const LocalSessionSettings({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    this.avatarUrl,
    this.biometricEnabled = false,
    this.displayCurrency = 'IDR',
    this.displayTimezone = 'WIB',
    this.shakeSensorEnabled = true,
    this.tiltSensorEnabled = true,
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
      displayCurrency: map['display_currency'] as String? ?? 'IDR',
      displayTimezone: map['display_timezone'] as String? ?? 'WIB',
      shakeSensorEnabled: (map['shake_sensor_enabled'] as int? ?? 1) == 1,
      tiltSensorEnabled: (map['tilt_sensor_enabled'] as int? ?? 1) == 1,
    );
  }
}

class LocalDatabase {
  LocalDatabase._();
  static final LocalDatabase instance = LocalDatabase._();

  sql.Database? _db;
  final Map<String, Map<String, dynamic>> _webSessionStore = {};
  final List<Map<String, dynamic>> _webProductsStore = [];
  final List<Map<String, dynamic>> _webTransactionsStore = [];

  Future<sql.Database?> get database async {
    if (kIsWeb) return null;
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db;
  }

  Future<sql.Database> _initDatabase() async {
    final dbPath = await sql.getDatabasesPath();
    final path = p.join(dbPath, 'arus_local.db');

    return await sql.openDatabase(
      path,
      version: 1,
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
            tilt_sensor_enabled INTEGER DEFAULT 1
          )
        ''');

        // 2. Backup Produk & Stok Offline
        await db.execute('''
          CREATE TABLE backup_products (
            product_id TEXT,
            outlet_id TEXT,
            sku TEXT NOT NULL,
            name TEXT NOT NULL,
            category_name TEXT,
            price_idr INTEGER NOT NULL,
            stock_quantity INTEGER NOT NULL,
            reorder_level INTEGER NOT NULL,
            last_sync_at TEXT NOT NULL,
            PRIMARY KEY (product_id, outlet_id)
          )
        ''');

        // 3. Backup 50 Struk Terakhir & Blockchain
        await db.execute('''
          CREATE TABLE backup_transactions (
            transaction_id TEXT PRIMARY KEY,
            receipt_no TEXT NOT NULL,
            outlet_name TEXT NOT NULL,
            total_idr INTEGER NOT NULL,
            payment_method TEXT NOT NULL,
            data_hash TEXT,
            block_hash TEXT,
            created_at TEXT NOT NULL
          )
        ''');
      },
    );
  }

  // --- Session & Settings Operations ---
  Future<void> saveSessionSettings(LocalSessionSettings settings) async {
    if (kIsWeb) {
      _webSessionStore[settings.userId] = settings.toMap();
      return;
    }

    final db = await database;
    if (db == null) return;

    await db.insert(
      'local_session_settings',
      settings.toMap(),
      conflictAlgorithm: sql.ConflictAlgorithm.replace,
    );
  }

  Future<LocalSessionSettings?> getSessionSettings(String userId) async {
    if (kIsWeb) {
      final map = _webSessionStore[userId];
      return map != null ? LocalSessionSettings.fromMap(map) : null;
    }

    final db = await database;
    if (db == null) return null;

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
    if (kIsWeb) {
      if (_webSessionStore.isEmpty) return null;
      return LocalSessionSettings.fromMap(_webSessionStore.values.last);
    }

    final db = await database;
    if (db == null) return null;

    final maps = await db.query(
      'local_session_settings',
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return LocalSessionSettings.fromMap(maps.first);
  }

  Future<void> updateBiometricSetting(String userId, bool enabled) async {
    if (kIsWeb) {
      if (_webSessionStore.containsKey(userId)) {
        _webSessionStore[userId]!['biometric_enabled'] = enabled ? 1 : 0;
      }
      return;
    }

    final db = await database;
    if (db == null) return;

    await db.update(
      'local_session_settings',
      {'biometric_enabled': enabled ? 1 : 0},
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  Future<void> clearSession(String userId) async {
    if (kIsWeb) {
      _webSessionStore.remove(userId);
      return;
    }

    final db = await database;
    if (db == null) return;

    await db.delete(
      'local_session_settings',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  // --- Backup Products Operations ---
  Future<void> backupProducts(List<Map<String, dynamic>> products) async {
    if (kIsWeb) {
      _webProductsStore.clear();
      _webProductsStore.addAll(products);
      return;
    }

    final db = await database;
    if (db == null) return;

    final batch = db.batch();
    for (final prod in products) {
      batch.insert(
        'backup_products',
        prod,
        conflictAlgorithm: sql.ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getBackupProducts({String? outletId}) async {
    if (kIsWeb) {
      if (outletId == null) return _webProductsStore;
      return _webProductsStore.where((p) => p['outlet_id'] == outletId).toList();
    }

    final db = await database;
    if (db == null) return [];

    return await db.query(
      'backup_products',
      where: outletId != null ? 'outlet_id = ?' : null,
      whereArgs: outletId != null ? [outletId] : null,
    );
  }

  // --- Backup Transactions Operations ---
  Future<void> backupTransaction(Map<String, dynamic> tx) async {
    if (kIsWeb) {
      _webTransactionsStore.insert(0, tx);
      if (_webTransactionsStore.length > 50) {
        _webTransactionsStore.removeLast();
      }
      return;
    }

    final db = await database;
    if (db == null) return;

    await db.insert(
      'backup_transactions',
      tx,
      conflictAlgorithm: sql.ConflictAlgorithm.replace,
    );

    // Keep only latest 50 records per specification
    await db.execute('''
      DELETE FROM backup_transactions WHERE transaction_id NOT IN (
        SELECT transaction_id FROM backup_transactions ORDER BY created_at DESC LIMIT 50
      )
    ''');
  }

  Future<List<Map<String, dynamic>>> getBackupTransactions() async {
    if (kIsWeb) return _webTransactionsStore;

    final db = await database;
    if (db == null) return [];

    return await db.query(
      'backup_transactions',
      orderBy: 'created_at DESC',
      limit: 50,
    );
  }
}
