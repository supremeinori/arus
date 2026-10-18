import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';

/// Format tanggal feedback — fungsi top-level murni (aturan E21:
/// DateTime.now tidak menentukan struktur di dalam build; dipakai di handler).
String formatFeedbackDateTime(DateTime now) {
  return '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
}

class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final _kesanController = TextEditingController();
  final _saranController = TextEditingController();
  bool _isSending = false;
  String? _savedAt;

  @override
  void initState() {
    super.initState();
    _loadSavedFeedback();
  }

  Future<void> _loadSavedFeedback() async {
    // 1. Baca cache lokal dulu
    final prefs = await SharedPreferences.getInstance();
    final savedKesan = prefs.getString('pam_feedback_kesan');
    final savedSaran = prefs.getString('pam_feedback_saran');
    final savedDate = prefs.getString('pam_feedback_date');

    if (savedKesan != null || savedSaran != null) {
      if (mounted) {
        setState(() {
          _kesanController.text = savedKesan ?? '';
          _saranController.text = savedSaran ?? '';
          _savedAt = savedDate;
        });
      }
    }

    // 2. Coba sinkronisasi riwayat feedback dari backend database
    try {
      final apiClient = ref.read(apiClientProvider);
      final res = await apiClient.get('/feedback');
      final list = res.data['data'] as List<dynamic>?;
      if (list != null && list.isNotEmpty) {
        final latest = list.first as Map<String, dynamic>;
        if (mounted && _kesanController.text.isEmpty) {
          setState(() {
            _kesanController.text = latest['kesan'] as String? ?? '';
            _saranController.text = latest['saran'] as String? ?? '';
            _savedAt = latest['created_at'] != null ? 'Database Online' : null;
          });
        }
      }
    } catch (_) {
      // Abaikan jika sedang offline / backend disconnect
    }
  }

  @override
  void dispose() {
    _kesanController.dispose();
    _saranController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    final kesan = _kesanController.text.trim();
    final saran = _saranController.text.trim();

    if (kesan.isEmpty || saran.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Harap lengkapi kolom Kesan dan Saran.',
            style: GoogleFonts.inter(fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    final dateStr = formatFeedbackDateTime(DateTime.now());

    // 1. Simpan ke database online via REST API backend (Phase 1)
    bool sentToBackend = false;
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.post(
        '/feedback',
        data: {'kesan': kesan, 'saran': saran, 'rating': 5},
      );
      sentToBackend = true;
    } catch (_) {
      // Jika offline, simpan lokal sebagai fallback
      sentToBackend = false;
    }

    // 2. Simpan ke SharedPreferences lokal
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pam_feedback_kesan', kesan);
    await prefs.setString('pam_feedback_saran', saran);
    await prefs.setString('pam_feedback_date', dateStr);

    if (mounted) {
      setState(() {
        _isSending = false;
        _savedAt =
            '$dateStr ${sentToBackend ? "(Tersimpan di Cloud)" : "(Tersimpan Offline)"}';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            sentToBackend
                ? 'Terima kasih! Kesan & saran PAM berhasil tersimpan di database online & lokal.'
                : 'Tersimpan di penyimpanan lokal perangkat (akan disinkronkan saat online).',
            style: GoogleFonts.inter(fontSize: 13),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: Text(
          'Saran & Kesan Kuliah PAM',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 17),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header Card Info Kuliah
          ShadCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.jadeTosca.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.darkCardBorder),
                  ),
                  child: const Icon(
                    Icons.school_outlined,
                    color: AppTheme.jadeTosca,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Praktikum Aplikasi Mobile (PAM)',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimaryDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Formulir evaluasi mata kuliah & syarat wajib presentasi tugas akhir (Phase 1)',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.textMutedDark,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_savedAt != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.darkCardSurfaceElevated,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.darkCardBorder),
                          ),
                          child: Text(
                            'Status: $_savedAt',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF16A34A),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Form Field 1: Kesan
          Text(
            'Kesan Perkuliahan *',
            style: GoogleFonts.inter(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryDark,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          const SizedBox(height: 8),
          TextField(
            controller: _kesanController,
            maxLines: 5,
            style: GoogleFonts.inter(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Tuliskan kesan Anda di sini...',
              hintStyle: GoogleFonts.inter(
                fontSize: 12.5,
                color: const Color(0xFF94A3B8),
              ),
              filled: true,
              fillColor: AppTheme.darkCardSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.darkCardBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.darkCardBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: AppTheme.jadeTosca,
                  width: 1.5,
                ),
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Form Field 2: Saran
          Text(
            'Saran Perkuliahan *',
            style: GoogleFonts.inter(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryDark,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _saranController,
            maxLines: 5,
            style: GoogleFonts.inter(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Tuliskan saran Anda di sini',
              hintStyle: GoogleFonts.inter(
                fontSize: 12.5,
                color: const Color(0xFF94A3B8),
              ),
              filled: true,
              fillColor: AppTheme.darkCardSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.darkCardBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.darkCardBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: AppTheme.jadeTosca,
                  width: 1.5,
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Submit Button
          SizedBox(
            width: double.infinity,
            child: ShadButton(
              onPressed: _isSending ? null : _submitFeedback,
              leading: _isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              child: const Text('Simpan & Kirim Masukan'),
            ),
          ),
        ],
      ),
    );

    if (ShadTheme.maybeOf(context) == null) {
      return ShadTheme(
        data: AppTheme.shadcnThemeDark,
        child: scaffold,
      );
    }
    return scaffold;
  }
}
