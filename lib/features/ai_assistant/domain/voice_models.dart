/// State Machine untuk mode interaksi ARUS Voice (Push-to-Talk)
/// sesuai dengan spesifikasi arus_voice_spec.md Bagian 4.1
enum VoiceSessionState {
  /// Menunggu pengguna menekan tombol PTT
  idle,

  /// Jari pengguna sedang menahan tombol PTT, mikrofon aktif merekam
  listening,

  /// Jari pengguna dilepas, request dikirim ke backend, dan aplikasi memutar audio filler instan
  processingFiller,

  /// Memutar audio jawaban GadisNeural dari backend
  speakingResult,
}
