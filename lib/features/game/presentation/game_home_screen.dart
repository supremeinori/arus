import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../data/game_repository.dart';
import '../data/synth_audio_service.dart';
import '../domain/tilt_direction.dart';
import '../../sensors/presentation/sensor_provider.dart';

enum GameState { lobby, loading, playing, result }

/// Status ketersediaan sensor untuk kontrol gyroscope.
enum _GyroSensorState { initializing, ready, unavailable }

class GameHomeScreen extends ConsumerStatefulWidget {
  const GameHomeScreen({super.key, this.clock});

  /// Sumber waktu seam untuk pengujian.
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

  // Sistem Combo Beruntun
  int _comboStreak = 0;
  int _maxComboStreak = 0;

  // Layanan Sintesis Audio Synth Procedural
  final SynthAudioService _synthAudio = SynthAudioService();

  // Timer per soal (10 detik)
  static const int _timePerQuestion = 10;
  int _remainingSeconds = _timePerQuestion;
  Timer? _countdownTimer;
  Timer? _sessionTimer;

  // State Tombol Interaksi (Feedback Jawaban)
  String? _selectedOptionKey;
  bool _isAnswerChecked = false;

  // Gyroscope 2-Arah (Miring Kiri & Miring Kanan) — Respon Instan & Debounce
  static const Duration _gyroPollInterval = Duration(milliseconds: 30);
  static const Duration _gyroSensorTimeout = Duration(milliseconds: 2500);

  final TiltInstantTrigger _gyroTrigger = TiltInstantTrigger(threshold: kTilt2WayThreshold);
  Timer? _gyroPollTimer;
  Tilt2WayDirection? _liveTiltDirection; // untuk visual highlight real-time di tombol
  _GyroSensorState _gyroSensorState = _GyroSensorState.initializing;
  DateTime? _lastGyroSampleAt;
  int _gyroStalePolls = 0;

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
  // GYROSCOPE 2-ARAH (RESPON INSTAN + DEBOUNCE)
  // ==========================================

  void _startGyroPolling() {
    _stopGyroPolling();
    if (_gameState != GameState.playing) return;
    _lastGyroSampleAt = ref.read(gyroscopeProvider).timestamp;
    _gyroPollTimer = Timer.periodic(_gyroPollInterval, (_) => _pollGyro());
  }

  void _stopGyroPolling() {
    _gyroPollTimer?.cancel();
    _gyroPollTimer = null;
    _resetGyroState();
    _gyroSensorState = _GyroSensorState.initializing;
    _lastGyroSampleAt = null;
    _gyroStalePolls = 0;
  }

  void _resetGyroState() {
    _gyroTrigger.reset();
    _liveTiltDirection = null;
  }

  void _pollGyro() {
    if (!mounted) return;
    if (_gameState != GameState.playing || _isAnswerChecked) return;

    final reading = ref.read(gyroscopeProvider);

    // Deteksi ketersediaan sensor
    if (reading.timestamp != _lastGyroSampleAt) {
      _lastGyroSampleAt = reading.timestamp;
      _gyroStalePolls = 0;
      if (_gyroSensorState != _GyroSensorState.ready) {
        setState(() => _gyroSensorState = _GyroSensorState.ready);
      }
    } else {
      _gyroStalePolls++;
      if (_gyroStalePolls >= _gyroSensorStalePollLimit &&
          _gyroSensorState != _GyroSensorState.unavailable) {
        setState(() => _gyroSensorState = _GyroSensorState.unavailable);
        _resetGyroState();
      }
    }

    if (_gyroSensorState != _GyroSensorState.ready) return;
    if (!_gyroControlEnabled) return;

    // 1. Highlight visual kemiringan secara real-time
    final currentTilt = detect2WayTilt(roll: reading.roll, threshold: 14.0);
    if (currentTilt != _liveTiltDirection) {
      setState(() => _liveTiltDirection = currentTilt);
    }

    // 2. INPUT KEMIRINGAN LANGSUNG (INSTAN TANPA TAHAN 3 DETIK) + DEBOUNCE
    final triggeredDirection = _gyroTrigger.update(roll: reading.roll);
    if (triggeredDirection != null) {
      _handleInstantGyroAnswer(triggeredDirection);
    }
  }

  void _handleInstantGyroAnswer(Tilt2WayDirection direction) {
    if (_questions.isEmpty || _currentQuestionIndex >= _questions.length) return;
    final options = _questions[_currentQuestionIndex].options;
    final idx = direction.optionIndex;
    if (idx < options.length) {
      _selectOption(options[idx].key);
    }
  }

  bool get _gyroControlEnabled {
    final settings = ref.read(sensorSettingsProvider).valueOrNull;
    return settings?.tiltEnabled ?? true;
  }

  int get _gyroSensorStalePollLimit =>
      (_gyroSensorTimeout.inMilliseconds / _gyroPollInterval.inMilliseconds).ceil();

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _sessionTimer?.cancel();
    _stopGyroPolling();
    _synthAudio.dispose();
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

  /// Memformat soal agar selalu memiliki tepat 2 opsi:
  /// Opsi 1 (Kiri / A) dan Opsi 2 (Kanan / B).
  List<GameQuestionModel> _formatTwoChoiceQuestions(List<GameQuestionModel> rawQuestions) {
    final rng = math.Random();
    return rawQuestions.map((q) {
      if (q.options.length == 2) return q;

      // Ambil jawaban benar
      final correctOpt = q.options.firstWhere(
        (o) => o.key == q.correctOptionKey,
        orElse: () => q.options.first,
      );

      // Ambil 1 opsi pengecoh secara acak
      final distractors = q.options.where((o) => o.key != q.correctOptionKey).toList();
      final chosenDistractor = distractors.isNotEmpty
          ? distractors[rng.nextInt(distractors.length)]
          : GameQuestionOption(key: 'opt_distractor', label: 'Pengecoh', value: 'Pengecoh');

      // Acak posisi kiri vs kanan (agar jawaban benar tidak selalu di kiri)
      final bool correctOnLeft = rng.nextBool();
      final leftOpt = correctOnLeft ? correctOpt : chosenDistractor;
      final rightOpt = correctOnLeft ? chosenDistractor : correctOpt;

      final twoOptions = [
        GameQuestionOption(key: leftOpt.key, label: leftOpt.label, value: leftOpt.value),
        GameQuestionOption(key: rightOpt.key, label: rightOpt.label, value: rightOpt.value),
      ];

      return GameQuestionModel(
        questionNo: q.questionNo,
        productId: q.productId,
        imageUrl: q.imageUrl,
        categoryName: q.categoryName,
        promptTitle: q.promptTitle,
        options: twoOptions,
        correctOptionKey: q.correctOptionKey,
      );
    }).toList();
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
      _comboStreak = 0;
      _maxComboStreak = 0;
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

      final formattedQuestions = _formatTwoChoiceQuestions(list);

      if (mounted) {
        setState(() {
          _questions = formattedQuestions;
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

    // Waktu habis = reset combo & putar SFX salah
    _comboStreak = 0;
    _synthAudio.playWrong();

    setState(() {
      _remainingSeconds = 0;
      _isAnswerChecked = true;
    });

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) _goToNextQuestion();
    });
  }

  void _selectOption(String optionKey) {
    if (_isAnswerChecked) return; // Cegah double trigger

    _countdownTimer?.cancel();
    final currentQ = _questions[_currentQuestionIndex];
    final isCorrect = optionKey == currentQ.correctOptionKey;

    if (isCorrect) {
      HapticFeedback.lightImpact();
      _comboStreak++;
      if (_comboStreak > _maxComboStreak) {
        _maxComboStreak = _comboStreak;
      }

      // Skor: 100 dasar + bonus waktu + bonus combo
      final timeBonus = _remainingSeconds * 10;
      final comboBonus = _comboStreak > 1 ? (_comboStreak - 1) * 25 : 0;
      _currentScore += (100 + timeBonus + comboBonus);
      _correctCount++;

      // Audio Feedback Synth
      if (_comboStreak > 1) {
        _synthAudio.playCombo(_comboStreak);
      } else {
        _synthAudio.playCorrect();
      }
    } else {
      HapticFeedback.heavyImpact();
      _comboStreak = 0;
      _synthAudio.playWrong();
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

    // Sound effect selesai game
    _synthAudio.playGameOver();

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
        _loadUserStats();
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
        actions: [
          IconButton(
            icon: Icon(
              _synthAudio.isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              color: _synthAudio.isMuted ? AppTheme.textMuted : AppTheme.primary,
            ),
            tooltip: _synthAudio.isMuted ? 'Nyalakan Audio Synth' : 'Matikan Audio (Mute)',
            onPressed: () {
              setState(() {
                _synthAudio.toggleMute();
              });
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _synthAudio.isMuted
                        ? 'Audio synth dimatikan (Muted)'
                        : 'Audio synth aktif (Unmuted)',
                  ),
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
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
        return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
      case GameState.playing:
        return _buildPlayingView();
      case GameState.result:
        return _buildResultView();
    }
  }

  // ==========================================
  // VIEW 1: LOBBY
  // ==========================================
  Widget _buildLobbyView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner Maskot Game
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F766E), Color(0xFF0D9488)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'MINI GAME POS • 2-ARAH GYRO',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Guess the Menu',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Miringkan HP ke KIRI atau KANAN untuk menjawab instan dengan sound effect synth!',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.9),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.sports_esports_rounded,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // High Score Stats Cards
          Text(
            'Rekor Terbaik Anda',
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (_isLoadingStats)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
          else
            Row(
              children: [
                Expanded(
                  child: _GameStatCard(
                    icon: Icons.image_search_rounded,
                    title: 'Tebak Nama',
                    score: _userStats?.bestGuessName ?? 0,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _GameStatCard(
                    icon: Icons.payments_outlined,
                    title: 'Tebak Harga',
                    score: _userStats?.bestGuessPrice ?? 0,
                    color: const Color(0xFF059669),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 24),

          // Pilihan Mode Permainan
          Text(
            'Pilih Mode Permainan',
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),

          _GameModeCard(
            modeKey: 'guess_name',
            icon: Icons.fastfood_rounded,
            title: 'Mode 1: Tebak Nama Menu',
            desc: 'Lihat gambar produk POS lalu miringkan HP ke kiri atau kanan untuk memilih nama menu yang tepat.',
            badgeText: '5 Soal • 2 Pilihan Instan',
            color: AppTheme.primary,
            onTap: _startGame,
          ),
          const SizedBox(height: 12),

          _GameModeCard(
            modeKey: 'guess_price',
            icon: Icons.price_check_rounded,
            title: 'Mode 2: Tebak Harga Jual',
            desc: 'Hafalkan harga kasir POS! Miringkan HP ke kiri atau kanan untuk menebak harga jual yang tepat.',
            badgeText: '5 Soal • 2 Pilihan Instan',
            color: const Color(0xFF059669),
            onTap: _startGame,
          ),
        ],
      ),
    );
  }

  // ==========================================
  // VIEW 2: GAMEPLAY (2 PILIHAN INSTAN + COMBO)
  // ==========================================
  Widget _buildPlayingView() {
    if (_questions.isEmpty || _currentQuestionIndex >= _questions.length) {
      return const SizedBox.shrink();
    }

    final currentQ = _questions[_currentQuestionIndex];
    final timerProgress = _remainingSeconds / _timePerQuestion;
    final gyroEnabled = _gyroControlEnabled;

    return Column(
      children: [
        // Header Status Permainan & Combo
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Soal ${_currentQuestionIndex + 1} dari ${_questions.length}',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: AppTheme.textPrimaryLight,
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: AppTheme.warningAmber, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        '$_currentScore Poin',
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
              const SizedBox(height: 8),

              // Animated Combo Streak Banner
              if (_comboStreak >= 2) ...[
                AnimatedScale(
                  scale: _comboStreak >= 2 ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.elasticOut,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33F59E0B),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.local_fire_department_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'COMBO ${_comboStreak}X BERUNTUN! (+${(_comboStreak - 1) * 25} Bonus)',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Progress Bar Waktu Hitung Mundur (10 detik)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: timerProgress,
                  minHeight: 7,
                  backgroundColor: AppTheme.lightCardBorder,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _remainingSeconds <= 3 ? AppTheme.error : AppTheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '⏱️ Sisa Waktu: $_remainingSeconds dtk',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: _remainingSeconds <= 3 ? AppTheme.error : AppTheme.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // Panel Gyroscope 2-Arah (Miring Kiri & Miring Kanan)
              _Gyro2WayPanel(
                enabled: gyroEnabled,
                sensorState: _gyroSensorState,
                liveTilt: _liveTiltDirection,
                isAnswerChecked: _isAnswerChecked,
              ),
            ],
          ),
        ),

        // Area Foto Menu & Pertanyaan
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
            child: Column(
              children: [
                // Badge Kategori
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    currentQ.categoryName,
                    style: GoogleFonts.inter(
                      color: AppTheme.primary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Card Gambar Menu
                Container(
                  width: double.infinity,
                  height: 180,
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
                        child: Icon(Icons.fastfood_rounded, size: 54, color: AppTheme.textMuted),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Judul Pertanyaan
                Text(
                  currentQ.promptTitle,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: _selectedMode == 'guess_price' ? 17 : 14.5,
                    color: AppTheme.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 14),

                // DUA PILIHAN JAWABAN (KIRI vs KANAN)
                if (currentQ.options.length >= 2) ...[
                  Row(
                    children: [
                      // Opsi 1: Miring Kiri
                      Expanded(
                        child: _Game2WayOptionCard(
                          direction: Tilt2WayDirection.left,
                          opt: currentQ.options[0],
                          isHighlighted: _liveTiltDirection == Tilt2WayDirection.left && !_isAnswerChecked,
                          correctKey: currentQ.correctOptionKey,
                          isAnswerChecked: _isAnswerChecked,
                          selectedOptionKey: _selectedOptionKey,
                          onSelect: _selectOption,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Opsi 2: Miring Kanan
                      Expanded(
                        child: _Game2WayOptionCard(
                          direction: Tilt2WayDirection.right,
                          opt: currentQ.options[1],
                          isHighlighted: _liveTiltDirection == Tilt2WayDirection.right && !_isAnswerChecked,
                          correctKey: currentQ.correctOptionKey,
                          isAnswerChecked: _isAnswerChecked,
                          selectedOptionKey: _selectedOptionKey,
                          onSelect: _selectOption,
                        ),
                      ),
                    ],
                  ),
                ],
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
          const SizedBox(height: 16),
          // Ikon Trofi
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppTheme.warningAmber.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              size: 64,
              color: AppTheme.warningAmber,
            ),
          ),
          const SizedBox(height: 14),

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
          const SizedBox(height: 4),
          Text(
            badgeTitle,
            style: GoogleFonts.inter(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: badgeColor,
            ),
          ),
          const SizedBox(height: 20),

          // Card Skor Utama
          Container(
            padding: const EdgeInsets.all(18),
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
                const SizedBox(height: 4),
                Text(
                  '$_currentScore',
                  style: GoogleFonts.inter(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primary,
                  ),
                ),
                const Divider(height: 28),
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
                      label: 'Combo Beruntun',
                      value: '$_maxComboStreak x 🔥',
                      icon: Icons.local_fire_department_rounded,
                      color: const Color(0xFFF59E0B),
                    ),
                    _GameResultMetric(
                      label: 'Total Waktu',
                      value: '$_totalDurationSec dtk',
                      icon: Icons.timer_outlined,
                      color: AppTheme.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Tombol Aksi
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _gameState = GameState.lobby),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppTheme.lightCardBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Menu Utama', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _startGame(_selectedMode),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Main Lagi 🔁',
                    style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Panel status gyroscope 2-arah (Kiri & Kanan) dengan visual live indicator
class _Gyro2WayPanel extends StatelessWidget {
  final bool enabled;
  final _GyroSensorState sensorState;
  final Tilt2WayDirection? liveTilt;
  final bool isAnswerChecked;

  const _Gyro2WayPanel({
    required this.enabled,
    required this.sensorState,
    required this.liveTilt,
    required this.isAnswerChecked,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return _buildNotice(
        icon: Icons.screen_rotation_rounded,
        text: 'Kontrol miring nonaktif. Gunakan tombol sentuh.',
        color: AppTheme.textSecondary,
      );
    }

    if (sensorState == _GyroSensorState.unavailable) {
      return _buildNotice(
        icon: Icons.touch_app_rounded,
        text: 'Sensor tidak tersedia. Gunakan tombol sentuh.',
        color: AppTheme.error,
      );
    }

    if (sensorState == _GyroSensorState.initializing) {
      return _buildNotice(
        icon: Icons.sensors_rounded,
        text: 'Mengaktifkan sensor gyroscope...',
        color: AppTheme.textSecondary,
      );
    }

    if (isAnswerChecked) {
      return _buildNotice(
        icon: Icons.check_circle_rounded,
        text: 'Jawaban terkunci.',
        color: AppTheme.successGreen,
      );
    }

    // Sensor aktif: Tampilkan kontrol 2-arah
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.lightCardSurfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.lightCardBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildDirectionPill(
            direction: Tilt2WayDirection.left,
            isActive: liveTilt == Tilt2WayDirection.left,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              'atau',
              style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted),
            ),
          ),
          _buildDirectionPill(
            direction: Tilt2WayDirection.right,
            isActive: liveTilt == Tilt2WayDirection.right,
          ),
        ],
      ),
    );
  }

  Widget _buildDirectionPill({
    required Tilt2WayDirection direction,
    required bool isActive,
  }) {
    final isLeft = direction == Tilt2WayDirection.left;
    final color = isActive ? AppTheme.jadeTosca : AppTheme.textSecondary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isActive ? AppTheme.jadeTosca.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isActive ? AppTheme.jadeTosca : Colors.transparent,
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLeft) Icon(Icons.arrow_back_rounded, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            isLeft ? '⬅️ Miring Kiri' : 'Miring Kanan ➡️',
            style: GoogleFonts.inter(
              fontSize: 10.5,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
              color: color,
            ),
          ),
          if (!isLeft) Icon(Icons.arrow_forward_rounded, size: 12, color: color),
        ],
      ),
    );
  }

  Widget _buildNotice({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.lightCardSurfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.lightCardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
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
}

/// Kartu pilihan jawaban 2-arah (Miring Kiri atau Miring Kanan)
class _Game2WayOptionCard extends StatelessWidget {
  final Tilt2WayDirection direction;
  final GameQuestionOption opt;
  final bool isHighlighted;
  final String correctKey;
  final bool isAnswerChecked;
  final String? selectedOptionKey;
  final ValueChanged<String> onSelect;

  const _Game2WayOptionCard({
    required this.direction,
    required this.opt,
    required this.isHighlighted,
    required this.correctKey,
    required this.isAnswerChecked,
    required this.selectedOptionKey,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    Color cardColor = isHighlighted ? const Color(0xFFF0FDFA) : Colors.white;
    Color borderColor = isHighlighted ? AppTheme.jadeTosca : AppTheme.lightCardBorder;
    Color textColor = AppTheme.textPrimaryLight;
    Widget? statusIcon;

    if (isAnswerChecked) {
      if (opt.key == correctKey) {
        cardColor = const Color(0xFFDCFCE7);
        borderColor = const Color(0xFF16A34A);
        textColor = const Color(0xFF15803D);
        statusIcon = const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 18);
      } else if (opt.key == selectedOptionKey) {
        cardColor = const Color(0xFFFEE2E2);
        borderColor = const Color(0xFFDC2626);
        textColor = const Color(0xFFB91C1C);
        statusIcon = const Icon(Icons.cancel_rounded, color: Color(0xFFDC2626), size: 18);
      }
    }

    final isLeft = direction == Tilt2WayDirection.left;

    return InkWell(
      onTap: isAnswerChecked ? null : () => onSelect(opt.key),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: borderColor,
            width: isHighlighted || (isAnswerChecked && opt.key == correctKey) ? 2.0 : 1.2,
          ),
          boxShadow: isHighlighted
              ? [
                  BoxShadow(
                    color: AppTheme.jadeTosca.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Arah & Huruf Opsi
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: isHighlighted
                        ? AppTheme.jadeTosca
                        : AppTheme.lightCardSurfaceElevated,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isLeft)
                        Icon(
                          Icons.arrow_back_rounded,
                          size: 11,
                          color: isHighlighted ? Colors.white : AppTheme.textSecondary,
                        ),
                      Text(
                        isLeft ? ' KIRI (${direction.letter})' : '(${direction.letter}) KANAN ',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                          color: isHighlighted ? Colors.white : AppTheme.textSecondary,
                        ),
                      ),
                      if (!isLeft)
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 11,
                          color: isHighlighted ? Colors.white : AppTheme.textSecondary,
                        ),
                    ],
                  ),
                ),
                ?statusIcon,
              ],
            ),
            const SizedBox(height: 10),

            // Teks Pilihan Jawaban
            Text(
              opt.label,
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
                color: textColor,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.lightCardBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 10.5),
                ),
                Text(
                  '$score Poin',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
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
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14.5),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    desc,
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 11.5, height: 1.3),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badgeText,
                      style: GoogleFonts.inter(
                        color: color,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }
}

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
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        Text(
          label,
          style: TextStyle(color: AppTheme.textMuted, fontSize: 10.5),
        ),
      ],
    );
  }
}
