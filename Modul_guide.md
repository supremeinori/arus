**Nama Proyek:** ARUS (Mobile Business Decision-Support System)

**Mata Kuliah:** Pemrograman Aplikasi Mobile / Teknologi & Pemrograman Mobile

**Arsitektur:** Flutter (Multiplatform Android/iOS) \+ Node.js/Express REST API \+ PostgreSQL (Supabase) \+ SQLite (sqflite)

## **BAB 1: Pembagian Struktur Navigasi & Kemampuan per Role**

Aplikasi ARUS menerapkan kontrol akses berbasis peran (*Role-Based Access Control* / RBAC) untuk tiga jenis pengguna utama: **Owner**, **Manager**, dan **Staff (Kasir)**. Pembatasan akses cabang (*outlet scoping*) dikendalikan melalui tabel penghubung user\_outlets di database PostgreSQL.

### **1.1 Struktur Bottom Navigation per Role**

Begitu pengguna berhasil login, aplikasi Flutter akan menyesuaikan bilah navigasi bawah (*Bottom Navigation Bar*) sesuai peran akun:

* **Navigasi Owner & Manager (5 Tab):** Beranda (Dashboard) | Operasi | AI Assistant | Analitik | Lainnya (Profil, Kesan & Saran PAM, Game, Pengaturan, Logout)  
* **Navigasi Staff / Kasir (4 Tab):** Beranda (Ringkasan Shift) | Kasir (POS) | Stok | Lainnya (Profil, Kesan & Saran PAM, Game, Pengaturan, Logout)

### **1.2 Tabel Perbandingan Hak Akses Role (Permission Matrix)**

| Area Kemampuan | Owner (Pemilik Bisnis) | Manager (Manajer Cabang) | Staff (Kasir Operasional) |
| :---- | :---- | :---- | :---- |
| **Cakupan Data Cabang** | **Seluruh cabang** tanpa batas (WIB, WITA, WIT, & London). | **Hanya cabang yang ditugaskan** kepadanya di tabel user\_outlets. | **Hanya 1 cabang** tempat ia bertugas menjaga kasir. |
| **Manajemen Akun & Cabang** | **Akses Penuh:** Membuat/menonaktifkan akun user, mengatur penugasan cabang, dan menambah/mengedit data lokasi cabang (outlets). | **Ditolak (HTTP 403):** Tidak dapat membuat user baru atau menambah cabang. | **Ditolak (HTTP 403):** Tidak memiliki akses manajemen. |
| **Katalog Produk & Harga Modal** | **Akses Penuh:** Menambah/mengedit produk & kategori, serta melihat harga modal (cost\_idr) untuk perhitungan margin laba. | **Akses Penuh:** Menambah/mengedit produk & kategori, serta melihat harga modal (cost\_idr). | **Terbatas (Read-Only):** Hanya melihat produk aktif dan harga jual (price\_idr). Kolom cost\_idr disembunyikan oleh API. |
| **Stok & Inventaris** | **Penuh (Semua Cabang):** Melihat stok, log pergerakan barang, dan melakukan penyesuaian stok (*restock*, koreksi, barang buang). | **Penuh (Cabang Sendiri):** Melakukan *restock*, koreksi stok, dan melihat riwayat pergerakan barang di cabangnya. | **Terbatas (Cabang Sendiri):** Hanya melihat sisa angka stok (quantity) tanpa bisa mengubah stok atau melihat log audit. |
| **Kasir (POS) & Transaksi** | Menginput penjualan di semua cabang, melihat seluruh riwayat struk, dan membatalkan transaksi (*Void*) kapan saja. | Menginput penjualan di cabangnya, melihat seluruh struk cabangnya, dan melakukan *Void* transaksi (maksimal 24 jam). | Menginput penjualan di POS cabangnya. Hanya bisa melihat struk buatannya sendiri pada hari ini, dan tidak bisa melakukan *Void*. |
| **Dashboard & Analitik** | **Dashboard Jaringan:** Melihat KPI omzet gabungan, perbandingan seluruh cabang, jam ramai, dan grafik tren. | **Dashboard Cabang:** Melihat KPI omzet dan analitik khusus cabang yang ditugaskan kepadanya. | **Ringkasan Shift Saja:** Hanya melihat jumlah transaksi hari ini, total uang masuk shift ini, dan 5 struk terakhir. |
| **Decision Support & AI (LLM)** | Melihat seluruh *business insights* dan bertanya ke AI Assistant mencakup data semua cabang. | Melihat *insights* cabangnya dan bertanya ke AI Assistant (data otomatis difilter hanya untuk cabangnya). | **Ditolak (HTTP 403):** Tab AI dan Analitik tidak ditampilkan. |
| **Blockchain & Laporan** | Membuat laporan periode, memverifikasi hash per struk, dan memverifikasi keutuhan seluruh rantai blok (Integrity Chain). | Membuat laporan cabangnya dan memverifikasi keaslian hash pada struk/laporan di cabangnya. | Hanya melihat kode/lencana hash pada struk yang baru dicetak tanpa menu audit rantai blok. |
| **Peta LBS (Outlet Map)** | Melihat peta seluruh cabang dengan warna pin sesuai performa omzet dan jarak terdekat dari GPS. | Melihat peta cabang yang ditugaskan beserta indikator performanya dan jarak terdekat. | Melihat lokasi cabangnya di peta beserta jarak GPS (Read-Only). |
| **Notifikasi Mobile** | Menerima semua notifikasi: stok tipis, omzet turun, target tercapai, ringkasan harian, dan peringatan manipulasi Blockchain. | Menerima notifikasi untuk cabangnya: stok tipis, perubahan omzet, dan target harian. | Hanya menerima notifikasi Stok Menipis (low\_stock) di cabangnya. |

## **BAB 2: Daftar Lengkap 27 Fitur Aplikasi & Pemetaan Kriteria Dosen**

Keterangan simbol akses: **✔ Penuh** (akses penuh sesuai cakupan cabang), **👁️ Read-Only** (hanya lihat), **❌ Ditolak** (tidak punya akses).

### **2.1 Modul Autentikasi, Keamanan & Profil**

| No | Nama Fitur & Deskripsi Teknis | Owner | Manager | Staff | Kriteria Tugas Akhir Dosen yang Dipenuhi |
| :---- | :---- | :---- | :---- | :---- | :---- |
| 1 | **Login Email & Password**: Autentikasi menggunakan password yang di-hash dengan argon2/bcrypt di Express API. | ✔ | ✔ | ✔ | Login dengan enkripsi (tidak menggunakan Firebase) dan session. |
| 2 | **Session Management**: Pengelolaan sesi menggunakan JWT Bearer Token serta penyimpanan sesi di SQLite & Secure Storage. | ✔ | ✔ | ✔ | Login dengan enkripsi (tidak menggunakan Firebase) dan session. |
| 3 | **Biometric Unlock**: Membuka kunci sesi aplikasi menggunakan sensor sidik jari/wajah perangkat (local\_auth). | ✔ | ✔ | ✔ | Memiliki login biometric. |
| 4 | **Menu Profil Bergambar**: Menampilkan foto profil pengguna (avatar\_url), nama, role, dan daftar cabang aktif. | ✔ | ✔ | ✔ | Bottom navigation: menu profil (ada gambar). |
| 5 | **Menu Saran & Kesan Matkul PAM**: Form input kesan dan saran selama mengikuti mata kuliah PAM yang disimpan ke tabel feedback. | ✔ | ✔ | ✔ | Bottom navigation: menu saran dan kesan mata kuliah Pemrograman Aplikasi Mobile. |
| 6 | **Menu Logout**: Menghapus token sesi aktif dari penyimpanan lokal dan mengembalikan pengguna ke layar Login. | ✔ | ✔ | ✔ | Bottom navigation: menu logout. |
| 7 | **Manajemen Akun Pengguna**: Menambah akun Manager/Staff baru dan mengatur penugasan cabang (user\_outlets). | ✔ | ❌ | ❌ | Pendukung skenario hak akses multi-role. |

### **2.2 Modul Operasional (Katalog, Stok, Pencarian & Kasir POS)**

| No | Nama Fitur & Deskripsi Teknis | Owner | Manager | Staff | Kriteria Tugas Akhir Dosen yang Dipenuhi |
| :---- | :---- | :---- | :---- | :---- | :---- |
| 8 | **CRUD Produk & Kategori**: Mengelola daftar barang, harga jual (price\_idr), dan harga modal (cost\_idr) melalui REST API. | ✔ | ✔ | 👁️ | Terkoneksi Web Service / API & Database Online. |
| 9 | **Pencarian & Filter Katalog**: Mencari produk berdasarkan nama/SKU dan memfilter berdasarkan kategori atau status aktif. | ✔ | ✔ | ✔ | Memiliki fasilitas pencarian dan pemilihan. |
| 10 | **Backup Offline Katalog (SQLite)**: Menyimpan salinan katalog produk secara otomatis ke tabel backup\_products di SQLite untuk mode tanpa internet. | ✔ | ✔ | ✔ | Terkoneksi database / penyimpanan lokal (SQLite) dan online. |
| 11 | **Filter Status Stok Cabang**: Memilih cabang dan memfilter barang berdasarkan status stok (Aman, Menipis, Habis) beserta *days of cover*. | ✔ | ✔ | 👁️ | Memiliki fasilitas pencarian dan pemilihan. |
| 12 | **Penyesuaian Stok (*Stock Adjustment*)**: Mencatat penambahan stok (*restock*), koreksi, atau barang rusak ke inventory\_movements. | ✔ | ✔ | ❌ | Konsep inti sistem pendukung keputusan inventaris. |
| 13 | **Kasir Mobile (POS)**: Memilih barang ke keranjang, menghitung total & kembalian di server, serta memotong stok secara atomik. | ✔ | ✔ | ✔ | Memiliki konsep projek akhir (sumber data transaksi). |
| 14 | **Pencarian Struk & Backup Transaksi (SQLite)**: Mencari riwayat struk berdasarkan nomor/tanggal/metode bayar dan menyimpannya di SQLite. | ✔ | ✔ | 👁️ | Fasilitas pencarian dan pemilihan \+ DB Lokal SQLite. |
| 15 | **Pembatalan Transaksi (*Void*)**: Membatalkan transaksi yang keliru dan mengembalikan jumlah stok secara otomatis. | ✔ | ✔ | ❌ | Integritas data operasional POS. |

### **2.3 Modul Blockchain & Notifikasi Mobile**

| No | Nama Fitur & Deskripsi Teknis | Owner | Manager | Staff | Kriteria Tugas Akhir Dosen yang Dipenuhi |
| :---- | :---- | :---- | :---- | :---- | :---- |
| 16 | **Pencatatan Hash Blockchain (SHA-256)**: Setiap transaksi selesai, server membuat data\_hash dan mengaitkannya dengan prev\_hash transaksi sebelumnya di blockchain\_records. | ✔ | ✔ | ✔ | Memiliki fitur blockchain sederhana. |
| 17 | **Verifikasi Keaslian Data (Tamper Check)**: Membandingkan hash data struk saat ini di DB dengan hash yang tercatat di rantai blok (VALID vs TAMPERED). | ✔ | ✔ | 👁️ | Memiliki fitur blockchain sederhana. |
| 18 | **Notifikasi Mobile Stok Menipis**: Memunculkan notifikasi lokal di HP Android (flutter\_local\_notifications) ketika penjualan POS membuat stok $\leq$ reorder\_level. | ✔ | ✔ | ✔ | Memiliki fitur notifikasi berbasis mobile sesuai konsep. |

### **2.4 Modul Dashboard Analitik, Konversi Utilitas, Sensor & LBS**

| No | Nama Fitur & Deskripsi Teknis | Owner | Manager | Staff | Kriteria Tugas Akhir Dosen yang Dipenuhi |
| :---- | :---- | :---- | :---- | :---- | :---- |
| 19 | **Dashboard KPI & Grafik Penjualan**: Menampilkan kartu ringkasan omzet, jumlah transaksi, rata-rata nilai transaksi (ATV), dan grafik tren (fl\_chart). | ✔ | ✔ | 👁️ | Memiliki konsep projek akhir (Business Analytics). |
| 20 | **Konversi 3 Mata Uang (IDR, USD, EUR)**: Mengubah tampilan nominal uang di Dashboard dan Katalog menggunakan kurs dari Web Service publik (api.frankfurter.dev). | ✔ | ✔ | ✔ | Memiliki menu tambahan konversi mata uang (min. 3 mata uang) terpadu konsep. |
| 21 | **Konversi 4 Zona Waktu (WIB, WITA, WIT, London)**: Mengonversi jam transaksi dan menampilkan perbandingan waktu lokal cabang Indonesia hingga cabang ekspansi London. | ✔ | ✔ | ✔ | Konversi waktu (minimal ada: WIB, WIT, WITA, London) terpadu konsep. |
| 22 | **Sensor 1 — Accelerometer (*Shake to Refresh*)**: Menggoyangkan HP pada halaman Dashboard untuk memuat ulang data analitik terbaru dari server. | ✔ | ✔ | ✔ | Memiliki fitur minimal 2 sensor (Accelerometer) sesuai konsep. |
| 23 | **Sensor 2 — Gyroscope (*Tilt Chart Switch*)**: Memiringkan pergelangan tangan/HP untuk mengganti rentang waktu grafik (Harian, Mingguan, Bulanan). | ✔ | ✔ | 👁️ | Memiliki fitur minimal 2 sensor (Gyroscope) sesuai konsep. |
| 24 | **Peta Cabang & LBS (*Location-Based Services*)**: Menampilkan lokasi cabang di peta OpenStreetMap, menghitung jarak GPS pengguna ke cabang terdekat, dan memberi warna pin berdasarkan performa omzet. | ✔ | ✔ | 👁️ | Terdapat Web Service / API serta memiliki fasilitas LBS yang terkait tema. |

### **2.5 Modul Kecerdasan Buatan (AI / LLM) & Mini Games**

| No | Nama Fitur & Deskripsi Teknis | Owner | Manager | Staff | Kriteria Tugas Akhir Dosen yang Dipenuhi |
| :---- | :---- | :---- | :---- | :---- | :---- |
| 25 | **Rule-Based Decision Support (business\_insights)**: Mesin aturan deterministik yang mendeteksi stok kritis, produk lambat laku, dan penurunan penjualan beserta bukti angkanya. | ✔ | ✔ | ❌ | Memiliki fitur/fasilitas AI sesuai dengan konsep tema. |
| 26 | **ARUS AI Business Assistant (LLM Gemini)**: Fitur tanya-jawab bahasa alami di mana backend mengambil fakta angka dari PostgreSQL dan memintakan analisis ke Gemini API dalam format *Data, Dugaan, dan Saran*. | ✔ | ✔ | ❌ | Memiliki fitur/fasilitas AI dan fitur LLM sesuai dengan konsep tema. |
| 27 | **Mini Game (*Business Decision Challenge*)**: Permainan simulasi kuis 5 skenario bisnis (menentukan langkah saat stok menipis atau omzet turun) beserta penilaian skor di server. | ✔ | ✔ | ✔ | Memiliki fitur mini games sederhana terkait dengan konsep. |

## **BAB 3: Cara Kerja Teknis Biometric Login & Alur Skenario Demo**

### **3.1 Mekanisme Biometric Login (local\_auth \+ flutter\_secure\_storage)**

Sesuai aturan keamanan sistem (BR-AUTH-03), pemindaian sidik jari tidak menggantikan verifikasi password saat pengguna pertama kali masuk di perangkat baru, melainkan berfungsi sebagai pembuka kunci token sesi yang tersimpan secara aman di perangkat:

1. **Login Pertama (Inisialisasi Sesi):** Pengguna memasukkan email dan password di Layar Login (SC02). Backend Express.js memverifikasi password (argon2) dan mengirimkan token sesi JWT. Aplikasi menyimpan token tersebut di dalam flutter\_secure\_storage (terlindungi oleh Android Keystore) dan mengaktifkan penanda biometric\_enabled \= 1 pada tabel SQLite local\_session\_settings.  
2. **Buka Kunci Biometrik Saat Aplikasi Dibuka Kembali (SC03):** Ketika pengguna menutup lalu membuka kembali aplikasi (atau aplikasi berada di latar belakang lebih dari 5 menit), Layar Splash (SC01) mendeteksi adanya sesi yang tersimpan dan langsung memicu dialog sidik jari Android (local\_auth).  
3. **Verifikasi Berhasil:** Jika sidik jari valid, aplikasi mengambil token dari flutter\_secure\_storage, memvalidasi sesi ke endpoint /api/auth/me, dan langsung mengarahkan pengguna ke halaman Beranda sesuai perannya (*Owner*, *Manager*, atau *Staff*) tanpa mengetik password.  
4. **Penanganan Kegagalan (*Fallback*):** Apabila pemindaian sidik jari gagal 3 kali berturut-turut, dibatalkan oleh pengguna, atau perangkat tidak memiliki sensor biometrik, aplikasi otomatis mengarahkan pengguna kembali ke Layar Login Password standar (SC02).

### **3.2 Pembagian Tugas Tim (3 Anggota Kelompok)**

Untuk memastikan seluruh 27 fitur selesai tepat waktu mengikuti jadwal presentasi mingguan setelah UTS, beban kerja dibagi menjadi 3 fokus utama:

* **Anggota 1 — Backend Web Service, Database & Blockchain:** Bertanggung jawab atas skema Prisma PostgreSQL (Supabase), autentikasi JWT (argon2), endpoint Katalog & Stok, transaksi atomik POS, perhitungan rantai hash **Blockchain SHA-256**, serta query SQL untuk **Dashboard Analitik**.  
* **Anggota 2 — Flutter Core UI, SQLite Lokal & Utilitas Mobile:** Bertanggung jawab atas kerangka navigasi multi-role, Layar Login & **Biometrik**, Halaman Profil bergambar & **Form Kesan Saran PAM**, UI Kasir POS, sinkronisasi **Backup Offline SQLite**, **Konversi Mata Uang (IDR/USD/EUR) & Zona Waktu (WIB/WITA/WIT/London)**, serta **Notifikasi Lokal**.  
* **Anggota 3 — Fitur Spesial (Sensor, LBS Peta, AI/LLM & Mini Game):** Bertanggung jawab atas integrasi **Sensor Accelerometer & Gyroscope**, layar **Peta Cabang LBS (flutter\_map & geolocator)**, integrasi **AI Business Assistant (Gemini API)**, serta pembuatan skenario & antarmuka **Mini Game**.

