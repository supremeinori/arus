import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

class GameHomeScreen extends StatefulWidget {
  const GameHomeScreen({super.key});

  @override
  State<GameHomeScreen> createState() => _GameHomeScreenState();
}

class _GameHomeScreenState extends State<GameHomeScreen> {
  int _currentStep = 0;
  int _totalScore = 0;
  bool _isFinished = false;
  final Map<int, int> _selectedAnswers = {};

  final List<Map<String, dynamic>> _scenarios = [
    {
      'title': 'Skenario 1: Lonjakan Jam Makan Siang',
      'difficulty': 'Mudah (Easy)',
      'description': 'Pukul 12:30 WIB, antrean kasir menumpuk hingga 15 orang dan satu mesin espresso mengalami overheat. Apa tindakan prioritasmu?',
      'options': [
        {
          'text': 'A. Panggil staf cadangan, buka kasir kedua, dan tawarkan menu signature ready-to-drink.',
          'points': 100,
          'feedback': 'Sangat tepat! Memangkas antrean dengan cepat tanpa mengecewakan pembeli.',
        },
        {
          'text': 'B. Tutup pintu toko sementara sampai antrean yang ada di dalam selesai.',
          'points': 20,
          'feedback': 'Kurang tepat. Menutup pintu toko merusak reputasi dan menghilangkan potensi omset.',
        },
        {
          'text': 'C. Tetap layani satu per satu dengan satu mesin tanpa memberi tahu pelanggan.',
          'points': 50,
          'feedback': 'Waktu tunggu terlalu lama (>20 menit) dan berisiko memicu komplain antrean.',
        },
      ],
    },
    {
      'title': 'Skenario 2: Stok Susu Oat Habis Total',
      'difficulty': 'Menengah (Medium)',
      'description': 'Menu favorit Matcha Latte Oatmilk dipesan 10 pelanggan berturut-turut, tapi persediaan susu oat di chiller habis total. Apa keputusanmu?',
      'options': [
        {
          'text': 'A. Ganti diam-diam dengan susu sapi biasa tanpa memberi tahu pembeli.',
          'points': 0,
          'feedback': 'Fatal! Pelanggan bisa mengalami alergi atau intoleransi laktosa. Pelanggaran SOP berat.',
        },
        {
          'text': 'B. Beri tahu pelanggan secara jujur, tawarkan alternatif (Almond/Kedelai) dengan diskon 15%, lalu buat permintaan transfer stok darurat ke cabang Senopati.',
          'points': 100,
          'feedback': 'Sempurna! Transparansi menjaga loyalitas dan mitigasi stok tercatat rapi di sistem.',
        },
        {
          'text': 'C. Langsung batalkan pesanan dengan ketus tanpa opsi solusi.',
          'points': 30,
          'feedback': 'Kurang solutif. Kasir profesional selalu memberikan alternatif terbaik.',
        },
      ],
    },
    {
      'title': 'Skenario 3: Kesalahan Nominal Transaksi',
      'difficulty': 'Tantangan (Hard)',
      'description': 'Pelanggan membayar lewat QRIS Rp 45.000, tapi kasir salah input Tunai Rp 450.000 sehingga kas toko tidak seimbang. Apa langkah yang benar?',
      'options': [
        {
          'text': 'A. Segera minta persetujuan Manager untuk melakukan VOID transaksi resmi, lalu input ulang transaksi QRIS yang benar.',
          'points': 100,
          'feedback': 'Sempurna! Integritas pembukuan kas tetap terjaga dan audit SHA-256 tercatat bersih.',
        },
        {
          'text': 'B. Talangi selisihnya dengan uang pribadi tanpa melapor ke sistem.',
          'points': 40,
          'feedback': 'Niat baik tapi salah prosedur. Menyulitkan rekonsiliasi kas harian.',
        },
        {
          'text': 'C. Diamkan saja dan berharap tidak ada yang memeriksa saat closing.',
          'points': 10,
          'feedback': 'Pelanggaran integritas kerja berat. Selisih kas pasti terdeteksi saat audit.',
        },
      ],
    },
  ];

  void _chooseOption(int optionIndex) {
    setState(() {
      _selectedAnswers[_currentStep] = optionIndex;
    });
  }

  void _nextStep() {
    if (_currentStep < _scenarios.length - 1) {
      setState(() {
        _currentStep++;
      });
    } else {
      // Hitung Skor
      int score = 0;
      _selectedAnswers.forEach((step, optIdx) {
        final options = _scenarios[step]['options'] as List<dynamic>;
        score += options[optIdx]['points'] as int;
      });
      setState(() {
        _totalScore = score;
        _isFinished = true;
      });
    }
  }

  void _restart() {
    setState(() {
      _currentStep = 0;
      _totalScore = 0;
      _isFinished = false;
      _selectedAnswers.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      appBar: AppBar(
        title: Text(
          'Simulasi Bisnis & Skenario Kasir',
          style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
      body: _isFinished ? _buildResultView() : _buildQuestionView(),
    );
  }

  Widget _buildQuestionView() {
    final scenario = _scenarios[_currentStep];
    final options = scenario['options'] as List<dynamic>;
    final selectedOpt = _selectedAnswers[_currentStep];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Progress Bar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Tantangan ${_currentStep + 1} dari ${_scenarios.length}',
              style: GoogleFonts.lexend(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFBFDBFE), width: 1.0),
              ),
              child: Text(
                scenario['difficulty'],
                style: GoogleFonts.lexend(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primaryBlue),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: (_currentStep + 1) / _scenarios.length,
          backgroundColor: AppTheme.borderOutline,
          color: AppTheme.primaryBlue,
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),

        const SizedBox(height: 18),

        // Scenario Card
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
                scenario['title'],
                style: GoogleFonts.lexend(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.accentBlack),
              ),
              const SizedBox(height: 8),
              Text(
                scenario['description'],
                style: GoogleFonts.lexend(fontSize: 13.5, color: const Color(0xFF334155), height: 1.45),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        Text(
          'Pilih Tindakan SOP Terbaik:',
          style: GoogleFonts.lexend(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.accentBlack),
        ),
        const SizedBox(height: 10),

        ...List.generate(options.length, (idx) {
          final opt = options[idx];
          final isSelected = selectedOpt == idx;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: () => _chooseOption(idx),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? AppTheme.primaryBlue : AppTheme.borderOutline,
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      color: isSelected ? AppTheme.primaryBlue : const Color(0xFF94A3B8),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        opt['text'],
                        style: GoogleFonts.lexend(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected ? AppTheme.primaryBlue : AppTheme.accentBlack,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),

        const SizedBox(height: 12),

        ElevatedButton(
          onPressed: selectedOpt != null ? _nextStep : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(
            _currentStep < _scenarios.length - 1 ? 'Konfirmasi Pilihan & Lanjut' : 'Lihat Evaluasi Akhir',
            style: GoogleFonts.lexend(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildResultView() {
    final maxScore = _scenarios.length * 100;
    final percentage = _mathRound(_totalScore, maxScore);
    String rankBadge = 'Barista Pemula';
    Color rankColor = const Color(0xFF2563EB);

    if (percentage >= 90) {
      rankBadge = 'Master Store Manager ⭐⭐⭐';
      rankColor = const Color(0xFF16A34A);
    } else if (percentage >= 70) {
      rankBadge = 'Supervisor Handal ⭐⭐';
      rankColor = const Color(0xFFD97706);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.borderOutline, width: 1.0),
          ),
          child: Column(
            children: [
              const Icon(Icons.emoji_events_rounded, size: 54, color: Color(0xFFEAB308)),
              const SizedBox(height: 10),
              Text(
                'Simulasi Selesai!',
                style: GoogleFonts.lexend(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.accentBlack),
              ),
              const SizedBox(height: 4),
              Text(
                'Total Skor: $_totalScore / $maxScore ($percentage%)',
                style: GoogleFonts.lexend(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: rankColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  rankBadge,
                  style: GoogleFonts.lexend(fontSize: 13, fontWeight: FontWeight.w700, color: rankColor),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),
        Text(
          'Ulasan Keputusan Anda:',
          style: GoogleFonts.lexend(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.accentBlack),
        ),
        const SizedBox(height: 10),

        ...List.generate(_scenarios.length, (idx) {
          final scen = _scenarios[idx];
          final optIdx = _selectedAnswers[idx] ?? 0;
          final opt = (scen['options'] as List<dynamic>)[optIdx];
          final isBest = opt['points'] == 100;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderOutline, width: 1.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      scen['title'],
                      style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.accentBlack),
                    ),
                    Text(
                      '+${opt['points']} Poin',
                      style: GoogleFonts.lexend(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: isBest ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Ulasan: ${opt['feedback']}',
                  style: GoogleFonts.lexend(fontSize: 12, color: const Color(0xFF475569), height: 1.35),
                ),
              ],
            ),
          );
        }),

        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _restart,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(
            'Ulangi Simulasi Skenario',
            style: GoogleFonts.lexend(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ),
      ],
    );
  }

  int _mathRound(int num, int total) {
    if (total <= 0) return 0;
    return ((num / total) * 100).round();
  }
}
