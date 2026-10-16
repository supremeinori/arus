import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../data/game_repository.dart';

enum GameState { lobby, loading, playing, result }

class GameHomeScreen extends ConsumerStatefulWidget {
  const GameHomeScreen({super.key});

  @override
  ConsumerState<GameHomeScreen> createState() => _GameHomeScreenState();
}

class _GameHomeScreenState extends ConsumerState<GameHomeScreen> {
  GameState _gameState = GameState.lobby;
  String _selectedMode = 'guess_name'; // 'guess_name' | 'guess_price'

  // Data Soal & Gameplay
  List<GameQuestionModel> _questions = [];
  int _currentQuestionIndex = 0;
  int _currentScore = 0;
  int _correctCount = 0;
  int _totalDurationSec = 0;

  // Timer per soal (10 detik)
  static const int _timePerQuestion = 10;
  int _remainingSeconds = _timePerQuestion;
  Timer? _countdownTimer;
  Timer? _sessionTimer;

  // State Tombol Interaksi (Feedback Jawaban)
  String? _selectedOptionKey;
  bool _isAnswerChecked = false;

  // Data Sesi Selesai
  bool _isNewHighScore = false;
  UserGameStats? _userStats;
  bool _isLoadingStats = false;

  @override
  void initState() {
    super.initState();
    _loadUserStats();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _sessionTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUserStats() async {
    setState(() => _isLoadingStats = true);
    try {
      final repo = ref.read(gameRepositoryProvider);
      final stats = await repo.fetchUserStats();
      if (mounted) {
        setState(() {
          _userStats = stats;
          _isLoadingStats = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  Future<void> _startGame(String mode) async {
    setState(() {
      _selectedMode = mode;
      _gameState = GameState.loading;
      _questions = [];
      _currentQuestionIndex = 0;
      _currentScore = 0;
      _correctCount = 0;
      _totalDurationSec = 0;
      _selectedOptionKey = null;
      _isAnswerChecked = false;
    });

    try {
      final repo = ref.read(gameRepositoryProvider);
      final list = await repo.fetchQuestions(mode: mode, limit: 5);

      if (list.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Katalog menu belum cukup untuk memulai kuis.')),
          );
          setState(() => _gameState = GameState.lobby);
        }
        return;
      }

      if (mounted) {
        setState(() {
          _questions = list;
          _gameState = GameState.playing;
        });
        _startSessionTimer();
        _startQuestionTimer();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat soal kuis: $e')),
        );
        setState(() => _gameState = GameState.lobby);
      }
    }
  }

  void _startSessionTimer() {
    _sessionTimer?.cancel();
    _totalDurationSec = 0;
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _totalDurationSec++;
    });
  }

  void _startQuestionTimer() {
    _countdownTimer?.cancel();
    setState(() {
      _remainingSeconds = _timePerQuestion;
      _selectedOptionKey = null;
      _isAnswerChecked = false;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 1) {
        setState(() => _remainingSeconds--);
      } else {
        timer.cancel();
        _onTimeOut();
      }
    });
  }

  void _onTimeOut() {
    HapticFeedback.mediumImpact();
    setState(() {
      _remainingSeconds = 0;
      _isAnswerChecked = true;
    });

    // Waktu habis = Salah, jeda 1.2 detik lalu lanjut
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) _goToNextQuestion();
    });
  }

  void _selectOption(String optionKey) {
    if (_isAnswerChecked) return; // Cegah klik ganda

    _countdownTimer?.cancel();
    final currentQ = _questions[_currentQuestionIndex];
    final isCorrect = optionKey == currentQ.correctOptionKey;

    if (isCorrect) {
      HapticFeedback.lightImpact();
      final timeBonus = _remainingSeconds * 10;
      _currentScore += (100 + timeBonus);
      _correctCount++;
    } else {
      HapticFeedback.heavyImpact();
    }

    setState(() {
      _selectedOptionKey = optionKey;
      _isAnswerChecked = true;
    });

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) _goToNextQuestion();
    });
  }

  void _goToNextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
      _startQuestionTimer();
    } else {
      _finishGame();
    }
  }

  Future<void> _finishGame() async {
    _countdownTimer?.cancel();
    _sessionTimer?.cancel();

    setState(() {
      _gameState = GameState.loading;
    });

    try {
      final repo = ref.read(gameRepositoryProvider);
      final result = await repo.submitSession(
        mode: _selectedMode,
        score: _currentScore,
        correctCount: _correctCount,
        totalQuestions: _questions.length,
        durationSec: _totalDurationSec,
      );

      final isHigh = result['is_new_high_score'] as bool? ?? false;

      if (mounted) {
        setState(() {
          _isNewHighScore = isHigh;
          _gameState = GameState.result;
        });
        _loadUserStats(); // Refresh skor tertinggi
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isNewHighScore = false;
          _gameState = GameState.result;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          _gameState == GameState.playing
              ? (_selectedMode == 'guess_name' ? 'Tebak Nama Menu' : 'Tebak Harga Jual')
              : 'Guess the Menu',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: _gameState == GameState.playing
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Keluar dari Kuis?'),
                      content: const Text('Progres kuis saat ini akan dibatalkan.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Lanjut'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _countdownTimer?.cancel();
                            _sessionTimer?.cancel();
                            setState(() => _gameState = GameState.lobby);
                          },
                          child: const Text('Keluar', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                },
              )
            : null,
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _buildCurrentView(),
        ),
      ),
    );
  }

  Widget _buildCurrentView() {
    switch (_gameState) {
      case GameState.lobby:
        return _buildLobbyView();
      case GameState.loading:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppTheme.primary),
              const SizedBox(height: 16),
              const Text('Menyiapkan soal kuis dari katalog...'),
            ],
          ),
        );
      case GameState.playing:
        return _buildPlayingView();
      case GameState.result:
        return _buildResultView();
    }
  }

  // ==========================================
  // VIEW 1: LOBBY & PILIH MODE
  // ==========================================
  Widget _buildLobbyView() {
    return RefreshIndicator(
      onRefresh: _loadUserStats,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Banner Judul
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primary, const Color(0xFF1E3A8A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.sports_esports_rounded, color: Colors.white, size: 28),
                      const SizedBox(width: 8),
                      Text(
                        'Mini Game POS',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Guess the Menu! 🎯',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Asah ingatan kasir terhadap visual menu & harga jual resmi outlet secara interaktif.',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Kartu Skor Tertinggi (Personal Best)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Rekor Terbaik Anda',
                  style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                if (_isLoadingStats)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.image_search_rounded,
                    title: 'Tebak Nama',
                    score: _userStats?.bestGuessName ?? 0,
                    color: Colors.purple,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.payments_rounded,
                    title: 'Tebak Harga',
                    score: _userStats?.bestGuessPrice ?? 0,
                    color: Colors.teal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Pilihan Mode Permainan
            Text(
              'Pilih Mode Permainan',
              style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),

            _buildModeCard(
              modeKey: 'guess_name',
              icon: Icons.fastfood_rounded,
              title: 'Mode 1: Tebak Nama Menu',
              desc: 'Tampilkan foto makanan/minuman, tebak nama produk yang tepat dari 4 pilihan.',
              badgeText: '5 Soal · 10 Detik/Soal',
              color: Colors.indigo,
            ),
            const SizedBox(height: 12),

            _buildModeCard(
              modeKey: 'guess_price',
              icon: Icons.price_check_rounded,
              title: 'Mode 2: Tebak Harga Jual',
              desc: 'Lihat foto & nama menu kasir, tebak harga resmi yang terdaftar di POS.',
              badgeText: '5 Soal · Uji Hafalan Kasir',
              color: Colors.deepOrange,
            ),
            const SizedBox(height: 24),

            // Riwayat Permainan
            if (_userStats != null && _userStats!.recentSessions.isNotEmpty) ...[
              Text(
                'Riwayat Permainan Terakhir',
                style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _userStats!.recentSessions.take(5).length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, idx) {
                  final s = _userStats!.recentSessions[idx];
                  final isName = s.mode == 'guess_name';
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: isName ? Colors.purple.shade50 : Colors.teal.shade50,
                          child: Icon(
                            isName ? Icons.fastfood_rounded : Icons.price_check_rounded,
                            size: 18,
                            color: isName ? Colors.purple : Colors.teal,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isName ? 'Tebak Nama Menu' : 'Tebak Harga Jual',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                '${s.correctCount}/5 Benar · ${s.durationSec}s',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${s.score} Poin',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required int score,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                ),
                const SizedBox(height: 2),
                Text(
                  '$score Poin',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeCard({
    required String modeKey,
    required IconData icon,
    required String title,
    required String desc,
    required String badgeText,
    required Color color,
  }) {
    return InkWell(
      onTap: () => _startGame(modeKey),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12, height: 1.3),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badgeText,
                      style: GoogleFonts.plusJakartaSans(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // VIEW 2: GAMEPLAY (5 SOAL DENGAN TIMER)
  // ==========================================
  Widget _buildPlayingView() {
    if (_questions.isEmpty) return const SizedBox.shrink();

    final currentQ = _questions[_currentQuestionIndex];
    final timerProgress = _remainingSeconds / _timePerQuestion;

    return Column(
      children: [
        // Header Info Soal, Skor, & Timer Bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Soal ${_currentQuestionIndex + 1} dari ${_questions.length}',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        '$_currentScore Poin',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Progress Bar Waktu Hitung Mundur (10 detik)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: timerProgress,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _remainingSeconds <= 3 ? AppTheme.error : AppTheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '⏱️ Sisa Waktu: $_remainingSeconds detik',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _remainingSeconds <= 3 ? AppTheme.error : Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Area Soal & Foto Menu
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              children: [
                // Badge Kategori
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    currentQ.categoryName,
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Card Gambar Menu
                Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      currentQ.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Center(
                        child: Icon(Icons.fastfood_rounded, size: 64, color: Colors.grey),
                      ),
                      loadingBuilder: (ctx, child, progress) {
                        if (progress == null) return child;
                        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Judul Pertanyaan
                Text(
                  currentQ.promptTitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: _selectedMode == 'guess_price' ? 18 : 15,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),

                // 4 Tombol Pilihan Ganda
                ...currentQ.options.map((opt) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildOptionButton(opt, currentQ.correctOptionKey),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionButton(GameQuestionOption opt, String correctKey) {
    Color buttonColor = Colors.white;
    Color textColor = Colors.black87;
    Color borderColor = Colors.grey.shade300;
    Widget? trailingIcon;

    if (_isAnswerChecked) {
      if (opt.key == correctKey) {
        // Jawaban Benar -> Selalu Hijau
        buttonColor = const Color(0xFFDCFCE7); // Light green
        borderColor = const Color(0xFF16A34A);
        textColor = const Color(0xFF15803D);
        trailingIcon = const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A));
      } else if (opt.key == _selectedOptionKey) {
        // Jawaban Terpilih Tapi Salah -> Merah
        buttonColor = const Color(0xFFFEE2E2); // Light red
        borderColor = const Color(0xFFDC2626);
        textColor = const Color(0xFFB91C1C);
        trailingIcon = const Icon(Icons.cancel_rounded, color: Color(0xFFDC2626));
      }
    }

    return InkWell(
      onTap: _isAnswerChecked ? null : () => _selectOption(opt.key),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: buttonColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Text(
                opt.key.replaceAll('opt_', '').toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                opt.label,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: textColor,
                ),
              ),
            ),
            ?trailingIcon,
          ],
        ),
      ),
    );
  }

  // ==========================================
  // VIEW 3: HASIL PERMAINAN & SKOR
  // ==========================================
  Widget _buildResultView() {
    String badgeTitle = 'Barista Pemula ⭐';
    Color badgeColor = Colors.blueGrey;

    if (_currentScore >= 800) {
      badgeTitle = 'Master Menu POS ⭐⭐⭐';
      badgeColor = Colors.amber.shade800;
    } else if (_currentScore >= 500) {
      badgeTitle = 'Kasir Handal ⭐⭐';
      badgeColor = AppTheme.primary;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Ikon Trofi
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.emoji_events_rounded,
              size: 72,
              color: Colors.amber.shade700,
            ),
          ),
          const SizedBox(height: 16),

          if (_isNewHighScore) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.stars_rounded, color: Colors.amber, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'REKOR SKOR BARU! 🏆',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.amber.shade900,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          Text(
            'Permainan Selesai!',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            badgeTitle,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: badgeColor,
            ),
          ),
          const SizedBox(height: 24),

          // Card Skor Utama
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  'Total Skor Anda',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  '$_currentScore',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primary,
                  ),
                ),
                const Divider(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildResultMetric(
                      label: 'Jawaban Benar',
                      value: '$_correctCount / ${_questions.length}',
                      icon: Icons.check_circle_rounded,
                      color: Colors.green,
                    ),
                    _buildResultMetric(
                      label: 'Waktu Bermain',
                      value: '${_totalDurationSec}s',
                      icon: Icons.timer_rounded,
                      color: Colors.orange,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Tombol Aksi
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => _startGame(_selectedMode),
            child: Text(
              'Main Lagi 🔁',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),

          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              side: BorderSide(color: AppTheme.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => setState(() => _gameState = GameState.lobby),
            child: Text(
              'Kembali ke Menu Game',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppTheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultMetric({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
        ),
      ],
    );
  }
}
