import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
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

    // Simpan ke SharedPreferences agar data tersimpan di perangkat
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    await prefs.setString('pam_feedback_kesan', kesan);
    await prefs.setString('pam_feedback_saran', saran);
    await prefs.setString('pam_feedback_date', dateStr);

    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      setState(() {
        _isSending = false;
        _savedAt = dateStr;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Terima kasih! Saran & kesan untuk mata kuliah Pemrograman Aplikasi Mobile berhasil disimpan.',
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
              border: Border.all(color: AppTheme.borderOutline, width: 1.0),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.school_outlined, color: AppTheme.primaryBlue, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pemrograman Aplikasi Mobile',
                        style: GoogleFonts.lexend(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                          color: AppTheme.accentBlack,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Tuliskan kesan Anda selama mengikuti perkuliahan serta saran konstruktif untuk pengembangan mata kuliah ke depannya.',
                        style: GoogleFonts.lexend(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                          height: 1.4,
                        ),
                      ),
                      if (_savedAt != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF16A34A)),
                            const SizedBox(width: 4),
                            Text(
                              'Terakhir disimpan: $_savedAt',
                              style: GoogleFonts.lexend(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF16A34A),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

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
            'Bagaimana pengalaman dan kesan Anda selama belajar materi Flutter & PAM?',
            style: GoogleFonts.lexend(fontSize: 11.5, color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _kesanController,
            maxLines: 5,
            style: GoogleFonts.lexend(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Tuliskan kesan Anda di sini (misal: materi sangat terstruktur, tantangan proyek nyata membuat pemahaman arsitektur mobile semakin mendalam)...',
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
