import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../data/game_repository.dart';
import '../domain/tilt_direction.dart';
import '../../sensors/presentation/sensor_provider.dart';

enum GameState { lobby, loading, playing, result }

/// Status ketersediaan sensor untuk kontrol gyroscope.
enum _GyroSensorState { initializing, ready, unavailable }

class GameHomeScreen extends ConsumerStatefulWidget {
  const GameHomeScreen({super.key, this.clock});

  /// Sumber waktu untuk logika kontrol gyroscope (hold-to-answer).
  ///
  /// `null` (default) memakai jam dinding aplikasi. Parameter ini adalah seam
  /// untuk pengujian, sehingga durasi tahan 3 detik dapat diverifikasi tanpa
  /// menunggu waktu nyata.
  final DateTime Function()? clock;

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

  // Gyroscope Hold-to-Answer
  // Aturan main: miringkan HP ke satu arah lalu tahan selama 3 detik.
  //   Atas (A) | Kanan (B) | Kiri (C) | Bawah (D)
  static const Duration _gyroPollInterval = Duration(milliseconds: 40);
  static const Duration _gyroSensorTimeout = Duration(milliseconds: 2500);

  final TiltHoldTracker _gyroTracker = TiltHoldTracker();
  final ValueNotifier<double> _gyroProgress = ValueNotifier<double>(0);
  Timer? _gyroPollTimer;
  TiltDirection? _gyroDirection; // arah yang sedang ditahan (untuk UI)
  bool _gyroAnswerLocked = false; // jawaban sudah terkunci via gyroscope
  _GyroSensorState _gyroSensorState = _GyroSensorState.initializing;
  DateTime? _lastGyroSampleAt; // timestamp sampel sensor terakhir
  int _gyroStalePolls = 0; // jumlah polling tanpa sampel sensor baru

  // Data Sesi Selesai
  bool _isNewHighScore = false;
  UserGameStats? _userStats;
  bool _isLoadingStats = false;

  @override
  void initState() {
    super.initState();
    _loadUserStats();
  }

  // ==========================================
  // GYROSCOPE HOLD-TO-ANSWER
  // ==========================================

  /// Mulai monitoring sensor selama gameplay berjalan.
  ///
  /// Poll (bukan listener hardware baru) membaca state provider gyro yang
  /// sudah ada, sehingga tidak ada duplikasi listener sensor.
  void _startGyroPolling() {
    _stopGyroPolling();
    if (_gameState != GameState.playing) return;
    // Seed timestamp sampel terakhir: sensor baru dianggap "siap" setelah ada
    // sampel baru masuk, sehingga perangkat tanpa sensor terdeteksi sebagai
    // tidak tersedia (fallback ke tombol sentuh).
    _lastGyroSampleAt = ref.read(gyroscopeProvider).timestamp;
    _gyroPollTimer = Timer.periodic(_gyroPollInterval, (_) => _pollGyro());
  }

  /// Hentikan monitoring sensor & reset seluruh status gyro.
  void _stopGyroPolling() {
    _gyroPollTimer?.cancel();
    _gyroPollTimer = null;
    _resetGyroState();
    _gyroSensorState = _GyroSensorState.initializing;
    _lastGyroSampleAt = null;
    _gyroStalePolls = 0;
  }

  /// Reset status gyro (ganti soal / timeout / selesai / keluar).
  ///
  /// Status ketersediaan sensor tidak di-reset di sini: antar soal sensor tetap
  /// hidup, jadi tidak perlu mengulang deteksi (menghindari kedipan UI).
  void _resetGyroState() {
    _gyroTracker.reset();
    _gyroProgress.value = 0;
    _gyroDirection = null;
    _gyroAnswerLocked = false;
  }

  /// Baca sampel sensor terbaru, perbarui progres tahan, dan kunci jawaban
  /// bila arah sudah dipertahankan selama [_gyroHoldDuration].
  void _pollGyro() {
    if (!mounted) return;
    if (_gameState != GameState.playing || _isAnswerChecked) return;

    final reading = ref.read(gyroscopeProvider);
    final now = _now;

    // Timestamp hanya maju bila ada event sensor masuk -> dipakai untuk
    // mendeteksi sensor tidak tersedia (fallback ke kontrol sentuh).
    if (reading.timestamp != _lastGyroSampleAt) {
      _lastGyroSampleAt = reading.timestamp;
      _gyroStalePolls = 0;
      if (_gyroSensorState != _GyroSensorState.ready) {
        setState(() => _gyroSensorState = _GyroSensorState.ready);
      }
    } else {
      // Tidak ada sampel baru selama [_gyroSensorTimeout] -> sensor dianggap
      // mati/tidak tersedia, pemain tetap bisa menjawab lewat tombol sentuh.
      // Dihitung dari jumlah polling (bukan timestamp) agar tidak bergantung
      // pada sumber jam.
      _gyroStalePolls++;
      if (_gyroStalePolls >= _gyroSensorStalePollLimit &&
          _gyroSensorState != _GyroSensorState.unavailable) {
        setState(() => _gyroSensorState = _GyroSensorState.unavailable);
        // Batalkan tahan yang sedang berjalan: arah terakhir sudah basi.
        _resetGyroState();
      }
    }

    if (_gyroSensorState != _GyroSensorState.ready) return;
    if (!_gyroControlEnabled) return;

    final detected = detectTiltDirection(
      pitch: reading.pitch,
      roll: reading.roll,
      activeDirection: _gyroTracker.direction,
    );

    final changed = _gyroTracker.update(detected: detected, now: now);
    _gyroProgress.value = _gyroTracker.progressAt(now);

    if (changed) {
      setState(() {
        _gyroDirection = _gyroTracker.direction;
        _gyroAnswerLocked = _gyroTracker.isLocked;
      });
    }

    if (_gyroTracker.isLocked) {
      _lockGyroAnswer();
    }
  }

  /// Kunci jawaban hasil tahan gyroscope.
  ///
  /// Pemeriksaan jawaban & penghitungan skor memakai alur yang sama dengan
  /// tombol sentuh (`_selectOption`).
  void _lockGyroAnswer() {
    final direction = _gyroTracker.lockedDirection;
    if (direction == null) return;
    if (_questions.isEmpty) return;
    if (_currentQuestionIndex >= _questions.length) return;

    final options = _questions[_currentQuestionIndex].options;
    if (direction.optionIndex >= options.length) {
      _gyroTracker.reset();
      return;
    }

    // Jawab lewat alur validasi & skor yang sama dengan tombol sentuh.
    _selectOption(options[direction.optionIndex].key);

    // Tracker dikunci ulang agar tidak ada jawaban ganda untuk soal ini.
    _gyroTracker.reset();
    _gyroProgress.value = 1.0;
  }

  /// Kontrol miring mengikuti pengaturan sensor pengguna (default: aktif).
  bool get _gyroControlEnabled {
    final settings = ref.read(sensorSettingsProvider).valueOrNull;
    return settings?.tiltEnabled ?? true;
  }

  /// Jumlah polling tanpa sampel baru yang menandai sensor tidak tersedia.
  int get _gyroSensorStalePollLimit =>
      (_gyroSensorTimeout.inMilliseconds / _gyroPollInterval.inMilliseconds)
          .ceil();

  /// Sumber waktu kontrol gyroscope (jam dinding, atau clock yang disuntikkan
  /// pada pengujian).
  DateTime get _now => widget.clock?.call() ?? DateTime.now();

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _sessionTimer?.cancel();
    _stopGyroPolling();
    _gyroProgress.dispose();
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
        _startGyroPolling();
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
    _resetGyroState();
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
    _resetGyroState();
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
    _stopGyroPolling();

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
        centerTitle: true,
        title: Text(
          _gameState == GameState.playing
              ? (_selectedMode == 'guess_name' ? 'Tebak Nama Menu' : 'Tebak Harga Jual')
              : 'Guess the Menu',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
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
                      title: const Text('Keluar dari Kuis?', maxLines: 2, overflow: TextOverflow.ellipsis),
                      content: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: const Text('Progres kuis saat ini akan dibatalkan.'),
                      ),
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
                            _stopGyroPolling();
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
                        style: GoogleFonts.inter(
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
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Asah ingatan kasir terhadap visual menu & harga jual resmi outlet secara interaktif.',
                    style: GoogleFonts.inter(
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
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
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
                  child: _GameStatCard(
                    icon: Icons.image_search_rounded,
                    title: 'Tebak Nama',
                    score: _userStats?.bestGuessName ?? 0,
                    color: AppTheme.jadeTosca,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _GameStatCard(
                    icon: Icons.payments_rounded,
                    title: 'Tebak Harga',
                    score: _userStats?.bestGuessPrice ?? 0,
                    color: AppTheme.warningAmber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Pilihan Mode Permainan
            Text(
              'Pilih Mode Permainan',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),

            _GameModeCard(
              modeKey: 'guess_name',
              icon: Icons.fastfood_rounded,
              title: 'Mode 1: Tebak Nama Menu',
              desc: 'Tampilkan foto makanan/minuman, tebak nama produk yang tepat dari 4 pilihan.',
              badgeText: '5 Soal · 10 Detik/Soal',
              color: AppTheme.jadeTosca,
              onTap: _startGame,
            ),
            const SizedBox(height: 12),

            _GameModeCard(
              modeKey: 'guess_price',
              icon: Icons.price_check_rounded,
              title: 'Mode 2: Tebak Harga Jual',
              desc: 'Lihat foto & nama menu kasir, tebak harga resmi yang terdaftar di POS.',
              badgeText: '5 Soal · Uji Hafalan Kasir',
              color: AppTheme.warningAmber,
              onTap: _startGame,
            ),
            const SizedBox(height: 24),

            // Riwayat Permainan
            if (_userStats != null && _userStats!.recentSessions.isNotEmpty) ...[
              Text(
                'Riwayat Permainan Terakhir',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              // List kecil & tetap (<=5 item): render langsung tanpa ListView
              // bersarang (aturan A2/A5) agar SingleChildScrollView induk
              // tetap satu-satunya scrollable.
              ..._userStats!.recentSessions.take(5).map((s) {
                final isName = s.mode == 'guess_name';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.lightCardBorder),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: isName
                              ? AppTheme.jadeTosca.withValues(alpha: 0.12)
                              : AppTheme.warningAmber.withValues(alpha: 0.14),
                          child: Icon(
                            isName ? Icons.fastfood_rounded : Icons.price_check_rounded,
                            size: 18,
                            color: isName ? AppTheme.jadeTosca : AppTheme.warningAmber,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isName ? 'Tebak Nama Menu' : 'Tebak Harga Jual',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                '${s.correctCount}/5 Benar · ${s.durationSec}s',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${s.score} Poin',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
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
    final gyroEnabled =
        ref.watch(sensorSettingsProvider).valueOrNull?.tiltEnabled ?? true;

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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppTheme.textPrimaryLight,
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: AppTheme.warningAmber, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        '$_currentScore Poin',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
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
                  backgroundColor: AppTheme.lightCardBorder,
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
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _remainingSeconds <= 3 ? AppTheme.error : AppTheme.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Kontrol Gyroscope Hold-to-Answer (indikator arah + progres tahan)
              _GyroHoldPanel(
                enabled: gyroEnabled,
                sensorState: _gyroSensorState,
                direction: _gyroDirection,
                locked: _gyroAnswerLocked,
                progress: _gyroProgress,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
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
                    border: Border.all(color: AppTheme.lightCardBorder),
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
                        child: Icon(Icons.fastfood_rounded, size: 64, color: AppTheme.textMuted),
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
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: _selectedMode == 'guess_price' ? 18 : 15,
                    color: AppTheme.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 16),

                // 4 Tombol Pilihan Ganda (huruf A/B/C/D sesuai posisi)
                ...currentQ.options.asMap().entries.map((entry) {
                  final opt = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _GameOptionButton(
                      opt: opt,
                      letter: String.fromCharCode(65 + entry.key),
                      correctKey: currentQ.correctOptionKey,
                      isAnswerChecked: _isAnswerChecked,
                      selectedOptionKey: _selectedOptionKey,
                      onSelect: _selectOption,
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // VIEW 3: HASIL PERMAINAN & SKOR
  // ==========================================
  Widget _buildResultView() {
    String badgeTitle = 'Barista Pemula ⭐';
    Color badgeColor = AppTheme.textMuted;

    if (_currentScore >= 800) {
      badgeTitle = 'Master Menu POS ⭐⭐⭐';
      badgeColor = AppTheme.warningAmber;
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
              color: AppTheme.warningAmber.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              size: 72,
              color: AppTheme.warningAmber,
            ),
          ),
          const SizedBox(height: 16),

          if (_isNewHighScore) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.warningAmber.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.stars_rounded, color: AppTheme.warningAmber, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'REKOR SKOR BARU! 🏆',
                    style: GoogleFonts.inter(
                      color: AppTheme.warningAmber,
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
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            badgeTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
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
              border: Border.all(color: AppTheme.lightCardBorder),
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
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  '$_currentScore',
                  style: GoogleFonts.inter(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primary,
                  ),
                ),
                const Divider(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _GameResultMetric(
                      label: 'Jawaban Benar',
                      value: '$_correctCount / ${_questions.length}',
                      icon: Icons.check_circle_rounded,
                      color: AppTheme.jadeTosca,
                    ),
                    _GameResultMetric(
                      label: 'Waktu Bermain',
                      value: '${_totalDurationSec}s',
                      icon: Icons.timer_rounded,
                      color: AppTheme.warningAmber,
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
              style: GoogleFonts.inter(
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
              style: GoogleFonts.inter(
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
}

/// Kartu skor rekor per mode (aturan E23: widget class const, bukan helper).
class _GameStatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final int score;
  final Color color;

  const _GameStatCard({
    required this.icon,
    required this.title,
    required this.score,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.lightCardBorder),
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                ),
                const SizedBox(height: 2),
                Text(
                  '$score Poin',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppTheme.textPrimaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu mode permainan (aturan E23: widget class const, bukan helper).
class _GameModeCard extends StatelessWidget {
  final String modeKey;
  final IconData icon;
  final String title;
  final String desc;
  final String badgeText;
  final Color color;
  final ValueChanged<String> onTap;

  const _GameModeCard({
    required this.modeKey,
    required this.icon,
    required this.title,
    required this.desc,
    required this.badgeText,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onTap(modeKey),
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12, height: 1.3),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }
}

class _GameOptionButton extends StatelessWidget {
  final GameQuestionOption opt;
  final String letter;
  final String correctKey;
  final bool isAnswerChecked;
  final String? selectedOptionKey;
  final ValueChanged<String> onSelect;

  const _GameOptionButton({
    required this.opt,
    required this.letter,
    required this.correctKey,
    required this.isAnswerChecked,
    required this.selectedOptionKey,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    Color buttonColor = Colors.white;
    Color textColor = AppTheme.textPrimaryLight;
    Color borderColor = AppTheme.lightCardBorder;
    Widget? trailingIcon;

    if (isAnswerChecked) {
      if (opt.key == correctKey) {
        // Jawaban Benar -> Selalu Hijau
        buttonColor = const Color(0xFFDCFCE7); // Light green
        borderColor = const Color(0xFF16A34A);
        textColor = const Color(0xFF15803D);
        trailingIcon = const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A));
      } else if (opt.key == selectedOptionKey) {
        // Jawaban Terpilih Tapi Salah -> Merah
        buttonColor = const Color(0xFFFEE2E2); // Light red
        borderColor = const Color(0xFFDC2626);
        textColor = const Color(0xFFB91C1C);
        trailingIcon = const Icon(Icons.cancel_rounded, color: Color(0xFFDC2626));
      }
    }

    return InkWell(
      onTap: isAnswerChecked ? null : () => onSelect(opt.key),
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
                color: AppTheme.lightCardSurfaceElevated,
                shape: BoxShape.circle,
              ),
              child: Text(
                letter,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                opt.label,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
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
}

/// Panel indikator kontrol gyroscope hold-to-answer (aturan E23: widget class const).
///
/// Menampilkan:
///   - status ketersediaan sensor (fallback ke tombol sentuh)
///   - legenda 4 arah (Atas A / Kanan B / Kiri C / Bawah D)
///   - arah yang sedang ditahan + progress bar + hitung mundur
class _GyroHoldPanel extends StatelessWidget {
  final bool enabled;
  final _GyroSensorState sensorState;
  final TiltDirection? direction;
  final bool locked;
  final ValueListenable<double> progress;

  const _GyroHoldPanel({
    required this.enabled,
    required this.sensorState,
    required this.direction,
    required this.locked,
    required this.progress,
  });

  static IconData _iconFor(TiltDirection direction) {
    switch (direction) {
      case TiltDirection.up:
        return Icons.keyboard_arrow_up_rounded;
      case TiltDirection.right:
        return Icons.keyboard_arrow_right_rounded;
      case TiltDirection.left:
        return Icons.keyboard_arrow_left_rounded;
      case TiltDirection.down:
        return Icons.keyboard_arrow_down_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return _buildNotice(
        icon: Icons.screen_rotation_rounded,
        text: 'Kontrol miring nonaktif (Pengaturan > Sensor). Gunakan tombol jawaban.',
        color: AppTheme.textSecondary,
      );
    }

    switch (sensorState) {
      case _GyroSensorState.initializing:
        return _buildNotice(
          icon: Icons.sensors_rounded,
          text: 'Mengaktifkan sensor gyroscope...',
          color: AppTheme.textSecondary,
        );
      case _GyroSensorState.unavailable:
        return _buildNotice(
          icon: Icons.touch_app_rounded,
          text: 'Sensor tidak tersedia. Gunakan tombol jawaban.',
          color: AppTheme.error,
        );
      case _GyroSensorState.ready:
        break;
    }

    if (locked) {
      return _buildNotice(
        icon: Icons.check_circle_rounded,
        text: 'Jawaban terkunci lewat gyroscope.',
        color: AppTheme.successGreen,
      );
    }

    final dir = direction;
    if (dir == null) {
      return _buildLegend();
    }
    return _buildHold(dir);
  }

  Widget _buildNotice({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.lightCardSurfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.lightCardBorder),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.lightCardSurfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.lightCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.screen_rotation_rounded,
                  size: 16, color: AppTheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Miringkan HP & tahan 3 detik untuk menjawab',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: TiltDirection.values.map((dir) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_iconFor(dir), size: 14, color: AppTheme.primary),
                  const SizedBox(width: 2),
                  Text(
                    '${dir.letter} ${dir.label}',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHold(TiltDirection dir) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_iconFor(dir), size: 18, color: AppTheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Tahan: ${dir.label} (${dir.letter})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              ValueListenableBuilder<double>(
                valueListenable: progress,
                builder: (context, value, _) {
                  final remaining = (kTiltHoldDuration.inMilliseconds *
                          (1 - value) /
                          1000)
                      .ceil();
                  return Text(
                    '$remaining dtk',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          ValueListenableBuilder<double>(
            valueListenable: progress,
            builder: (context, value, _) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 6,
                  backgroundColor: AppTheme.lightCardBorder,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Metrik hasil permainan (aturan E23: widget class const, bukan helper).
class _GameResultMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _GameResultMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
        ),
      ],
    );
  }
}
