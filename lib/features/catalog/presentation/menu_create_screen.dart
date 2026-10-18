import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../ai_assistant/data/ai_repository.dart';
import '../../inventory/domain/inventory_models.dart';
import '../../inventory/presentation/inventory_provider.dart';
import '../../shell/presentation/main_shell.dart';
import '../data/catalog_repository.dart';
import 'catalog_provider.dart';

/// Satu baris builder resep: dropdown bahan + input takaran.
class _RecipeRow {
  String? ingredientId;
  final TextEditingController amountController = TextEditingController();

  void dispose() => amountController.dispose();
}

/// Layar "Tambah Menu Baru" — slice terisolasi untuk flow:
/// Step 1 info dasar → Step 2 builder resep dinamis →
/// Step 3 HPP live → Step 4 rekomendasi harga (30/50/100% & AI).
class MenuCreateScreen extends ConsumerStatefulWidget {
  const MenuCreateScreen({super.key});

  @override
  ConsumerState<MenuCreateScreen> createState() => _MenuCreateScreenState();
}

class _MenuCreateScreenState extends ConsumerState<MenuCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final List<_RecipeRow> _rows = [_RecipeRow()];

  String? _categoryId;
  bool _saving = false;
  String? _error;

  // State Rekomendasi Harga AI
  bool _aiLoading = false;
  int? _aiRecommendedPrice;
  int? _aiMarginPercentage;
  String? _aiReasoning;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _skuCtrl.dispose();
    _priceCtrl.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  /// Step 3: HPP live = SUM(amount_needed * cost_per_unit).
  int _calcHpp(List<IngredientModel> ingredients) {
    var total = 0;
    for (final row in _rows) {
      if (row.ingredientId == null) continue;
      final amt = int.tryParse(row.amountController.text.trim()) ?? 0;
      if (amt <= 0) continue;
      IngredientModel? ing;
      for (final e in ingredients) {
        if (e.id == row.ingredientId) {
          ing = e;
          break;
        }
      }
      if (ing == null) continue;
      total += amt * ing.costPerUnit;
    }
    return total;
  }

  /// Step 4: harga jual = modal + margin%.
  int _priceFor(int hpp, int marginPct) => (hpp * (100 + marginPct) / 100).round();

  /// Panggil API Backend POST /api/ai/recommend-price
  Future<void> _fetchAiRecommendation(int hpp) async {
    final menuName = _nameCtrl.text.trim();
    if (menuName.isEmpty) {
      setState(() => _error = 'Isi Nama Menu terlebih dahulu untuk rekomendasi AI.');
      return;
    }

    final recipes = <Map<String, dynamic>>[];
    for (final r in _rows) {
      final amt = int.tryParse(r.amountController.text.trim()) ?? 0;
      if (r.ingredientId != null && amt > 0) {
        recipes.add({'ingredient_id': r.ingredientId!, 'amount_needed': amt});
      }
    }

    setState(() {
      _aiLoading = true;
      _error = null;
    });

    try {
      final aiRepo = ref.read(aiRepositoryProvider);
      final result = await aiRepo.recommendPrice(
        menuName: menuName,
        totalCogsIdr: hpp,
        recipes: recipes,
      );

      if (mounted) {
        setState(() {
          _aiLoading = false;
          _aiRecommendedPrice = result.recommendedPrice;
          _aiMarginPercentage = result.marginPercentage;
          _aiReasoning = result.reasoning;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiLoading = false;
          _error = 'Gagal mengambil rekomendasi AI: $e';
        });
      }
    }
  }

  /// Pindah ke AI Chat dengan konteks bawaan (Passing Context & Navigation)
  void _navigateToAiChat(int hpp) {
    final menuName = _nameCtrl.text.trim().isEmpty ? 'Menu Baru' : _nameCtrl.text.trim();
    final recPrice = _aiRecommendedPrice ?? _priceFor(hpp, 50);

    final promptText =
        'Saya sedang membuat produk baru bernama $menuName dengan HPP ${MoneyFormatter.format(hpp)}. '
        'Tadi kamu merekomendasikan harga ${MoneyFormatter.format(recPrice)}. '
        'Tolong berikan simulasi detail BEP atau analisis lebih lanjut mengenai harga ini.';

    // Panggil Global AI Companion Bottom Sheet tanpa merusak state form di belakangnya
    showAiCompanionBottomSheet(context, ref, initialPrompt: promptText);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final recipes = <Map<String, dynamic>>[];
    for (final r in _rows) {
      final amt = int.tryParse(r.amountController.text.trim()) ?? 0;
      if (r.ingredientId != null && amt > 0) {
        recipes.add({'ingredient_id': r.ingredientId!, 'amount_needed': amt});
      }
    }
    if (recipes.isEmpty) {
      setState(() => _error = 'Tambahkan minimal 1 bahan baku dengan takaran > 0.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref.read(catalogRepositoryProvider).createProduct(
            name: _nameCtrl.text.trim(),
            sku: _skuCtrl.text.trim(),
            priceIdr: int.parse(_priceCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')),
            categoryId: _categoryId,
            recipes: recipes,
          );
      ref.invalidate(productListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.textPrimaryDark,
            content: Text(
              'Menu baru + resep tersimpan!',
              style: GoogleFonts.lexend(color: Colors.white, fontSize: 13),
            ),
          ),
        );
        context.pop();
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesState = ref.watch(categoriesProvider);
    final ingredientsState = ref.watch(ingredientsListProvider);

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: Text(
          'Tambah Menu Baru',
          style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0x22EF4444),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFEF4444), width: 1.0),
                  ),
                  child: Text(
                    _error!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.lexend(color: const Color(0xFFF87171), fontSize: 12.5),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ---------- Step 1: Info dasar ----------
              Text('Step 1 — Info Dasar',
                  style: GoogleFonts.lexend(fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameCtrl,
                style: GoogleFonts.lexend(fontSize: 14),
                decoration: const InputDecoration(
                  labelText: 'Nama Menu *',
                  hintText: 'Contoh: Es Kopi Susu Aren',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Nama menu wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _skuCtrl,
                style: GoogleFonts.lexend(fontSize: 14),
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'SKU *',
                  hintText: 'MNM-001',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'SKU wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              AsyncStateView(
                value: categoriesState,
                dataBuilder: (categories) => DropdownButtonFormField<String>(
                  initialValue: _categoryId,
                  dropdownColor: AppTheme.darkCardSurface,
                  decoration: const InputDecoration(
                    labelText: 'Kategori (opsional)',
                    border: OutlineInputBorder(),
                  ),
                  items: categories
                      .map((c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(
                              c.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.lexend(fontSize: 14),
                            ),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _categoryId = v),
                ),
              ),
              const SizedBox(height: 20),

              // ---------- Step 2: Builder resep dinamis ----------
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Step 2 — Resep',
                      style: GoogleFonts.lexend(fontSize: 14, fontWeight: FontWeight.w700)),
                  TextButton.icon(
                    onPressed: () => setState(() => _rows.add(_RecipeRow())),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('(+) Tambah Bahan Baku'),
                  ),
                ],
              ),
              Text(
                'Takaran bahan baku per 1 porsi pesanan',
                style: GoogleFonts.lexend(fontSize: 11.5, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 8),
              AsyncStateView(
                value: ingredientsState,
                dataBuilder: (ingredients) => Column(
                  children: [
                    for (var i = 0; i < _rows.length; i++) ...[
                      Builder(
                        builder: (_) {
                          final row = _rows[i];
                          IngredientModel? selected;
                          for (final e in ingredients) {
                            if (e.id == row.ingredientId) {
                              selected = e;
                              break;
                            }
                          }
                          return Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.darkCardSurfaceElevated,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.darkCardBorder),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: DropdownButtonFormField<String>(
                                    dropdownColor: AppTheme.darkCardSurface,
                                    isExpanded: true,
                                    initialValue: row.ingredientId != null &&
                                            ingredients.any((e) => e.id == row.ingredientId)
                                        ? row.ingredientId
                                        : null,
                                    decoration: const InputDecoration(
                                      labelText: 'Bahan baku',
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                    ),
                                    items: ingredients
                                        .map((g) => DropdownMenuItem(
                                              value: g.id,
                                              child: Text(
                                                '${g.name} (${MoneyFormatter.format(g.costPerUnit)}/${g.unit})',
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.lexend(fontSize: 12.5),
                                              ),
                                            ))
                                        .toList(),
                                    onChanged: (v) => setState(() => row.ingredientId = v),
                                    validator: (_) => row.ingredientId == null
                                        ? 'Pilih bahan'
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: row.amountController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    onChanged: (_) => setState(() {}),
                                    style: GoogleFonts.lexend(fontSize: 12.5),
                                    decoration: InputDecoration(
                                      labelText: 'Takaran',
                                      hintText: '18',
                                      suffixText: selected?.unit ?? '',
                                      isDense: true,
                                      border: const OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: AppTheme.dangerRed, size: 20),
                                  tooltip: 'Hapus baris ini',
                                  onPressed: _rows.length > 1
                                      ? () => setState(() => _rows.removeAt(i).dispose())
                                      : null,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      if (i < _rows.length - 1) const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ---------- Step 3 + 4: HPP live & rekomendasi harga AI ----------
              AsyncStateView(
                value: ingredientsState,
                dataBuilder: (ingredients) {
                  final hpp = _calcHpp(ingredients);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Card HPP
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.darkCardSurfaceElevated,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.darkCardBorder),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Step 3 — Total Modal (HPP)',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.lexend(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              MoneyFormatter.format(hpp),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.lexend(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.jadeTosca,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'Step 4 — Rekomendasi Harga Jual',
                        style: GoogleFonts.lexend(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),

                      // Tombol "✨ Rekomendasi Harga AI"
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.jadeTosca,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: (_aiLoading || hpp <= 0)
                              ? null
                              : () => _fetchAiRecommendation(hpp),
                          icon: _aiLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.auto_awesome_rounded, size: 18),
                          label: Text(
                            '✨ Rekomendasi Harga AI',
                            style: GoogleFonts.lexend(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),

                      // Result UI Rekomendasi AI
                      if (_aiRecommendedPrice != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.darkCardSurfaceElevated,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.jadeTosca.withAlpha(120)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.lightbulb_outline_rounded,
                                    color: AppTheme.jadeTosca,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Rekomendasi AI (${_aiMarginPercentage ?? 50}% Margin)',
                                    style: GoogleFonts.lexend(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.jadeTosca,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // a) Action Chip/Button harga untuk mengisi price_idr
                              ActionChip(
                                backgroundColor: AppTheme.jadeTosca,
                                side: BorderSide.none,
                                avatar: const Icon(
                                  Icons.check_circle_outline_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                label: Text(
                                  'Gunakan Harga ${MoneyFormatter.format(_aiRecommendedPrice!)}',
                                  style: GoogleFonts.lexend(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _priceCtrl.text = _aiRecommendedPrice.toString();
                                  });
                                },
                              ),
                              const SizedBox(height: 8),
                              // b) Teks reasoning sebagai caption
                              Text(
                                _aiReasoning ?? 'Rekomendasi optimal berdasarkan analisis pasar F&B.',
                                style: GoogleFonts.lexend(
                                  fontSize: 12,
                                  color: AppTheme.textSecondaryDark,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 10),
                              // c) Tombol sekunder "🤖 Lanjutkan ke Arus AI"
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.jadeTosca,
                                  side: const BorderSide(color: AppTheme.jadeTosca, width: 1.2),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                onPressed: () => _navigateToAiChat(hpp),
                                icon: const Icon(Icons.forum_outlined, size: 16),
                                label: Text(
                                  '🤖 Lanjutkan ke Arus AI',
                                  style: GoogleFonts.lexend(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),
                      Text(
                        'Rekomendasi Cepat (Margin Statis):',
                        style: GoogleFonts.lexend(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final m in [30, 50, 100])
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.jadeTosca,
                                side: const BorderSide(color: AppTheme.darkCardBorder),
                                backgroundColor: AppTheme.darkCardSurfaceElevated,
                              ),
                              onPressed: hpp <= 0
                                  ? null
                                  : () => setState(() =>
                                      _priceCtrl.text = _priceFor(hpp, m).toString()),
                              child: Text(
                                '${m == 30 ? "Rendah" : m == 50 ? "Sedang" : "Tinggi"} $m%\n${MoneyFormatter.format(_priceFor(hpp, m))}',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.lexend(fontSize: 11),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _priceCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: GoogleFonts.lexend(fontSize: 14),
                        decoration: const InputDecoration(
                          labelText: 'Harga Jual (price_idr) *',
                          hintText: 'Klik rekomendasi atau ketik sendiri',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final n =
                              int.tryParse((v ?? '').replaceAll(RegExp(r'[^0-9]'), '')) ??
                                  0;
                          if (n <= 0) return 'Harga jual wajib > 0';
                          if (hpp > 0 && n < hpp) {
                            return 'Harga di bawah modal (${MoneyFormatter.format(hpp)})';
                          }
                          return null;
                        },
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.jadeTosca,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        'Simpan Menu + Resep',
                        style: GoogleFonts.lexend(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
