import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/timezone_converter.dart';
import 'currency_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _amountController = TextEditingController(text: '100000');
  String _fromCurrency = 'IDR';
  String _toCurrency = 'USD';

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

    final rateFrom = _fromCurrency == 'IDR' ? 1.0 : (rates[_fromCurrency] ?? 1.0);
    final rateTo = _toCurrency == 'IDR' ? 1.0 : (rates[_toCurrency] ?? 1.0);

    final amountInIdr = _fromCurrency == 'IDR' ? amount : (amount / rateFrom);
    final converted = _toCurrency == 'IDR' ? amountInIdr : (amountInIdr * rateTo);
    return converted;
  }

  String _formatCurrencyValue(double val, String currency) {
    switch (currency) {
      case 'IDR':
        return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(val);
      case 'USD':
        return NumberFormat.currency(locale: 'en_US', symbol: '\$ ', decimalDigits: 2).format(val);
      case 'EUR':
        return NumberFormat.currency(locale: 'de_DE', symbol: '€ ', decimalDigits: 2).format(val);
      case 'SGD':
        return NumberFormat.currency(locale: 'en_SG', symbol: 'S\$ ', decimalDigits: 2).format(val);
      case 'JPY':
        return NumberFormat.currency(locale: 'ja_JP', symbol: '¥ ', decimalDigits: 0).format(val);
      case 'MYR':
        return NumberFormat.currency(locale: 'ms_MY', symbol: 'RM ', decimalDigits: 2).format(val);
      case 'GBP':
        return NumberFormat.currency(locale: 'en_GB', symbol: '£ ', decimalDigits: 2).format(val);
      default:
        return '$currency ${NumberFormat('#,##0.00').format(val)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentCurrency = ref.watch(displayCurrencyProvider);
    final currentTimezone = ref.watch(displayTimezoneProvider);
    final ratesAsync = ref.watch(fxRatesProvider);

    final rates = ratesAsync.value?.rates;

    const sampleOmzetIdr = 2500000;
    final convertedPreview = MoneyFormatter.format(
      sampleOmzetIdr,
      currency: currentCurrency,
      rates: rates,
    );

    final nowUtc = DateTime.now().toUtc();
    final timePreview = TimezoneConverter.formatTime(nowUtc, currentTimezone);

    // Hitung konversi interaktif dari input user
    final cleanInput = _amountController.text.replaceAll(RegExp(r'[^0-9.]'), '');
    final inputAmount = double.tryParse(cleanInput) ?? 0.0;
    final convertedResult = _calculateConversion(inputAmount, rates);
    final formattedResult = _formatCurrencyValue(convertedResult, _toCurrency);

    final singleUnitRate = _calculateConversion(1.0, rates);
    final singleUnitFormatted = _formatCurrencyValue(singleUnitRate, _toCurrency);

    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      appBar: AppBar(
        title: Text(
          'Pengaturan Kurs & Waktu',
          style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Mata Uang Tampilan (Multi-Currency)
            Text(
              'Mata Uang Tampilan (Multi-Currency)',
              style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.accentBlack),
            ),
            const SizedBox(height: 4),
            Text(
              'Pilih mata uang untuk menampilkan seluruh laporan omzet dan harga produk.',
              style: GoogleFonts.lexend(fontSize: 12, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppTheme.borderOutline, width: 1.0),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      currentCurrency == 'IDR' ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: currentCurrency == 'IDR' ? AppTheme.primaryBlue : const Color(0xFF94A3B8),
                    ),
                    title: Text('Rupiah Indonesia (IDR)', style: GoogleFonts.lexend(fontWeight: FontWeight.w600, fontSize: 13.5)),
                    subtitle: Text('Format standar: Rp 2.500.000', style: GoogleFonts.lexend(fontSize: 12, color: const Color(0xFF64748B))),
                    onTap: () => ref.read(displayCurrencyProvider.notifier).state = 'IDR',
                  ),
                  const Divider(height: 1, color: AppTheme.borderOutline, thickness: 1),
                  ListTile(
                    leading: Icon(
                      currentCurrency == 'USD' ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: currentCurrency == 'USD' ? AppTheme.primaryBlue : const Color(0xFF94A3B8),
                    ),
                    title: Text('Dolar Amerika Serikat (USD)', style: GoogleFonts.lexend(fontWeight: FontWeight.w600, fontSize: 13.5)),
                    subtitle: Text('Format internasional: \$155.00', style: GoogleFonts.lexend(fontSize: 12, color: const Color(0xFF64748B))),
                    onTap: () => ref.read(displayCurrencyProvider.notifier).state = 'USD',
                  ),
                  const Divider(height: 1, color: AppTheme.borderOutline, thickness: 1),
                  ListTile(
                    leading: Icon(
                      currentCurrency == 'EUR' ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: currentCurrency == 'EUR' ? AppTheme.primaryBlue : const Color(0xFF94A3B8),
                    ),
                    title: Text('Euro Uni Eropa (EUR)', style: GoogleFonts.lexend(fontWeight: FontWeight.w600, fontSize: 13.5)),
                    subtitle: Text('Format ekspansi Eropa: € 145.00', style: GoogleFonts.lexend(fontSize: 12, color: const Color(0xFF64748B))),
                    onTap: () => ref.read(displayCurrencyProvider.notifier).state = 'EUR',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Live Preview Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDFA),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.primaryBlue, width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.currency_exchange_rounded, color: AppTheme.primaryBlue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pratinjau Omzet Toko (Contoh Rp 2.500.000):',
                          style: GoogleFonts.lexend(fontSize: 11.5, color: const Color(0xFF475569)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          convertedPreview,
                          style: GoogleFonts.lexend(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Section 2: Kalkulator Konversi Interaktif (Fokus Input Uang User)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Kalkulator Konversi Nominal',
                  style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.accentBlack),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDFA),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF99F6E4), width: 1.0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sync_alt_rounded, size: 14, color: AppTheme.primaryBlue),
                      const SizedBox(width: 4),
                      Text(
                        ratesAsync.isLoading ? 'Memuat...' : 'Live Rate API',
                        style: GoogleFonts.lexend(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppTheme.primaryBlue),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Masukkan jumlah uang yang ingin dikonversi secara fleksibel ke berbagai mata uang.',
              style: GoogleFonts.lexend(fontSize: 12, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderOutline, width: 1.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nominal Uang yang Ingin Dikonversi',
                    style: GoogleFonts.lexend(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.accentBlack),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                    style: GoogleFonts.lexend(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.accentBlack),
                    decoration: InputDecoration(
                      prefixIcon: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        child: Text(
                          _fromCurrency,
                          style: GoogleFonts.lexend(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.primaryBlue),
                        ),
                      ),
                      suffixIcon: _amountController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18, color: Color(0xFF94A3B8)),
                              onPressed: () {
                                _amountController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      hintText: 'Ketik nominal uang...',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderOutline)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderOutline)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 1.5)),
                    ),
                    onChanged: (val) => setState(() {}),
                  ),

                  const SizedBox(height: 10),

                  // Quick preset chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildAmountChip('50.000', 50000),
                      _buildAmountChip('100.000', 100000),
                      _buildAmountChip('500.000', 500000),
                      _buildAmountChip('1.000.000', 1000000),
                      _buildAmountChip('100 USD', 100, customCurrency: 'USD'),
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
                            Text('Dari', style: GoogleFonts.lexend(fontSize: 11.5, color: const Color(0xFF64748B))),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.borderOutline),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _fromCurrency,
                                  isExpanded: true,
                                  items: _availableCurrencies
                                      .map((c) => DropdownMenuItem(value: c, child: Text(c, style: GoogleFonts.lexend(fontSize: 13, fontWeight: FontWeight.w600))))
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _fromCurrency = val);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8).copyWith(top: 18),
                        child: IconButton.filledTonal(
                          onPressed: _swapCurrencies,
                          tooltip: 'Tukar Posisi',
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFF0FDFA),
                            foregroundColor: AppTheme.primaryBlue,
                          ),
                          icon: const Icon(Icons.swap_horiz_rounded, size: 22),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Ke', style: GoogleFonts.lexend(fontSize: 11.5, color: const Color(0xFF64748B))),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.borderOutline),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _toCurrency,
                                  isExpanded: true,
                                  items: _availableCurrencies
                                      .map((c) => DropdownMenuItem(value: c, child: Text(c, style: GoogleFonts.lexend(fontSize: 13, fontWeight: FontWeight.w600))))
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _toCurrency = val);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Converted Result Display
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDFA),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF99F6E4), width: 1.0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hasil Konversi:',
                          style: GoogleFonts.lexend(fontSize: 11.5, fontWeight: FontWeight.w500, color: const Color(0xFF475569)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formattedResult,
                          style: GoogleFonts.lexend(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Nilai Tukar: 1 $_fromCurrency = $singleUnitFormatted',
                          style: GoogleFonts.lexend(fontSize: 11.5, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Section 3: Zona Waktu Operasional
            Text(
              'Zona Waktu Operasional',
              style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.accentBlack),
            ),
            const SizedBox(height: 4),
            Text(
              'Menyesuaikan jam buka, laporan shift kasir, dan penutupan harian per cabang.',
              style: GoogleFonts.lexend(fontSize: 12, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppTheme.borderOutline, width: 1.0),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      currentTimezone == 'Asia/Jakarta' ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: currentTimezone == 'Asia/Jakarta' ? AppTheme.primaryBlue : const Color(0xFF94A3B8),
                    ),
                    title: Text('WIB — Waktu Indonesia Barat', style: GoogleFonts.lexend(fontWeight: FontWeight.w600, fontSize: 13.5)),
                    subtitle: Text('Asia/Jakarta (UTC+7: Jakarta, Jogja, Solo, Surabaya)', style: GoogleFonts.lexend(fontSize: 12, color: const Color(0xFF64748B))),
                    onTap: () => ref.read(displayTimezoneProvider.notifier).state = 'Asia/Jakarta',
                  ),
                  const Divider(height: 1, color: AppTheme.borderOutline, thickness: 1),
                  ListTile(
                    leading: Icon(
                      currentTimezone == 'Asia/Makassar' ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: currentTimezone == 'Asia/Makassar' ? AppTheme.primaryBlue : const Color(0xFF94A3B8),
                    ),
                    title: Text('WITA — Waktu Indonesia Tengah', style: GoogleFonts.lexend(fontWeight: FontWeight.w600, fontSize: 13.5)),
                    subtitle: Text('Asia/Makassar (UTC+8: Bali, Lombok, Makassar)', style: GoogleFonts.lexend(fontSize: 12, color: const Color(0xFF64748B))),
                    onTap: () => ref.read(displayTimezoneProvider.notifier).state = 'Asia/Makassar',
                  ),
                  const Divider(height: 1, color: AppTheme.borderOutline, thickness: 1),
                  ListTile(
                    leading: Icon(
                      currentTimezone == 'Asia/Jayapura' ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: currentTimezone == 'Asia/Jayapura' ? AppTheme.primaryBlue : const Color(0xFF94A3B8),
                    ),
                    title: Text('WIT — Waktu Indonesia Timur', style: GoogleFonts.lexend(fontWeight: FontWeight.w600, fontSize: 13.5)),
                    subtitle: Text('Asia/Jayapura (UTC+9: Maluku, Papua)', style: GoogleFonts.lexend(fontSize: 12, color: const Color(0xFF64748B))),
                    onTap: () => ref.read(displayTimezoneProvider.notifier).state = 'Asia/Jayapura',
                  ),
                  const Divider(height: 1, color: AppTheme.borderOutline, thickness: 1),
                  ListTile(
                    leading: Icon(
                      currentTimezone == 'Europe/London' ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: currentTimezone == 'Europe/London' ? AppTheme.primaryBlue : const Color(0xFF94A3B8),
                    ),
                    title: Text('BST/GMT — London United Kingdom', style: GoogleFonts.lexend(fontWeight: FontWeight.w600, fontSize: 13.5)),
                    subtitle: Text('Europe/London (UTC+1: Oxford St, London)', style: GoogleFonts.lexend(fontSize: 12, color: const Color(0xFF64748B))),
                    onTap: () => ref.read(displayTimezoneProvider.notifier).state = 'Europe/London',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDFA),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.primaryBlue, width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time_rounded, color: AppTheme.primaryBlue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Jam Operasional Saat Ini di Zona Terpilih:',
                          style: GoogleFonts.lexend(fontSize: 11.5, color: const Color(0xFF475569)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          timePreview,
                          style: GoogleFonts.lexend(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountChip(String label, double val, {String? customCurrency}) {
    return ActionChip(
      label: Text(label, style: GoogleFonts.lexend(fontSize: 11.5, fontWeight: FontWeight.w600)),
      backgroundColor: const Color(0xFFF1F5F9),
      side: const BorderSide(color: AppTheme.borderOutline),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      onPressed: () {
        setState(() {
          _amountController.text = val.toStringAsFixed(val.truncateToDouble() == val ? 0 : 2);
          if (customCurrency != null) {
            _fromCurrency = customCurrency;
            if (_toCurrency == customCurrency) {
              _toCurrency = 'IDR';
            }
          }
        });
      },
    );
  }
}
