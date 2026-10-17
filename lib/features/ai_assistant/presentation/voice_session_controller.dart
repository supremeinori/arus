import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../data/ai_repository.dart';
import '../domain/voice_models.dart';
import 'ai_provider.dart';

class VoiceSessionStateData {
  final VoiceSessionState sessionState;
  final String liveTranscript;
  final String? lastAiSpokenText;
  final String? activeFillerText;
  final bool isMicInitialized;
  final String? errorMessage;

  const VoiceSessionStateData({
    this.sessionState = VoiceSessionState.idle,
    this.liveTranscript = '',
    this.lastAiSpokenText,
    this.activeFillerText,
    this.isMicInitialized = false,
    this.errorMessage,
  });

  VoiceSessionStateData copyWith({
    VoiceSessionState? sessionState,
    String? liveTranscript,
    String? lastAiSpokenText,
    String? activeFillerText,
    bool? isMicInitialized,
    String? errorMessage,
  }) {
    return VoiceSessionStateData(
      sessionState: sessionState ?? this.sessionState,
      liveTranscript: liveTranscript ?? this.liveTranscript,
      lastAiSpokenText: lastAiSpokenText ?? this.lastAiSpokenText,
      activeFillerText: activeFillerText ?? this.activeFillerText,
      isMicInitialized: isMicInitialized ?? this.isMicInitialized,
      errorMessage: errorMessage,
    );
  }
}

final voiceSessionProvider = StateNotifierProvider<VoiceSessionNotifier, VoiceSessionStateData>((ref) {
  final repo = ref.watch(aiRepositoryProvider);
  return VoiceSessionNotifier(ref, repo);
});

class VoiceSessionNotifier extends StateNotifier<VoiceSessionStateData> {
  final Ref _ref;
  final AiRepository _repository;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final SpeechToText _speechToText = SpeechToText();
  StreamSubscription? _playerCompleteSubscription;

  int _currentRequestId = 0;

  static const List<String> fillerTemplates = [
    'Baik, saya cek datanya dulu ya...',
    'Sebentar ya, saya periksa laporan ARUS dulu...',
    'Oke, tunggu sebentar, sedang saya hitung...',
    'Siap, saya carikan informasinya sekarang...',
  ];

  final Map<String, String> _fillerCache = {};

  VoiceSessionNotifier(this._ref, this._repository) : super(const VoiceSessionStateData()) {
    _init();
  }

  Future<void> _init() async {
    // Listen to player completion
    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted && state.sessionState == VoiceSessionState.speakingResult) {
        state = state.copyWith(sessionState: VoiceSessionState.idle);
      }
    });

    // Initialize speech to text
    try {
      final available = await _speechToText.initialize(
        onError: (val) {
          debugPrint('[STT Error] $val');
        },
        onStatus: (status) {
          debugPrint('[STT Status] $status');
        },
      );
      if (mounted) {
        state = state.copyWith(isMicInitialized: available);
      }
    } catch (e) {
      debugPrint('[STT Init Exception] $e');
    }

    // Pre-cache filler audios in background for 0ms latency
    _preCacheFillers();
  }

  Future<void> _preCacheFillers() async {
    for (final text in fillerTemplates) {
      if (!_fillerCache.containsKey(text)) {
        try {
          final audio = await _repository.getTtsAudio(text);
          if (audio.isNotEmpty) {
            _fillerCache[text] = audio;
          }
        } catch (_) {}
      }
    }
  }

  /// AUTO-CUT & PUSH-TO-TALK PRESS DOWN:
  /// Memotong instan (<50ms) suara AI jika sedang bicara, dan mengaktifkan STT.
  Future<void> onPttPressDown() async {
    _currentRequestId++;

    // AUTO-CUT: Matikan audio detik ini juga jika sedang bicara atau memutar filler
    if (state.sessionState == VoiceSessionState.speakingResult ||
        state.sessionState == VoiceSessionState.processingFiller) {
      await _audioPlayer.stop();
    }

    if (!mounted) return;
    state = state.copyWith(
      sessionState: VoiceSessionState.listening,
      liveTranscript: '',
      activeFillerText: null,
      errorMessage: null,
    );

    try {
      if (_speechToText.isAvailable) {
        await _speechToText.listen(
          onResult: (result) {
            if (mounted) {
              state = state.copyWith(liveTranscript: result.recognizedWords);
            }
          },
          listenOptions: SpeechListenOptions(
            localeId: 'id_ID',
            listenMode: ListenMode.dictation,
            cancelOnError: false,
            partialResults: true,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(errorMessage: 'Gagal mendengarkan mikrofon: $e');
      }
    }
  }

  /// PUSH-TO-TALK RELEASE:
  /// Menghentikan mikrofon, memutar instant filler audio, dan mengirim prompt ke backend.
  Future<void> onPttRelease({String? outletId, String? screenContext}) async {
    try {
      if (_speechToText.isListening) {
        await _speechToText.stop();
      }
    } catch (_) {}

    if (!mounted) return;
    final transcript = state.liveTranscript.trim();
    if (transcript.isEmpty) {
      state = state.copyWith(sessionState: VoiceSessionState.idle);
      return;
    }

    // Pilih 1 kalimat filler acak
    final filler = fillerTemplates[Random().nextInt(fillerTemplates.length)];

    state = state.copyWith(
      sessionState: VoiceSessionState.processingFiller,
      activeFillerText: filler,
    );

    // Putar audio filler instan (0ms delay jika sudah ada di cache)
    _playFillerAudio(filler);

    final requestId = _currentRequestId;

    // Kirim request ke backend di background
    try {
      final chatNotifier = _ref.read(aiChatProvider.notifier);
      final aiMessage = await chatNotifier.sendMessage(transcript, outletId: outletId);

      // Cek apakah user telah melakukan AUTO-CUT (menekan PTT lagi) saat request berjalan
      if (requestId != _currentRequestId || !mounted) {
        return;
      }

      // Hentikan filler audio
      await _audioPlayer.stop();
      if (!mounted) return;

      if (aiMessage != null && aiMessage.audioBase64 != null && aiMessage.audioBase64!.isNotEmpty) {
        state = state.copyWith(
          sessionState: VoiceSessionState.speakingResult,
          lastAiSpokenText: aiMessage.voiceSummary ?? aiMessage.content,
        );
        final bytes = base64Decode(aiMessage.audioBase64!);
        await _audioPlayer.play(BytesSource(bytes));
      } else if (aiMessage != null) {
        // Fallback: TTS on the fly jika backend belum menyertakan audio_base64
        final textToSpeak = aiMessage.voiceSummary ?? aiMessage.content;
        state = state.copyWith(
          sessionState: VoiceSessionState.speakingResult,
          lastAiSpokenText: textToSpeak,
        );
        final audio = await _repository.getTtsAudio(textToSpeak);
        if (requestId == _currentRequestId && mounted && audio.isNotEmpty) {
          final bytes = base64Decode(audio);
          await _audioPlayer.play(BytesSource(bytes));
        } else if (mounted) {
          state = state.copyWith(sessionState: VoiceSessionState.idle);
        }
      } else {
        state = state.copyWith(sessionState: VoiceSessionState.idle);
      }
    } catch (e) {
      if (requestId == _currentRequestId && mounted) {
        await _audioPlayer.stop();
        if (mounted) {
          state = state.copyWith(
            sessionState: VoiceSessionState.idle,
            errorMessage: 'Gagal memproses suara: $e',
          );
        }
      }
    }
  }

  Future<void> _playFillerAudio(String text) async {
    final cached = _fillerCache[text];
    if (cached != null && cached.isNotEmpty) {
      try {
        final bytes = base64Decode(cached);
        await _audioPlayer.play(BytesSource(bytes));
      } catch (_) {}
    } else {
      // Ambil dan putar jika belum di-cache
      try {
        final audio = await _repository.getTtsAudio(text);
        if (audio.isNotEmpty) {
          _fillerCache[text] = audio;
          if (mounted && state.sessionState == VoiceSessionState.processingFiller) {
            final bytes = base64Decode(audio);
            await _audioPlayer.play(BytesSource(bytes));
          }
        }
      } catch (_) {}
    }
  }

  /// Menghentikan seluruh audio & sesi suara secara paksa
  Future<void> stopSession() async {
    _currentRequestId++;
    try {
      await _audioPlayer.stop();
    } catch (_) {}
    try {
      if (_speechToText.isListening) {
        await _speechToText.stop();
      }
    } catch (_) {}
    if (mounted) {
      state = state.copyWith(
        sessionState: VoiceSessionState.idle,
        liveTranscript: '',
        activeFillerText: null,
      );
    }
  }

  @override
  void dispose() {
    if (!mounted) return;
    _playerCompleteSubscription?.cancel();
    _playerCompleteSubscription = null;
    _audioPlayer.stop();
    _speechToText.stop();
    _audioPlayer.dispose();
    super.dispose();
  }
}
