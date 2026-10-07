import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  String _selectedCategory = 'Saran Fitur';
  bool _isSending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _submitFeedback() {
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();

    if (title.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Harap lengkapi judul dan isi masukan.', style: GoogleFonts.lexend(fontSize: 13)),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Terima kasih! Masukan Anda telah berhasil dikirim ke tim pengembang.',
              style: GoogleFonts.lexend(fontSize: 13),
            ),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      appBar: AppBar(
        title: Text(
          'Kirim Masukan & Laporan',
          style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Bantu kami meningkatkan kualitas sistem ARUS',
            style: GoogleFonts.lexend(fontSize: 13, color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),

          Text(
            'Kategori',
            style: GoogleFonts.lexend(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.accentBlack),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _selectedCategory,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderOutline)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderOutline)),
            ),
            items: ['Saran Fitur', 'Laporan Kendala (Bug)', 'Pertanyaan Teknis', 'Lainnya']
                .map((cat) => DropdownMenuItem(value: cat, child: Text(cat, style: GoogleFonts.lexend(fontSize: 13))))
                .toList(),
            onChanged: (val) => setState(() => _selectedCategory = val ?? 'Saran Fitur'),
          ),

          const SizedBox(height: 14),

          Text(
            'Judul Masukan *',
            style: GoogleFonts.lexend(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.accentBlack),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              hintText: 'Contoh: Penambahan opsi pembayaran e-wallet',
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderOutline)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderOutline)),
            ),
          ),

          const SizedBox(height: 14),

          Text(
            'Isi Pesan / Penjelasan Detail *',
            style: GoogleFonts.lexend(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.accentBlack),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _messageController,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'Tuliskan detail masukan atau kendala yang dihadapi...',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderOutline)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderOutline)),
            ),
          ),

          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: _isSending ? null : _submitFeedback,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _isSending
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text('Kirim Masukan', style: GoogleFonts.lexend(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
