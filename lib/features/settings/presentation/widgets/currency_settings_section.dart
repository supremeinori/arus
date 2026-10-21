import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/money_formatter.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../../../shared/widgets/async_state_view.dart';
import '../currency_provider.dart';

/// Section pengaturan kurs: pilihan mata uang tampilan, pratinjau omzet, dan
/// kalkulator konversi nominal.
///
/// Dipisah dari [TimeSettingsSection] supaya tiap domain pengaturan punya
/// widget mandiri (aturan E23: widget class, bukan helper method).
class CurrencySettingsSection extends ConsumerStatefulWidget {
  const CurrencySettingsSection({super.key});

  @override
  ConsumerState<CurrencySettingsSection> createState() =>
      _CurrencySettingsSectionState();
}

class _CurrencySettingsSectionState
    extends ConsumerState<CurrencySettingsSection> {
  final _amountController = TextEditingController(text: '100000');
  String _fromCurrency = 'IDR';
  String _toCurrency = 'USD';

  @override
  void initState() {
    super.initState();
    // Aturan E21: parsing input tidak di build — rebuild via listener.
    _amountController.addListener(_onAmountChanged);
  }

  void _onAmountChanged() {
    if (mounted) setState(() {});
  }

  /// Satu-satunya sumber daftar mata uang (sinkron dengan MoneyFormatter
  /// dan endpoint /users/me/settings di backend).
  final List<String> _availableCurrencies = MoneyFormatter.supportedCurrencies;

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _amountController.dispose();
    super.dispose();
  }

  /// Simpan pilihan ke backend (kolom `User.display_currency`).
  Future<void> _selectCurrency(String currency) async {
    final ok = await ref
        .read(displayCurrencyProvider.notifier)
        .setCurrency(currency);
    if (!ok && mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menyimpan mata uang. Periksa koneksi ke server.',
          ),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  void _swapCurrencies() {
    setState(() {
      final temp = _fromCurrency;
      _fromCurrency = _toCurrency;
      _toCurrency = temp;
    });
  }

  double _calculateConversion(double amount, Map<String, double>? rates) {
    if (_fromCurrency == _toCurrency) return amount;

    // Kurs live (basis IDR); bila belum tersedia pakai fallback terpusat.
    final effective = (rates == null || rates.isEmpty)
        ? MoneyFormatter.fallbackRates
        : rates;

    final rateFrom = effective[_fromCurrency] ?? 1.0;
    final rateTo = effective[_toCurrency] ?? 1.0;

    final amountInIdr = _fromCurrency == 'IDR' ? amount : (amount / rateFrom);
    final converted = _toCurrency == 'IDR'
        ? amountInIdr
        : (amountInIdr * rateTo);
    return converted;
  }


  void _applyPresetAmount(double val, String? customCurrency) {
    setState(() {
      _amountController.text = val.toStringAsFixed(
        val.truncateToDouble() == val ? 0 : 2,
      );
      if (customCurrency != null) {
        _fromCurrency = customCurrency;
        if (_toCurrency == customCurrency) {
          _toCurrency = 'IDR';
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentCurrency = ref.watch(displayCurrencyProvider);
    final ratesAsync = ref.watch(fxRatesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section 1: Mata Uang Tampilan (Multi-Currency)
        Text(
          'Mata Uang Tampilan (Multi-Currency)',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: AppTheme.textPrimaryDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Pilih mata uang untuk menampilkan seluruh laporan omzet dan harga produk.',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppTheme.textMutedDark,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          color: AppTheme.darkCardSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(
              color: AppTheme.darkCardBorder,
              width: 1.0,
            ),
          ),
          child: Column(
            children: [
              for (var i = 0; i < _availableCurrencies.length; i++) ...[
                if (i > 0)
                  const Divider(
                    height: 1,
                    color: AppTheme.darkCardBorder,
                    thickness: 1,
                  ),
                _CurrencyOptionTile(
                  currency: _availableCurrencies[i],
                  label: MoneyFormatter.currencyLabels[_availableCurrencies[i]] ??
                      _availableCurrencies[i],
                  sample: MoneyFormatter.currencySamples[_availableCurrencies[i]] ??
                      0,
                  selected: currentCurrency == _availableCurrencies[i],
                  onSelected: _selectCurrency,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Live Preview Card (aturan E24: loading/error kurs eksplisit).
        AsyncStateView(
          value: ratesAsync,
          loadingMessage: 'Memuat kurs...',
          onRetry: () => ref.refresh(fxRatesProvider),
          dataBuilder: (fx) {
            const sampleOmzetIdr = 2500000;
            final convertedPreview = MoneyFormatter.format(
              sampleOmzetIdr,
              currency: currentCurrency,
              rates: fx.rates,
            );
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.darkCardSurfaceElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.jadeTosca.withAlpha(120),
                  width: 1.0,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.currency_exchange_rounded,
                    color: AppTheme.jadeTosca,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pratinjau Omzet Toko (Contoh ${MoneyFormatter.format(sampleOmzetIdr)}):',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: AppTheme.textMutedDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        MoneyText(
                          sampleOmzetIdr,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.jadeTosca,
                          ),
                        ),
                        Text(
                          convertedPreview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        const SizedBox(height: 24),

        // Section 2: Kalkulator Konversi Interaktif (Fokus Input Uang User)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Kalkulator Konversi Nominal',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: AppTheme.textPrimaryDark,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: AppTheme.darkCardSurfaceElevated,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppTheme.darkCardBorder,
                  width: 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.sync_alt_rounded,
                    size: 14,
                    color: AppTheme.jadeTosca,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    ratesAsync.isLoading ? 'Memuat...' : 'Live Rate API',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.jadeTosca,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Masukkan jumlah uang yang ingin dikonversi secara fleksibel ke berbagai mata uang.',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppTheme.textMutedDark,
          ),
        ),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.darkCardSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.darkCardBorder, width: 1.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nominal Uang yang Ingin Dikonversi',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryDark,
                ),
              ),
              const SizedBox(height: 6),
              AppTextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                labelText: 'Nominal Uang yang Ingin Dikonversi',
                hintText: 'Ketik nominal uang...',
                prefixIcon: Icons.payments_outlined,
                suffixIcon: _amountController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear,
                          size: 18,
                          color: Color(0xFF94A3B8),
                        ),
                        onPressed: _amountController.clear,
                      )
                    : null,
              ),

              const SizedBox(height: 10),

              // Quick preset chips
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _AmountChip(
                    label: '50.000',
                    value: 50000,
                    onSelect: _applyPresetAmount,
                  ),
                  _AmountChip(
                    label: '100.000',
                    value: 100000,
                    onSelect: _applyPresetAmount,
                  ),
                  _AmountChip(
                    label: '500.000',
                    value: 500000,
                    onSelect: _applyPresetAmount,
                  ),
                  _AmountChip(
                    label: '1.000.000',
                    value: 1000000,
                    onSelect: _applyPresetAmount,
                  ),
                  _AmountChip(
                    label: '100 USD',
                    value: 100,
                    customCurrency: 'USD',
                    onSelect: _applyPresetAmount,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Selectors From & To
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dari',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: AppTheme.textMutedDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        AppDropdown<String>(
                          value: _fromCurrency,
                          items: _availableCurrencies
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(
                                    c,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _fromCurrency = val);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8)
                        .copyWith(top: 18),
                    child: IconButton.filledTonal(
                      onPressed: _swapCurrencies,
                      tooltip: 'Tukar Posisi',
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.darkCardSurfaceElevated,
                        foregroundColor: AppTheme.jadeTosca,
                      ),
                      icon: const Icon(Icons.swap_horiz_rounded, size: 22),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ke',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: AppTheme.textMutedDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        AppDropdown<String>(
                          value: _toCurrency,
                          items: _availableCurrencies
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(
                                    c,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _toCurrency = val);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Converted Result Display (aturan E24: ikut status kurs).
              AsyncStateView(
                value: ratesAsync,
                loadingMessage: 'Memuat kurs...',
                onRetry: () => ref.refresh(fxRatesProvider),
                dataBuilder: (fx) {
                  final cleanInput = _amountController.text.replaceAll(
                    RegExp(r'[^0-9.]'),
                    '',
                  );
                  final inputAmount = double.tryParse(cleanInput) ?? 0.0;
                  final convertedResult = _calculateConversion(
                    inputAmount,
                    fx.rates,
                  );
                  final formattedResult = MoneyFormatter.formatInCurrency(
                    convertedResult,
                    currency: _toCurrency,
                  );
                  final singleUnitFormatted = MoneyFormatter.formatInCurrency(
                    _calculateConversion(1.0, fx.rates),
                    currency: _toCurrency,
                  );
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.darkCardSurfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppTheme.darkCardBorder,
                        width: 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hasil Konversi:',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textMutedDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formattedResult,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.jadeTosca,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Nilai Tukar: 1 $_fromCurrency = $singleUnitFormatted',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: AppTheme.textSecondaryDark,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Chip preset nominal (aturan E23: widget class const, bukan helper).
class _AmountChip extends StatelessWidget {
  final String label;
  final double value;
  final String? customCurrency;
  final void Function(double value, String? customCurrency) onSelect;

  const _AmountChip({
    required this.label,
    required this.value,
    required this.onSelect,
    this.customCurrency,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimaryDark,
        ),
      ),
      backgroundColor: AppTheme.darkCardSurfaceElevated,
      side: const BorderSide(color: AppTheme.darkCardBorder),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      onPressed: () => onSelect(value, customCurrency),
    );
  }
}

/// Tile pilihan satu mata uang tampilan (dibangun dari daftar mata uang
/// yang didukung, bukan nominal hardcoded).
class _CurrencyOptionTile extends StatelessWidget {
  final String currency;
  final String label;
  final num sample;
  final bool selected;
  final ValueChanged<String> onSelected;

  const _CurrencyOptionTile({
    required this.currency,
    required this.label,
    required this.sample,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: selected ? AppTheme.jadeTosca : AppTheme.textMutedDark,
      ),
      title: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          fontSize: 13.5,
          color: AppTheme.textPrimaryDark,
        ),
      ),
      subtitle: Text(
        'Contoh: ${MoneyFormatter.formatInCurrency(sample, currency: currency)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(
          fontSize: 12,
          color: AppTheme.textMutedDark,
        ),
      ),
      onTap: () => onSelected(currency),
    );
  }
}
