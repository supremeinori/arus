# ARUS VOICE & STT — Master Technical Specification (`arus_voice_spec.md`)

**Target Agent:** Antigravity / Hermes (Fullstack Execution)  
**Scope:** Modul Ekstensi AI Companion (`app/lib/features/ai_assistant/` & `api/src/modules/ai/`)  
**Prinsip Utama:** Zero-Crash Layout, Non-Destructive pada `ai.service.ts`, dan Low-Latency Voice Interaction.

---

## 1. Gambaran Arsitektur (Overview)

Fitur ini menambahkan kemampuan interaksi suara dua arah (*Voice-to-Voice*) dan dikte suara (*Speech-to-Text*) ke dalam **Global AI Companion (Bottom Sheet)** yang sudah berjalan. 

Terdapat 2 mode penggunaan mikrofon yang **TIDAK BOLEH TERTUKAR**:
1. **Dictation Mode (STT Biasa):** Mengubah suara menjadi teks di dalam `TextField` input chat. Tidak langsung terkirim (User masih bisa mengedit teks sebelum menekan Send).
2. **ARUS Voice Mode (Push-to-Talk Tektokan):** Mode percakapan penuh berbasis suara menggunakan **Google STT** (di Flutter) untuk mendengar dan **Microsoft Edge TTS (`id-ID-GadisNeural`)** (di Backend Express) untuk menjawab.

---

## 2. Spesifikasi Backend (`api/src/modules/ai/`)

> **PERINGATAN KERAS:** JANGAN menghapus atau memotong logika personifikasi, aturan bisnis, atau *fact-injection* yang sudah ada di `ai.service.ts`. Cukup tambahkan fungsi dan field yang diminta di bawah ini.

### 2.1 Instalasi & Service Edge TTS
* Gunakan package Node.js `msedge-tts` (atau `node-edge-tts`).
* Konfigurasi Voice wajib: **`id-ID-GadisNeural`** (Bahasa Indonesia - Natural Female).
* Format Output: MP3 Audio (dikirim ke frontend sebagai **Base64 String** di dalam JSON atau binary audio stream agar mudah diputar oleh Flutter tanpa masalah CORS).

### 2.2 Endpoint Baru: `POST /api/ai/tts`
* **Fungsi:** Mengubah teks apa pun menjadi suara `id-ID-GadisNeural`.
* **Request Payload:**
  ```json
  {
    "text": "Kalimat yang ingin diubah menjadi suara."
  }
  ```

- **Response Payload (200 OK):**

  JSON
  ```
  {
    "data": {
      "audio_base64": "SUQzBAAAAAAAI1RTU0UAAAAPAAADTGF2ZjU4Ljc2LjEwMAAAAAAAA..."
    }
  }
  ```

### 2.3 Modifikasi Endpoint Chat: `POST /api/ai/chat`

- Tambahkan instruksi pada System Prompt LLM Gemini agar selain menghasilkan respons analisis biasa (markdown/data), LLM juga menyertakan satu kalimat ringkasan lisan yang ramah, singkat, dan **bebas dari simbol markdown** (`*`, `#`, `-`, tabel) serta menggunakan pelafalan natural (contoh: tulis `"dua puluh lima ribu rupiah"`, atau biarkan TTS membaca angka standar tanpa simbol aneh).
- **Response Payload `/api/ai/chat` Wajib Menyertakan Field `voice_summary`:**

  JSON
  ```
  {
    "data": {
      "reply_text": "Teks lengkap berformat Markdown untuk ditampilkan di gelembung chat UI...",
      "voice_summary": "Ringkasan lisan 1 sampai 2 kalimat yang natural untuk dibacakan oleh suara Gadis.",
      "audio_base64": "(Opsional/Direkomendasikan) Langsung generate audio_base64 dari voice_summary di sini agar frontend tidak perlu melakukan request ke-2 ke /api/ai/tts"
    }
  }
  ```

  *(Catatan Arsitek: Mengembalikan `audio_base64` langsung di dalam response `/api/ai/chat` sangat direkomendasikan untuk memangkas 1x network round-trip).*

## 3. Spesifikasi Frontend Flutter (`app/lib/features/ai_assistant/`)

### 3.1 Dependensi Package (`pubspec.yaml`)

Pastikan package berikut terpasang dan dikonfigurasi izinnya (`RECORD_AUDIO` di `AndroidManifest.xml`):

- `speech_to_text`: Untuk menangkap suara pengguna dari mikrofon HP.
- `audioplayers` (atau `just_audio`): Untuk memutar audio MP3 (dari Base64/Bytes) dan audio *filler* lokal.

### 3.2 Desain Input Bar Dinamis (Ala ChatGPT - Tema Jade Tosca)

Di bagian bawah Bottom Sheet AI Companion, buat input bar menggunakan `Row` (WAJIB membungkus `TextField` dengan `Expanded` untuk mencegah error `RenderBox` / `hitTest`):

Plaintext
```
[ (Expanded) TextField Ketik Pesan... ]  [ 🎤 Ikon Mic STT ]  [ 🟢 Tombol Aksi Utama ]
```

1. **Ikon Mic STT (Dictation):**
   - Saat ditekan: Mengaktifkan `speech_to_text`.
   - Hasil transkrip suara langsung dimasukkan ke dalam `TextEditingController` milik `TextField`.
   - **Jangan** otomatis mengirim pesan. Biarkan user meninjau teksnya.
2. **Tombol Aksi Utama (Bulat, Warna Jade Tosca `#00A896`):**
   - Pasang listener pada `TextEditingController`.
   - **Jika `text.trim().isNotEmpty`:** Tampilkan ikon **Send (`Icons.send`)**. Jika diklik, kirim chat teks biasa.
   - **Jika `text.trim().isEmpty`:** Tampilkan ikon **Waveform (`Icons.graphic_eq`)**. Jika diklik, ubah tampilan Bottom Sheet masuk ke **"ARUS Voice Mode"**.

## 4. State Machine & Alur Kerja "ARUS Voice Mode"

Saat pengguna masuk ke tampilan **ARUS Voice Mode** di dalam Bottom Sheet, antarmuka berfokus pada indikator status visual ( Gelombang suara / Avatar Maskot ARUS) dan **1 Tombol Besar Push-to-Talk (PTT)** di bagian bawah.

### 4.1 4 State Utama (`VoiceSessionState`)

- `IDLE`: Menunggu pengguna menekan tombol PTT.
- `LISTENING`: Jari pengguna sedang menahan tombol PTT, mikrofon aktif merekam.
- `PROCESSING_FILLER`: Jari pengguna dilepas, teks dikirim ke backend, dan aplikasi **langsung memutar suara filler** agar tidak hening.
- `SPEAKING_RESULT`: Memutar audio jawaban (`voice_summary`) dari backend.

### 4.2 Mekanisme Push-to-Talk & "AUTO-CUT" (Instant Interrupt)

Gunakan `GestureDetector` pada tombol Push-to-Talk:

1. **Saat Tombol Ditekan & Ditahan (`onTapDown` / `onLongPressStart`):**
   - **HUKUM AUTO-CUT (MUTLAK):** Jika saat itu state sedang berada di `SPEAKING_RESULT` atau `PROCESSING_FILLER` (suara Gadis sedang berbicara), **WAJIB hentikan pemutaran audio detik itu juga (`await audioPlayer.stop()`)** dan abaikan/batalkan request HTTP sebelumnya yang belum selesai.
   - Ubah state menjadi `LISTENING`.
   - Panggil `speechToText.listen()` (gunakan `localeId: 'id_ID'`).
   - Tampilkan transkrip teks yang sedang diucapkan secara *live* di layar.
2. **Saat Tombol Dilepas (`onTapUp` / `onLongPressEnd` / `onTapCancel`):**
   - Hentikan mikrofon (`await speechToText.stop()`).
   - Jika teks transkrip kosong, kembalikan state ke `IDLE`.
   - Jika ada teks transkrip: a. Ubah state menjadi `PROCESSING_FILLER`. b. **Putar Instant Filler Audio (0ms Delay):** Pilih 1 kalimat secara acak dari daftar rotasi template di bawah ini, lalu langsung putar suaranya (wajib di-*cache* di memori/lokal saat inisialisasi agar langsung berbunyi tanpa menunggu internet):
     - *"Baik, saya cek datanya dulu ya..."*
     - *"Sebentar ya, saya periksa laporan ARUS dulu..."*
     - *"Oke, tunggu sebentar, sedang saya hitung..."*
     - *"Siap, saya carikan informasinya sekarang..."*
   c. Secara paralel di background, kirim teks transkrip beserta `screen_context` ke `POST /api/ai/chat`.
3. **Saat Response Backend Tiba:**
   - Pastikan state saat ini masih `PROCESSING_FILLER` (pengguna belum melakukan *Auto-Cut* / menekan PTT lagi).
   - Hentikan suara filler jika masih berbunyi (`await audioPlayer.stop()`).
   - Ubah state menjadi `SPEAKING_RESULT`.
   - Putar audio dari `audio_base64` (hasil `voice_summary`) menggunakan `AudioPlayer` (`BytesSource(base64Decode(audioBase64))`).
   - Tambahkan juga pasangan pertanyaan & `reply_text` ke dalam riwayat chat visual agar ketika pengguna kembali ke mode teks, riwayat obrolannya tetap tercatat rapi.
   - Saat audio selesai diputar (`onPlayerComplete`), kembalikan state ke `IDLE`.

## 5. Checklist Eksekusi untuk Agent (Definition of Done)

- [ ] Package `msedge-tts` (atau setara) terinstal di `api/package.json` dan berhasil merender suara `id-ID-GadisNeural`.
- [ ] Endpoint `/api/ai/tts` dan `/api/ai/chat` mengembalikan audio Base64 yang valid tanpa merusak personifikasi di `ai.service.ts`.
- [ ] Audio filler telah di-*pre-fetch* atau di-*cache* saat Bottom Sheet dibuka sehingga berbunyi instan saat tombol PTT dilepas.
- [ ] Fitur **Auto-Cut** berjalan mulus: menyentuh tombol PTT langsung membungkam suara AI yang sedang bicara dalam waktu < 50ms.
- [ ] Seluruh komponen `Row` dan `Column` di UI Voice Mode mematuhi aturan `Expanded` / `Flexible` dan lulus `flutter analyze` tanpa error.

***

### Cara Eksekusi di Antigravity:
1. Buat file baru bernama `arus_voice_spec.md` di folder proyek lu, lalu *paste* seluruh kotak *markdown* di atas ke dalamnya.
2. Buka chat Antigravity, lalu ketik perintah singkat ini:
   > *"Baca spesifikasi lengkap di `@arus_voice_spec.md` dan aturan umum di `@arus_srs_v2.md`. Implementasikan fitur ARUS Voice & STT tersebut secara end-to-end (Backend Express & Frontend Flutter) sekarang."*

Dengan memisahkan spesifikasi ini ke file `.md` tersendiri, konteks Antigravity tidak ak
