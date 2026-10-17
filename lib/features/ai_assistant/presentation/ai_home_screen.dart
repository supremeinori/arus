import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/auth_provider.dart';
import '../domain/ai_models.dart';
import 'ai_provider.dart';

class AiHomeScreen extends ConsumerStatefulWidget {
  const AiHomeScreen({super.key});

  @override
  ConsumerState<AiHomeScreen> createState() => _AiHomeScreenState();
}

class _AiHomeScreenState extends ConsumerState<AiHomeScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _selectedOutletId;

  final List<String> _quickPrompts = [
    'Bagaimana ringkasan penjualan hari ini?',
    'Ada berapa sih gerai kita dan lokasinya di mana?',
    'Apakah ada produk yang butuh restock segera?',
    'Menu apa yang paling laris minggu ini?',
  ];

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
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

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(aiChatProvider);
    final authState = ref.watch(authProvider);
    final outlets = authState.user?.outlets ?? [];

    if (_selectedOutletId == null && outlets.isNotEmpty) {
      _selectedOutletId = outlets.first.id;
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Asisten AI Bisnis',
              style: GoogleFonts.lexend(fontSize: 16, fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (outlets.isNotEmpty)
              Text(
                'Cabang: ${outlets.firstWhere((o) => o.id == _selectedOutletId, orElse: () => outlets.first).name}',
                style: GoogleFonts.lexend(fontSize: 11, color: const Color(0xFF64748B)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.accentBlack),
            tooltip: 'Mulai Percakapan Baru',
            onPressed: () {
              ref.read(aiChatProvider.notifier).startNewChat();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (chatState.errorMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFFFEF2F2),
                border: Border(
                  bottom: BorderSide(color: AppTheme.borderOutline, width: 1.5),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      chatState.errorMessage!,
                      style: GoogleFonts.lexend(color: const Color(0xFFDC2626), fontSize: 12),
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
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.borderOutline, width: 1.5),
            ),
            child: const Icon(
              Icons.analytics_outlined,
              size: 42,
              color: AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'ARUS AI Decision Support',
            style: GoogleFonts.lexend(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.accentBlack),
          ),
          const SizedBox(height: 8),
          Text(
            'Asisten analitik cerdas berbasis data riil (Anti-Halusinasi). Tanyakan omset, status stok, jam ramai, hingga performa gerai cabang.',
            textAlign: TextAlign.center,
            style: GoogleFonts.lexend(color: const Color(0xFF475569), fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 28),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Rekomendasi Pertanyaan Cepat:',
              style: GoogleFonts.lexend(
                fontWeight: FontWeight.w700,
                color: AppTheme.accentBlack,
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
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.accentBlack,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      alignment: Alignment.centerLeft,
                      side: const BorderSide(color: AppTheme.borderOutline, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    icon: const Icon(Icons.help_outline_rounded, size: 16, color: AppTheme.primaryBlue),
                    label: Text(
                      prompt,
                      style: GoogleFonts.lexend(fontSize: 13, fontWeight: FontWeight.w500),
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
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.borderOutline, width: 1.5),
              ),
              child: const Icon(Icons.smart_toy_outlined, color: AppTheme.primaryBlue, size: 16),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? AppTheme.primaryBlue : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppTheme.borderOutline,
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: GoogleFonts.lexend(
                      color: isUser ? Colors.white : AppTheme.accentBlack,
                      fontSize: 13.5,
                      height: 1.45,
                    ),
                  ),
                  if (!isUser && message.factsUsed.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.borderOutline, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified_outlined, size: 12, color: AppTheme.primaryBlue),
                          const SizedBox(width: 5),
                          Text(
                            'Data Terverifikasi Sistem (${message.factsUsed.length} fakta)',
                            style: GoogleFonts.lexend(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.accentBlack,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (!isUser && message.suggestion != null) ...[
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => _handleSend(message.suggestion!),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.primaryBlue, width: 1.2),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.lightbulb_outline, size: 13, color: AppTheme.primaryBlue),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Saran: ${message.suggestion!}',
                                style: GoogleFonts.lexend(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryBlue,
                                ),
                              ),
                            ),
                          ],
                        ),
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
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2, right: 8),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.borderOutline, width: 1.5),
            ),
            child: const Icon(Icons.smart_toy_outlined, color: AppTheme.primaryBlue, size: 16),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.borderOutline, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryBlue),
                ),
                const SizedBox(width: 10),
                Text(
                  'ARUS AI menganalisis data...',
                  style: GoogleFonts.lexend(fontSize: 12.5, color: const Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(bool isLoading) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppTheme.borderOutline, width: 1.5),
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
                style: GoogleFonts.lexend(fontSize: 13.5, color: AppTheme.accentBlack),
                decoration: InputDecoration(
                  hintText: 'Tanyakan sesuatu tentang bisnis...',
                  hintStyle: GoogleFonts.lexend(fontSize: 13, color: const Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AppTheme.borderOutline, width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AppTheme.borderOutline, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.borderOutline, width: 1.5),
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                onPressed: isLoading ? null : () => _handleSend(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
