import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_client.dart';

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
            style: GoogleFonts.lexend(fontSize: 13),
          ),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    // 1. Simpan ke database online via REST API backend (Phase 1)
    bool sentToBackend = false;
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.post(
        '/feedback',
        data: {
          'kesan': kesan,
          'saran': saran,
          'rating': 5,
        },
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
        _savedAt = '$dateStr ${sentToBackend ? "(Tersimpan di Cloud)" : "(Tersimpan Offline)"}';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            sentToBackend
                ? 'Terima kasih! Kesan & saran PAM berhasil tersimpan di database online & lokal.'
                : 'Tersimpan di penyimpanan lokal perangkat (akan disinkronkan saat online).',
            style: GoogleFonts.lexend(fontSize: 13),
          ),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      appBar: AppBar(
        title: Text(
          'Saran & Kesan Kuliah PAM',
          style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header Card Info Kuliah
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderOutline),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Icon(Icons.school_outlined, color: AppTheme.primaryBlue, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Praktikum Aplikasi Mobile (PAM)',
                        style: GoogleFonts.lexend(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.accentBlack),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Formulir evaluasi mata kuliah & syarat wajib presentasi tugas akhir (Phase 1)',
                        style: GoogleFonts.lexend(fontSize: 12, color: const Color(0xFF64748B)),
                      ),
                      if (_savedAt != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: Text(
                            'Status: $_savedAt',
                            style: GoogleFonts.lexend(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF16A34A)),
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
            style: GoogleFonts.lexend(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.accentBlack,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Bagaimana pengalaman Anda selama mengikuti perkuliahan dan praktikum PAM semester ini?',
            style: GoogleFonts.lexend(fontSize: 11.5, color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _kesanController,
            maxLines: 5,
            style: GoogleFonts.lexend(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Tuliskan kesan Anda di sini (misal: materi sangat terstruktur, praktikum hands-on sangat membantu memahami arsitektur Flutter & Express)...',
              hintStyle: GoogleFonts.lexend(fontSize: 12.5, color: const Color(0xFF94A3B8)),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.borderOutline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.borderOutline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 1.5),
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Form Field 2: Saran
          Text(
            'Saran Perkuliahan *',
            style: GoogleFonts.lexend(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.accentBlack,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Apa saran Anda untuk perbaikan metode mengajar, tugas, atau praktikum ke depan?',
            style: GoogleFonts.lexend(fontSize: 11.5, color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _saranController,
            maxLines: 5,
            style: GoogleFonts.lexend(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Tuliskan saran Anda di sini (misal: perbanyak sesi bedah arsitektur state management dan studi kasus deployment ke production)...',
              hintStyle: GoogleFonts.lexend(fontSize: 12.5, color: const Color(0xFF94A3B8)),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.borderOutline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.borderOutline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 1.5),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Submit Button
          ElevatedButton(
            onPressed: _isSending ? null : _submitFeedback,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _isSending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Simpan & Kirim Masukan',
                        style: GoogleFonts.lexend(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
