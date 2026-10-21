import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

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

  final List<String> _availableCurrencies = [
    'IDR',
    'USD',
    'EUR',
    'SGD',
    'JPY',
    'MYR',
    'GBP',
  ];

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _amountController.dispose();
    super.dispose();
  }

  void _swapCurrencies() {
    setState(() {
      final temp = _fromCurrency;
      _fromCurrency = _toCurrency;
      _toCurrency = temp;
    });
  }

  double _calculateConversion(double amount, Map<String, double>? rates) {
    if (rates == null || rates.isEmpty) {
      if (_fromCurrency == 'IDR' && _toCurrency == 'USD') return amount / 16000;
      if (_fromCurrency == 'USD' && _toCurrency == 'IDR') return amount * 16000;
      if (_fromCurrency == 'IDR' && _toCurrency == 'EUR') return amount / 17000;
      if (_fromCurrency == 'EUR' && _toCurrency == 'IDR') return amount * 17000;
      return amount;
    }

    if (_fromCurrency == _toCurrency) return amount;

    final rateFrom = _fromCurrency == 'IDR'
        ? 1.0
        : (rates[_fromCurrency] ?? 1.0);
    final rateTo = _toCurrency == 'IDR' ? 1.0 : (rates[_toCurrency] ?? 1.0);

    final amountInIdr = _fromCurrency == 'IDR' ? amount : (amount / rateFrom);
    final converted = _toCurrency == 'IDR'
        ? amountInIdr
        : (amountInIdr * rateTo);
    return converted;
  }

  String _formatCurrencyValue(double val, String currency) {
    switch (currency) {
      case 'IDR':
        return NumberFormat.currency(
          locale: 'id_ID',
          symbol: 'Rp ',
          decimalDigits: 0,
        ).format(val);
      case 'USD':
        return NumberFormat.currency(
          locale: 'en_US',
          symbol: '\$ ',
          decimalDigits: 2,
        ).format(val);
      case 'EUR':
        return NumberFormat.currency(
          locale: 'de_DE',
          symbol: '€ ',
          decimalDigits: 2,
        ).format(val);
      case 'SGD':
        return NumberFormat.currency(
          locale: 'en_SG',
          symbol: 'S\$ ',
          decimalDigits: 2,
        ).format(val);
      case 'JPY':
        return NumberFormat.currency(
          locale: 'ja_JP',
          symbol: '¥ ',
          decimalDigits: 0,
        ).format(val);
      case 'MYR':
        return NumberFormat.currency(
          locale: 'ms_MY',
          symbol: 'RM ',
          decimalDigits: 2,
        ).format(val);
      case 'GBP':
        return NumberFormat.currency(
          locale: 'en_GB',
          symbol: '£ ',
          decimalDigits: 2,
        ).format(val);
      default:
        return '$currency ${NumberFormat('#,##0.00').format(val)}';
    }
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
              ListTile(
                leading: Icon(
                  currentCurrency == 'IDR'
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: currentCurrency == 'IDR'
                      ? AppTheme.jadeTosca
                      : AppTheme.textMutedDark,
                ),
                title: Text(
                  'Rupiah Indonesia (IDR)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    color: AppTheme.textPrimaryDark,
                  ),
                ),
                subtitle: Text(
                  'Format standar: Rp 2.500.000',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textMutedDark,
                  ),
                ),
                onTap: () =>
                    ref.read(displayCurrencyProvider.notifier).setCurrency('IDR'),
              ),
              const Divider(
                height: 1,
                color: AppTheme.darkCardBorder,
                thickness: 1,
              ),
              ListTile(
                leading: Icon(
                  currentCurrency == 'USD'
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: currentCurrency == 'USD'
                      ? AppTheme.jadeTosca
                      : AppTheme.textMutedDark,
                ),
                title: Text(
                  'Dolar Amerika Serikat (USD)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    color: AppTheme.textPrimaryDark,
                  ),
                ),
                subtitle: Text(
                  'Format internasional: \$155.00',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textMutedDark,
                  ),
                ),
                onTap: () =>
                    ref.read(displayCurrencyProvider.notifier).setCurrency('USD'),
              ),
              const Divider(
                height: 1,
                color: AppTheme.darkCardBorder,
                thickness: 1,
              ),
              ListTile(
                leading: Icon(
                  currentCurrency == 'EUR'
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: currentCurrency == 'EUR'
                      ? AppTheme.jadeTosca
                      : AppTheme.textMutedDark,
                ),
                title: Text(
                  'Euro Uni Eropa (EUR)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    color: AppTheme.textPrimaryDark,
                  ),
                ),
                subtitle: Text(
                  'Format ekspansi Eropa: € 145.00',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textMutedDark,
                  ),
                ),
                onTap: () =>
                    ref.read(displayCurrencyProvider.notifier).setCurrency('EUR'),
              ),
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
                          'Pratinjau Omzet Toko (Contoh Rp 2.500.000):',
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
                  final formattedResult = _formatCurrencyValue(
                    convertedResult,
                    _toCurrency,
                  );
                  final singleUnitFormatted = _formatCurrencyValue(
                    _calculateConversion(1.0, fx.rates),
                    _toCurrency,
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
