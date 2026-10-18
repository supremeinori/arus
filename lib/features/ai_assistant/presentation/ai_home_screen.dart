import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../auth/presentation/auth_state.dart';
import '../domain/ai_models.dart';
import '../domain/voice_models.dart';
import 'ai_provider.dart';
import 'voice_session_controller.dart';

class AiHomeScreen extends ConsumerStatefulWidget {
  const AiHomeScreen({super.key});

  @override
  ConsumerState<AiHomeScreen> createState() => _AiHomeScreenState();
}

class _AiHomeScreenState extends ConsumerState<AiHomeScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final SpeechToText _dictationStt = SpeechToText();

  String? _selectedOutletId;
  bool _isVoiceMode = false;
  bool _isDictating = false;

  final List<String> _quickPrompts = [
    'Bagaimana ringkasan penjualan hari ini?',
    'Ada berapa sih gerai kita dan lokasinya di mana?',
    'Apakah ada produk yang butuh restock segera?',
    'Menu apa yang paling laris minggu ini?',
  ];

  @override
  void initState() {
    super.initState();
    _inputController.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = ref.read(aiPendingPromptProvider);
      if (pending != null && pending.isNotEmpty) {
        ref.read(aiPendingPromptProvider.notifier).state = null;
        _handleSend(pending);
      }
    });
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _inputController.removeListener(_onTextChanged);
    _inputController.dispose();
    _scrollController.dispose();
    _dictationStt.stop();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSend([String? presetText]) {
    final text = presetText ?? _inputController.text;
    if (text.trim().isEmpty) return;

    if (presetText == null) {
      _inputController.clear();
    }

    final auth = ref.read(authProvider);
    final outletId = _selectedOutletId ??
        (auth.user?.outlets.isNotEmpty == true ? auth.user!.outlets.first.id : null);

    ref.read(aiChatProvider.notifier).sendMessage(text, outletId: outletId).then((_) {
      _scrollToBottom();
    });
    _scrollToBottom();
  }

  Future<void> _toggleDictation() async {
    if (_isDictating) {
      await _dictationStt.stop();
      if (mounted) setState(() => _isDictating = false);
      return;
    }

    try {
      final available = await _dictationStt.initialize(
        onError: (_) {
          if (mounted) setState(() => _isDictating = false);
        },
        onStatus: (status) {
          if (status == 'notListening' || status == 'done') {
            if (mounted) setState(() => _isDictating = false);
          }
        },
      );

      if (available && mounted) {
        setState(() => _isDictating = true);
        await _dictationStt.listen(
          onResult: (result) {
            if (mounted) {
              setState(() {
                _inputController.text = result.recognizedWords;
                _inputController.selection = TextSelection.fromPosition(
                  TextPosition(offset: _inputController.text.length),
                );
              });
            }
          },
          listenOptions: SpeechListenOptions(
            localeId: 'id_ID',
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _isDictating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(aiChatProvider);
    final authState = ref.watch(authProvider);
    final outlets = authState.user?.outlets ?? [];

    if (_selectedOutletId == null && outlets.isNotEmpty) {
      _selectedOutletId = outlets.first.id;
    }

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: ClipOval(
            child: Image.asset(
              'assets/images/ai_mascot.png',
              width: 36,
              height: 36,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(
                Icons.smart_toy_outlined,
                color: AppTheme.jadeTosca,
                size: 20,
              ),
            ),
          ),
        ),
        leadingWidth: 52,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isVoiceMode ? 'ARUS Voice Mode' : 'Asisten AI Bisnis',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (outlets.isNotEmpty)
              Text(
                'Cabang: ${outlets.firstWhere((o) => o.id == _selectedOutletId, orElse: () => outlets.first).name}',
                style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMutedDark),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          if (!_isVoiceMode)
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: AppTheme.textPrimaryDark),
              tooltip: 'Mulai Percakapan Baru',
              onPressed: () {
                ref.read(aiChatProvider.notifier).startNewChat();
              },
            ),
        ],
      ),
      body: _isVoiceMode
          ? _buildVoiceModeView(chatState, authState, outlets)
          : Column(
              children: [
                if (chatState.errorMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFEF2F2),
                      border: Border(
                        bottom: BorderSide(color: AppTheme.darkCardBorder, width: 1.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            chatState.errorMessage!,
                            style: GoogleFonts.inter(color: const Color(0xFFDC2626), fontSize: 12),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: chatState.messages.isEmpty && !chatState.isLoading
                      ? _buildEmptyState()
                      : _buildMessageList(chatState.messages, chatState.isLoading),
                ),
                _buildInputBar(chatState.isLoading),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.darkCardBorder, width: 1.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                'assets/images/ai_mascot.png',
                width: 72,
                height: 72,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.analytics_outlined,
                  size: 42,
                  color: AppTheme.jadeTosca,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'ARUS AI Decision Support',
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimaryDark),
          ),
          const SizedBox(height: 8),
          Text(
            'Asisten analitik cerdas berbasis data riil (Anti-Halusinasi). Tanyakan omset, status stok, jam ramai, hingga performa gerai cabang.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: AppTheme.textMutedDark, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 28),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Rekomendasi Pertanyaan Cepat:',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimaryDark,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Column(
            children: _quickPrompts.map((prompt) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: AppTheme.darkCardSurface,
                      foregroundColor: AppTheme.textPrimaryDark,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      alignment: Alignment.centerLeft,
                      side: const BorderSide(color: AppTheme.darkCardBorder, width: 1.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.help_outline_rounded, size: 16, color: AppTheme.jadeTosca),
                    label: Text(
                      prompt,
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textPrimaryDark),
                    ),
                    onPressed: () => _handleSend(prompt),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(List<AiMessageModel> messages, bool isLoading) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      itemCount: messages.length + (isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < messages.length) {
          final msg = messages[index];
          return _buildChatBubble(msg);
        } else {
          return _buildLoadingBubble();
        }
      },
    );
  }

  Widget _buildChatBubble(AiMessageModel message) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              margin: const EdgeInsets.only(top: 2, right: 8),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.darkCardSurfaceElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.darkCardBorder, width: 1.0),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                'assets/images/ai_mascot.png',
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.smart_toy_outlined,
                  color: AppTheme.jadeTosca,
                  size: 16,
                ),
              ),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? AppTheme.jadeTosca : AppTheme.darkCardSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isUser ? AppTheme.jadeTosca : AppTheme.darkCardBorder,
                  width: 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: GoogleFonts.inter(
                      color: isUser ? Colors.white : AppTheme.textPrimaryDark,
                      fontSize: 13.5,
                      height: 1.45,
                    ),
                  ),
                  if (!isUser && message.factsUsed.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.darkCardSurfaceElevated,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.darkCardBorder, width: 1.0),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified_outlined, size: 12, color: Color(0xFF22C55E)),
                          const SizedBox(width: 4),
                          Text(
                            'Grounded Fact: ${message.factsUsed.length} fakta database',
                            style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppTheme.textSecondaryDark),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (!isUser && message.suggestion != null && message.suggestion!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.darkCardSurfaceElevated,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.darkCardBorder, width: 1.0),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.tips_and_updates_outlined, size: 14, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              message.suggestion!,
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontStyle: FontStyle.italic,
                                color: AppTheme.textSecondaryDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingBubble() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2, right: 8),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.darkCardSurfaceElevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.darkCardBorder, width: 1.0),
            ),
            child: const Icon(Icons.smart_toy_outlined, color: AppTheme.jadeTosca, size: 16),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.darkCardSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.darkCardBorder, width: 1.0),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipOval(
                  child: Image.asset(
                    'assets/images/ai_mascot.png',
                    width: 20,
                    height: 20,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(width: 6),
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.jadeTosca),
                ),
                const SizedBox(width: 10),
                Text(
                  'ARUS AI menganalisis data...',
                  style: GoogleFonts.inter(fontSize: 12.5, color: AppTheme.textMutedDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Desain Input Bar Dinamis (Ala ChatGPT - Tema Jade Tosca #00A896)
  /// [ (Expanded) TextField Ketik Pesan... ]  [ 🎤 Ikon Mic STT ]  [ 🟢 Tombol Aksi Utama ]
  Widget _buildInputBar(bool isLoading) {
    final hasText = _inputController.text.trim().isNotEmpty;
    const jadeTosca = AppTheme.jadeTosca;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: AppTheme.darkCardSurface,
        border: Border(
          top: BorderSide(color: AppTheme.darkCardBorder, width: 1.0),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                textInputAction: TextInputAction.send,
                onSubmitted: isLoading ? null : (_) => _handleSend(),
                enabled: !isLoading,
                style: GoogleFonts.inter(fontSize: 13.5, color: AppTheme.textPrimaryDark),
                decoration: InputDecoration(
                  hintText: _isDictating
                      ? 'Mendengarkan suara Anda...'
                      : 'Tanyakan sesuatu tentang bisnis...',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 13,
                    color: _isDictating ? jadeTosca : AppTheme.textMutedDark,
                  ),
                  filled: true,
                  fillColor: AppTheme.darkCardSurfaceElevated,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppTheme.darkCardBorder, width: 1.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: _isDictating ? jadeTosca : AppTheme.darkCardBorder,
                      width: 1.0,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: jadeTosca, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),

            // 1. Ikon Mic STT (Dictation Mode)
            IconButton(
              icon: Icon(
                _isDictating ? Icons.mic : Icons.mic_none_rounded,
                color: _isDictating ? const Color(0xFFEF4444) : AppTheme.textMutedDark,
                size: 24,
              ),
              tooltip: _isDictating ? 'Hentikan Dikte' : 'Dikte Suara (STT)',
              onPressed: isLoading ? null : _toggleDictation,
            ),
            const SizedBox(width: 4),

            // 2. Tombol Aksi Utama (Bulat, Warna Jade Tosca #00A896)
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: jadeTosca,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(
                  hasText ? Icons.arrow_upward_rounded : Icons.graphic_eq_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                tooltip: hasText ? 'Kirim Pesan Teks' : 'Buka ARUS Voice Mode',
                onPressed: isLoading
                    ? null
                    : () {
                        if (hasText) {
                          _handleSend();
                        } else {
                          setState(() => _isVoiceMode = true);
                        }
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Antarmuka "ARUS Voice Mode" (Push-to-Talk Tektokan dengan Auto-Cut)
  Widget _buildVoiceModeView(
    AiChatState chatState,
    AuthState authState,
    List<dynamic> outlets,
  ) {
    final voiceState = ref.watch(voiceSessionProvider);
    final voiceNotifier = ref.read(voiceSessionProvider.notifier);
    const jadeTosca = AppTheme.jadeTosca;

    Color statusColor;
    String statusTitle;
    IconData statusIcon;

    switch (voiceState.sessionState) {
      case VoiceSessionState.listening:
        statusColor = const Color(0xFFEF4444);
        statusTitle = 'Mendengarkan...';
        statusIcon = Icons.mic_rounded;
        break;
      case VoiceSessionState.processingFiller:
        statusColor = const Color(0xFFF59E0B);
        statusTitle = 'Menganalisis...';
        statusIcon = Icons.hourglass_top_rounded;
        break;
      case VoiceSessionState.speakingResult:
        statusColor = jadeTosca;
        statusTitle = 'Gadis Berbicara...';
        statusIcon = Icons.volume_up_rounded;
        break;
      case VoiceSessionState.idle:
        statusColor = AppTheme.jadeTosca;
        statusTitle = 'Siap Berbicara';
        statusIcon = Icons.graphic_eq_rounded;
        break;
    }

    return Column(
      children: [
        // Top Bar Voice Mode
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.darkCardSurfaceElevated,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.darkCardBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 6),
                    Text(
                      statusTitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppTheme.textPrimaryDark),
                tooltip: 'Kembali ke Chat Teks',
                onPressed: () {
                  voiceNotifier.stopSession();
                  setState(() => _isVoiceMode = false);
                },
              ),
            ],
          ),
        ),

        const Divider(height: 1, color: AppTheme.darkCardBorder),

        // Center Area: Mascot Pulse & Live Transcript Box
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: voiceState.sessionState == VoiceSessionState.listening ||
                              voiceState.sessionState == VoiceSessionState.speakingResult
                          ? 120
                          : 96,
                      height: voiceState.sessionState == VoiceSessionState.listening ||
                              voiceState.sessionState == VoiceSessionState.speakingResult
                          ? 120
                          : 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: statusColor.withValues(alpha: 0.12),
                      ),
                    ),
                    ClipOval(
                      child: Image.asset(
                        'assets/images/ai_mascot.png',
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => CircleAvatar(
                          radius: 36,
                          backgroundColor: jadeTosca,
                          child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 36),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Dialog / Live Transcript Card
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 80),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.darkCardSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.darkCardBorder, width: 1.0),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        voiceState.liveTranscript.isNotEmpty
                            ? voiceState.liveTranscript
                            : voiceState.activeFillerText != null
                                ? voiceState.activeFillerText!
                                : voiceState.lastAiSpokenText != null
                                    ? voiceState.lastAiSpokenText!
                                    : 'Tahan tombol di bawah untuk berbicara dengan Gadis (ARUS Voice)...',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: voiceState.liveTranscript.isNotEmpty || voiceState.lastAiSpokenText != null
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: voiceState.liveTranscript.isNotEmpty
                              ? AppTheme.textPrimaryDark
                              : voiceState.lastAiSpokenText != null
                                  ? jadeTosca
                                  : AppTheme.textMutedDark,
                          height: 1.45,
                        ),
                      ),
                      if (voiceState.errorMessage != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          voiceState.errorMessage!,
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFEF4444)),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Bottom Action Area: Big Push-to-Talk (PTT) Button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: const BoxDecoration(
            color: AppTheme.darkCardSurface,
            border: Border(
              top: BorderSide(color: AppTheme.darkCardBorder, width: 1.0),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTapDown: (_) => voiceNotifier.onPttPressDown(),
                  onTapUp: (_) => voiceNotifier.onPttRelease(outletId: _selectedOutletId),
                  onTapCancel: () => voiceNotifier.onPttRelease(outletId: _selectedOutletId),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: voiceState.sessionState == VoiceSessionState.listening
                          ? const Color(0xFFEF4444)
                          : jadeTosca,
                      boxShadow: [
                        BoxShadow(
                          color: (voiceState.sessionState == VoiceSessionState.listening
                                  ? const Color(0xFFEF4444)
                                  : jadeTosca)
                              .withValues(alpha: 0.35),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        voiceState.sessionState == VoiceSessionState.listening
                            ? Icons.mic_rounded
                            : Icons.mic_none_rounded,
                        color: Colors.white,
                        size: 38,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  voiceState.sessionState == VoiceSessionState.listening
                      ? 'Lepas tombol untuk mengirim suara'
                      : voiceState.sessionState == VoiceSessionState.speakingResult
                          ? 'Sentuh tombol untuk memotong (Auto-Cut)'
                          : 'Tahan untuk bicara, lepas untuk kirim',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textMutedDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
