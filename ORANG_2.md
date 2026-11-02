# ORANG 2 — The Mobile Client, SQLite & Offline-First Lead
> **PANDUAN OPERASIONAL AI & KOMANDO SISTEM NYATA**  
> **Target Pengguna:** Anggota Tim 2 & Asisten AI (Antigravity / LLM).  
> **Prasyarat Wajib:** Pastikan AI telah membaca [`MASTER_UNDERSTAND.md`](file:///c:/MyProjects/arus/MASTER_UNDERSTAND.md) terlebih dahulu.

---

## 1. AI OPERATIONAL DIRECTIVE & SYSTEM LOCK

Jika Anda adalah asisten AI yang mendampingi **Orang 2**:
1. **Fokus Terkunci (Role-Lock):** Anda adalah Co-Pilot khusus untuk **Flutter Mobile UI, Riverpod State Management, Biometrik Keystore, Database Lokal SQLite, Mode Kasir Offline (Offline POS Queue & Auto-Sync), Konversi Kurs & Waktu, serta Push Notifikasi Lokal**.
2. **Larangan Melebar:** JANGAN membahas secara mendalam algoritma hashing blockchain backend atau arsitektur server Express (milik Orang 1), maupun sensor accelerometer/gyroscope dan AI Gemini (milik Orang 3), kecuali sebatas interaksi pada antarmuka aplikasi.
3. **Wajib Memeriksa Berkas Kode Nyata:** Sebelum memberikan jawaban atau penjelasan teknis kepada Orang 2, Anda **WAJIB membaca dan merujuk** berkas-berkas berikut di workspace:
   - Keamanan Biometrik: [`lib/core/auth/biometric_service.dart`](file:///c:/MyProjects/arus/lib/core/auth/biometric_service.dart), [`biometric_lock_wrapper.dart`](file:///c:/MyProjects/arus/lib/core/auth/biometric_lock_wrapper.dart)
   - Database Lokal SQLite: [`lib/core/storage/local_db.dart`](file:///c:/MyProjects/arus/lib/core/storage/local_db.dart)
   - Penyimpanan Aman Keystore: [`lib/core/storage/secure_store.dart`](file:///c:/MyProjects/arus/lib/core/storage/secure_store.dart)
   - Sinkronisasi Offline: [`lib/core/sync/sync_service.dart`](file:///c:/MyProjects/arus/lib/core/sync/sync_service.dart)
   - Konversi Kurs: [`lib/core/utils/money_formatter.dart`](file:///c:/MyProjects/arus/lib/core/utils/money_formatter.dart), [`lib/features/settings/data/fx_repository.dart`](file:///c:/MyProjects/arus/lib/features/settings/data/fx_repository.dart)
   - Konversi Waktu: [`lib/core/utils/timezone_converter.dart`](file:///c:/MyProjects/arus/lib/core/utils/timezone_converter.dart)
   - Notifikasi Lokal: [`lib/core/push/notification_service.dart`](file:///c:/MyProjects/arus/lib/core/push/notification_service.dart)
   - Antarmuka Kasir & Keranjang: [`lib/features/pos/presentation/pos_screen.dart`](file:///c:/MyProjects/arus/lib/features/pos/presentation/pos_screen.dart), [`pos_provider.dart`](file:///c:/MyProjects/arus/lib/features/pos/presentation/pos_provider.dart)
   - Profil Pengguna: [`lib/features/profile/presentation/profile_screen.dart`](file:///c:/MyProjects/arus/lib/features/profile/presentation/profile_screen.dart)

---

## 2. Peta Fitur & Tanggung Jawab Orang 2

Orang 2 memegang kendali atas pengalaman pengguna mobile (*client experience*) dan keandalan data lokal:

| Kode Fitur | Nama Fitur | Kriteria Dosen PAM | File Kunci di Codebase |
| :---: | :--- | :--- | :--- |
| **Fitur 3** | Login Biometrik (*Fingerprint / Face*) | Login Sensor Biometrik | `lib/core/auth/biometric_service.dart` |
| **Fitur 4** | Halaman Profil Bergambar (*Avatar*) | Bottom Nav: Profil Bergambar | `lib/features/profile/presentation/profile_screen.dart` |
| **Fitur 8 & 9** | Katalog Menu & Estimasi Porsi Dinamis | Fasilitas Pencarian & Pemilihan | `lib/features/catalog/presentation/product_list_screen.dart` |
| **Fitur 10** | Backup Offline Katalog (SQLite) | DB Lokal SQLite & Online | `lib/core/storage/local_db.dart` (`backup_products`) |
| **Fitur 11** | Filter Status Bahan Mentah Cabang | Fasilitas Pencarian & Filter | `lib/features/inventory/presentation/inventory_list_screen.dart` |
| **Fitur 13** | UI Kasir Mobile (POS) & Cart Sheet | Konsep Proyek Akhir | `lib/features/pos/presentation/pos_screen.dart` |
| **Fitur 14** | Antrean Kasir Offline & Struk Lokal | DB Lokal SQLite & Sync Service | `lib/core/sync/sync_service.dart` |
| **Fitur 18** | Push Notifikasi Mobile Stok Menipis | Notifikasi Mobile Sesuai Konsep | `lib/core/push/notification_service.dart` |
| **Fitur 20** | Konversi 3 Mata Uang (IDR, USD, EUR) | Menu Konversi Min. 3 Mata Uang | `lib/core/utils/money_formatter.dart` |
| **Fitur 21** | Konversi 4 Zona Waktu (WIB/WITA/WIT/LDN) | Konversi 4 Zona Waktu | `lib/core/utils/timezone_converter.dart` |

---

## 3. Bedah Teknis Sistem Nyata (Deep Dive Codebase)

### 3.1 Alur Biometric Unlock (`local_auth` & Secure Storage)
* **Lokasi Kode:** [`lib/core/auth/biometric_service.dart`](file:///c:/MyProjects/arus/lib/core/auth/biometric_service.dart) & [`secure_store.dart`](file:///c:/MyProjects/arus/lib/core/storage/secure_store.dart)
* **Mekanisme Kerja:**
  1. **Login Pertama:** User memasukkan email & password ke Express API. Token sesi JWT disimpan aman di `flutter_secure_storage` (dienkripsi menggunakan hardware Android Keystore / iOS Keychain). Flag `biometric_enabled = 1` disimpan di tabel SQLite `local_session_settings`.
  2. **Buka Aplikasi Kembali:** `SplashScreen` mendeteksi sesi aktif dan langsung memicu dialog sidik jari Android melalui library `local_auth`:
     ```dart
     final authenticated = await _localAuth.authenticate(
       localizedReason: 'Pindai sidik jari untuk membuka sesi ARUS',
       options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
     );
     ```
  3. **Keamanan Privasi:** Data biometrik (sidik jari/wajah) **TIDAK PERNAH dikirim ke server**. Hardware Secure Enclave hanya mengirim status boolean `true/false`. Jika `true`, aplikasi mengambil token dari Keystore dan masuk ke dashboard tanpa mengetik password.
  4. **Fallback:** Jika pemindaian gagal 3 kali berturut-turut atau dibatalkan pengguna, aplikasi otomatis mengarahkan ke Layar Login password biasa.

### 3.2 Arsitektur Offline-First & SQLite (`local_db.dart` & `sync_service.dart`)
* **Lokasi Kode:** [`lib/core/storage/local_db.dart`](file:///c:/MyProjects/arus/lib/core/storage/local_db.dart) & [`lib/core/sync/sync_service.dart`](file:///c:/MyProjects/arus/lib/core/sync/sync_service.dart)
* **Tabel Antrean Offline (`offline_transactions`):**
  - Kolom: `id`, `client_request_id` (UUID v4), `outlet_id`, `cashier_id`, `payload_json`, `sync_status` (`PENDING_SYNC`, `SYNCED`, `FAILED`), `retry_count`, `created_at`.
* **Alur Eksekusi Kasir Tanpa Internet (Offline):**
  1. Saat kasir menekan tombol "Bayar" dan koneksi internet terputus, aplikasi tidak menampilkan error koneksi.
  2. Transaksi dikemas dalam payload JSON lengkap dengan UUID unik `client_request_id`.
  3. Data langsung ditulis ke tabel SQLite `offline_transactions` dengan status `PENDING_SYNC`.
  4. Struk lokal langsung dicetak/ditampilkan ke layar dengan label *"Transaksi Tersimpan Offline (Antrean)"*.
  5. Stok lokal di tabel `backup_products` langsung dikurangi sementara agar estimasi porsi kasir tetap akurat.
* **Proses Auto-Sync Saat Online Kembali:**
  - `SyncService` memantau konektivitas internet secara reaktif via listener jaringan.
  - Begitu sinyal pulih, service mengambil seluruh transaksi dengan status `PENDING_SYNC`.
  - Mengirimkan transaksi satu per satu ke endpoint backend `POST /api/pos/checkout`.
  - Berkat `client_request_id`, backend memproses transaksi secara idempoten (tidak akan pernah terjadi transaksi ganda).
  - Setelah server mengonfirmasi, status di SQLite diupdate menjadi `SYNCED`.

### 3.3 Konversi Realtime 3 Mata Uang (IDR, USD, EUR)
* **Lokasi Kode:** [`lib/core/utils/money_formatter.dart`](file:///c:/MyProjects/arus/lib/core/utils/money_formatter.dart) & [`lib/features/settings/data/fx_repository.dart`](file:///c:/MyProjects/arus/lib/features/settings/data/fx_repository.dart)
* **Konsumsi Web Service:**
  - Aplikasi mengambil kurs pertukaran mata uang secara dinamis dari REST API publik:
    `https://api.frankfurter.dev/v1/latest?base=IDR&symbols=USD,EUR`
  - Kurs dicadangkan (*cached*) di memori lokal agar aplikasi tetap bisa mengonversi harga saat sedang offline.
  - **Prinsip Data Integrity:** Database backend dan SQLite selalu menyimpan harga dalam tipe data **integer IDR**. Konversi ke USD atau EUR hanya terjadi di lapisan presentasi UI (*view layer*).

### 3.4 Konversi 4 Zona Waktu (WIB, WITA, WIT, London)
* **Lokasi Kode:** [`lib/core/utils/timezone_converter.dart`](file:///c:/MyProjects/arus/lib/core/utils/timezone_converter.dart)
* **Mekanisme Perhitungan:**
  - Waktu transaksi disimpan di PostgreSQL dalam format ISO 8601 UTC.
  - Widget konverter menghitung offset waktu:
    - **WIB:** UTC + 7 jam (Asia/Jakarta)
    - **WITA:** UTC + 8 jam (Asia/Makassar)
    - **WIT:** UTC + 9 jam (Asia/Jayapura)
    - **London:** UTC + 0 jam / BST UTC + 1 jam (Europe/London)
  - Kasir dan Owner dapat melihat perbandingan jam transaksi di masing-masing cabang secara berdampingan.

### 3.5 Push Notifikasi Mobile Stok Menipis
* **Lokasi Kode:** [`lib/core/push/notification_service.dart`](file:///c:/MyProjects/arus/lib/core/push/notification_service.dart)
* **Mekanisme:**
  - Menggunakan package `flutter_local_notifications` dengan Android Notification Channel khusus.
  - Ketika sebuah transaksi POS selesai dieksekusi dan ada bahan mentah yang sisa stoknya $\leq$ `reorder_level`, backend/client mengirimkan trigger notifikasi.
  - Notifikasi muncul di status bar perangkat Android lengkap dengan judul peringatan dan nama bahan yang kritis.

---

## 4. Batasan Narasi Presentasi (Scope Boundaries)

### Yang HARUS Dijelaskan oleh Orang 2:
- Pengalaman kasir mobile (*clean UI* dengan Flutter & Riverpod).
- Mekanisme keamanan login biometrik sidik jari dengan Android Keystore.
- Arsitektur Offline-First: pembuktian kasir tetap bisa transaksi tanpa sinyal internet via antrean SQLite.
- Bagaimana `SyncService` menyinkronkan data secara otomatis dan mencegah transaksi ganda.
- Fitur utilitas global: konversi 3 valuta kurs realtime (Frankfurter API) dan 4 zona waktu operasional cabang.
- Penerimaan notifikasi stok menipis di perangkat mobile.

### Yang BUKAN Bagian Orang 2 (Delegasikan ke Rekan):
- "Bagaimana server mengeksekusi transaksi secara atomik dan skema Prisma-nya?" $\rightarrow$ **Lempar ke Orang 1 (Backend & DB).**
- "Bagaimana rantai hash blockchain dan tamper recovery bekerja?" $\rightarrow$ **Lempar ke Orang 1 (Blockchain).**
- "Bagaimana HP mendeteksi guncangan sensor dan AI Gemini menjawab pertanyaan?" $\rightarrow$ **Lempar ke Orang 3 (Sensors & AI).**

---

## 5. Skenario Live Demo (Runbook Presentasi)

Ikuti urutan langkah demo ini agar presentasi memukau dosen:

```text
[Langkah 1: Demo Biometric Fingerprint Login]
1. Kunci aplikasi atau buka aplikasi dari keadaan tertutup.
2. Saat splash screen selesai, tunjukkan dialog modal fingerprint bawaan Android muncul di layar.
3. Tempelkan jari pada sensor fisik HP / trigger fingerprint via emulator emulator command.
4. Tunjukkan dialog sukses dan aplikasi langsung masuk ke Beranda tanpa memasukkan password.

[Langkah 2: Demo Kasir Offline & Auto-Sync (Fitur Unggulan)]
1. Di depan dosen, nyalakan MODE PESAWAT (Airplane Mode) pada HP/Emulator (WiFi & Data mati).
2. Tunjukkan indikator banner di atas aplikasi: "Mode Offline: Bekerja dengan Database Lokal SQLite".
3. Masuk ke menu "Kasir (POS)" -> masukkan 2 menu ke keranjang -> klik "Bayar" (Tunai).
4. Selesaikan transaksi -> tunjukkan struk pembayaran berhasil terbit dengan status "Tersimpan di Antrean Offline (Pending Sync)".
5. Matikan Mode Pesawat (nyalakan kembali koneksi internet).
6. Dalam hitungan detik, tunjukkan snackbar notifikasi muncul otomatis:
   "Sinkronisasi Berhasil: 1 Transaksi Offline Berhasil Diunggah ke Server Cloud".

[Langkah 3: Demo Konversi Kurs & 4 Zona Waktu]
1. Buka menu "Pengaturan" -> pilih sub-menu "Mata Uang & Kurs".
2. Ubah mata uang dari IDR ke USD -> kembali ke katalog produk / dashboard -> tunjukkan harga berubah menjadi format $X.XX.
3. Ubah ke EUR -> harga berubah menjadi format €X.XX berdasarkan kurs live dari Frankfurter API.
4. Buka sub-menu "Zona Waktu" -> ubah zona waktu ke London -> tunjukkan jam transaksi menyesuaikan waktu lokal London.

[Langkah 4: Demo Notifikasi Mobile]
1. Lakukan transaksi produk yang bahan bakunya sudah diset kritis (stok <= reorder_level).
2. Tunjukkan pop-up notifikasi melayang di status bar Android yang memperingatkan stok menipis.
```

---

## 6. Cheatsheet Ujian Dosen & Jawaban Mantap

* **Dosen:** *"Bagaimana aplikasi mencegah terjadinya transaksi ganda jika kasir mengklik tombol sinkronisasi berkali-kali saat sinyal putus-nyambung?"*
  * **Jawaban:** *"Setiap kali transaksi offline dibuat di SQLite, aplikasi langsung men-generate UUID v4 unik bernama `client_request_id`. Ketika koneksi pulih dan `SyncService` mengirim data ke endpoint `/api/pos/checkout`, backend kami menerapkan mekanisme **Idempotency Check**. Jika `client_request_id` tersebut sudah pernah tersimpan di tabel `transactions` PostgreSQL, backend tidak akan memproses ulang atau memotong stok dua kali, melainkan hanya mengembalikan struk asli yang sudah terbit."*

* **Dosen:** *"Apakah sidik jari pengguna dikirim ke database Supabase untuk diverifikasi?"*
  * **Jawaban:** *"Tidak, Bu/Pak. Sesuai standar keamanan mobile modern, data biometrik pengguna tidak pernah meninggalkan chip hardware Secure Enclave perangkat. Library `local_auth` hanya meminta sistem operasi Android untuk memverifikasi sidik jari secara lokal dan mengembalikan status boolean. Jika valid, aplikasi mendekripsi JWT token sesi yang tersimpan di `flutter_secure_storage` yang terproteksi oleh Android Keystore."*

* **Dosen:** *"Mengapa kalian menggunakan SQLite lokal selain database PostgreSQL di cloud?"*
  * **Jawaban:** *"Untuk mengimplementasikan arsitektur **Offline-First**. Dalam operasional kasir retail nyata, kasir tidak boleh berhenti melayani pelanggan hanya karena internet mati. Dengan SQLite (`sqflite`), kami memiliki 7 tabel lokal yang menyimpan cache katalog, sesi, riwayat struk, serta antrean transaksi (`offline_transactions`), sehingga aplikasi tetap dapat beroperasi 100% secara offline dan tersinkronisasi mulus saat online kembali."*
