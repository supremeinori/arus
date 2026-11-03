# ARUS SRS v3 — Software Requirements Specification & Master Blueprint

**Versi:** 3.0 (Living System Architecture — Reverse-Engineered Single Source of Truth)  
**Proyek:** ARUS — Multi-Outlet Mobile Business Intelligence & POS System  
**Mata Kuliah:** Pemrograman Aplikasi Mobile (PAM)  
**Stack Utama:** Flutter (Android/iOS) + Node.js/Express (TypeScript) + PostgreSQL (Supabase) + SQLite (`sqflite`)  
**Repository:** `https://github.com/supremeinori/arus` (branch `main`)  
**Dokumen ini menggantikan secara resmi:** `arus_srs_v2.md`, `ARUS_SRS.md`, `ARUS_DESAIN_ADDER.md`, `arus_modul.md`, `Modul_guide.md`, `arus_voice_spec.md`, dan `minigame_design.md`.

---

## Daftar Isi

1. [Identitas Produk & Arsitektur Global](#1-identitas-produk--arsitektur-global)
2. [Hak Akses Role & Struktur Navigasi (RBAC)](#2-hak-akses-role--struktur-navigasi-rbac)
3. [Daftar 5 Modul & 27 Fitur Utama (Plus Fitur Inovatif)](#3-daftar-5-modul--27-fitur-utama-plus-fitur-inovatif)
4. [Business Rules & Batasan Sistem (BR)](#4-business-rules--batasan-sistem-br)
5. [Desain Database Lengkap (17 Model PostgreSQL & 7 Tabel SQLite)](#5-desain-database-lengkap-17-model-postgresql--7-tabel-sqlite)
6. [Katalog API & Konvensi REST Web Service](#6-katalog-api--konvensi-rest-web-service)
7. [Aturan Keamanan (Security Requirements)](#7-aturan-keamanan-security-requirements)
8. [Panduan Pre-Production & Setup](#8-panduan-pre-production--setup)
9. [Aturan Production & Hard Forbids](#9-aturan-production--hard-forbids)
10. [Panduan Post-Production, Cron & Maintenance](#10-panduan-post-production-cron--maintenance)
11. [Panduan UI/UX & Standar Widget Mobile](#11-panduan-uiux--standar-widget-mobile)
12. [Feature Flags & Degradasi Fitur](#12-feature-flags--degradasi-fitur)
13. [Konvensi Kode & Struktur Direktori Monorepo](#13-konvensi-kode--struktur-direktori-monorepo)
14. [Strategi Pengujian & Skenario Demo](#14-strategi-pengujian--skenario-demo)
15. [Pembagian Tugas Tim & Requirement Traceability Matrix](#15-pembagian-tugas-tim--requirement-traceability-matrix)

---

## 1. Identitas Produk & Arsitektur Global

### 1.1 Ringkasan Eksekutif
ARUS adalah platform terpadu operasional kasir seluler (*Mobile POS*) dan sistem pendukung keputusan bisnis multi-cabang (*Mobile Business Decision-Support System*). Aplikasi mobile dibangun menggunakan **Flutter** yang berkomunikasi secara eksklusif ke **Express.js REST API pribadi** (Node.js/TypeScript) dengan database cloud **PostgreSQL (Supabase, 17 Model Relasional)**. 

Untuk memastikan keandalan mutlak saat jaringan internet terputus di lapangan (*offline-first*), Flutter mengimplementasikan database lokal **SQLite (`sqflite`, 7 Tabel)** yang mendukung pencadangan katalog, ketersediaan porsi, riwayat 50 struk terakhir, cache analitik harian, serta **antrean transaksi kasir offline (*Offline POS Queue*)** yang disinkronisasikan otomatis ke server cloud secara idempoten ketika koneksi internet kembali online melalui `sync_service.dart`.

Sistem diperkaya dengan **Dual-Layer Blockchain SHA-256** dan penjangkaran publik **Web3 Ethereum Sepolia** untuk jaminan integritas anti-manipulasi (*tamper proofing*), **ARUS AI Copilot (Google Gemini LLM)** dengan kemampuan percakapan suara **Edge TTS (`id-ID-GadisNeural`)** dan **Speech-to-Text Push-to-Talk**, modul **AI Forecasting (Sales & Stockout Velocity)**, serta **Mini Game ("Guess the Menu")** dengan kontrol sensor giroskop 2-arah dan sintesis audio prosedural.

### 1.2 Diagram Arsitektur Sistem

```text
[ Flutter Mobile App (Android / iOS) ]
   ├── UI Shell: 4 Bottom Tabs (Beranda, Operasi/Kasir, Analitik/Stok, Profil)
   ├── Global AI Floating Action Button (FAB) -> Bottom Sheet & Fullscreen AI Voice
   ├── State Management: Riverpod (AsyncNotifier / FutureProvider / StateProvider)
   ├── Local DB: SQLite (sqflite) -> 7 Tabel (Session, Categories, Products, Backup Products,
   │                                  Offline POS Queue, Backup Receipts, Daily Analytics)
   ├── Hardware & Sensors: Accelerometer (Shake), Gyroscope (Tilt 2-Way), Biometric Keystore, GPS
   │
   ├──► (HTTPS REST JSON) ──► [ Express.js Backend API (/api/*) ]
   │                             ├── Middleware: Auth JWT (argon2id), RBAC, Outlet Scope, Zod, Rate Limit
   │                             ├── Blockchain Engine: Dual-Layer In-Memory & Database Mirror
   │                             ├── AI Grounding Engine & Edge TTS (id-ID-GadisNeural)
   │                             └── Prisma ORM ──► [ PostgreSQL Cloud (Supabase, 17 Models) ]
   │
   └──► (Public Web Services)
         ├── Frankfurter API (Kurs Realtime: IDR, USD, EUR)
         ├── OpenStreetMap Services (Peta Cabang & LBS Haversine)
         ├── Google Gemini API (LLM Business Copilot via Backend Grounding)
         ├── Ethereum Sepolia Testnet (Web3 Public Integrity Anchor & Verifier)
         └── Firebase Cloud Messaging (Opsional: Registrasi DeviceToken & Push Notif)
```

### 1.3 Scope Sistem
* **Dalam Scope (In-Scope):** 
  - Autentikasi JWT (`argon2id`) dengan Refresh Token Family Rotation, Biometric Unlock (`local_auth`), Manajemen Sesi aman (`flutter_secure_storage`), Profil Pengguna, dan Formulir Umpan Balik Perkuliahan PAM.
  - Multi-Role & Outlet Scoping: **Owner** (kontrol global seluruh cabang), **Manager** (kontrol operasional & staf cabang tugas), dan **Staff / Kasir** (layar kasir & stok cabang tugas).
  - Manajemen Katalog Menu (`products`) dan Resep Bahan Baku (`product_recipes`), Manajemen Inventaris Bahan Mentah Cabang (`ingredients`), dan Audit Mutasi Stok (`inventory_movements`).
  - Kasir POS Atomik Berbasis Resep, Kalkulasi HPP (*Unit Cost*), dan Antrean Transaksi Kasir Offline (*Offline POS Queue Sync* idempoten).
  - Integritas Data Kriptografis: **Dual-Layer Blockchain SHA-256** (*Child Transaction Block* & *Parent Daily Block* dengan *Merkle Root*) dan **Web3 Public Anchor (Ethereum Sepolia)** untuk verifikasi keaslian publik tanpa login.
  - In-App Notification Center terpusat (`notifications`) dengan deduplikasi otomatis (`dedup_key`), evaluasi pemicu stok kritis, dan dukungan registrasi `DeviceToken` FCM opsional.
  - Dashboard Analitik KPI, Tren Penjualan Harian/Mingguan/Bulanan (`/sales-trend`), Leaderboard Menu Terlaris, Multi-Currency (IDR/USD/EUR via Frankfurter), Multi-Timezone (WIB/WITA/WIT/London).
  - AI Sales & Stockout Forecasting: Prediksi deret waktu penjualan masa depan dan perkiraan kehabisan bahan baku.
  - Sensor Accelerometer (*Shake to Refresh*) & Gyroscope (*Tilt Orientation Test* serta Kontrol Kemiringan Game).
  - Peta Cabang LBS (*Location-Based Services*) interaktif dengan formula matematika **Haversine Formula**.
  - Rule-Based Decision Support System (Insights Evaluasi *on-the-fly* R1, R2, R4).
  - ARUS AI Business Assistant: Google Gemini LLM *grounded facts*, rekomendasi harga jual menu baru (`/recommend-price`), dan mode interaksi suara **ARUS Voice Mode (Edge TTS `id-ID-GadisNeural` + STT Push-to-Talk)**.
  - Mini Game *"Guess the Menu"*: Mode Tebak Nama & Mode Tebak Harga berbasis katalog menu nyata toko, dilengkapi kontrol giroskop 2-arah dan sintesis efek suara prosedural (`SynthAudioService`).
* **Luar Scope (Out-of-Scope):** 
  - Cetak struk fisik via printer thermal hardware Bluetooth (fokus pada digital receipt & riwayat offline).
  - Multi-tenancy publik terbuka (sistem bersifat *private multi-outlet enterprise* untuk jaringan toko internal).

---

## 2. Hak Akses Role & Struktur Navigasi (RBAC)

Aplikasi menerapkan *Role-Based Access Control* (RBAC) presisi dengan 3 role: **Owner**, **Manager**, dan **Staff (Kasir)**.

### 2.1 Struktur Navigasi Bawah (Bottom Navigation Bar)
Navigasi shell utama (`MainShell`) menggunakan **4 Tab** untuk seluruh role demi konsistensi ergonomi satu tangan di perangkat mobile:

* **Owner & Manager (4 Tab):**
  1. `Beranda` (`DashboardScreen`): Ringkasan KPI eksekutif omzet, transaksi, basket size, margin, tren penjualan, target harian, ranking produk, dan ringkasan AI/Insights.
  2. `Operasi` (`OperationsHubScreen`): Pusat operasional toko.
     - **Owner:** Akses ke Menu Produk (`/catalog`), Inventaris Bahan (`/inventory`), Kelola Staf & Akun Seluruh Cabang (`/users`), Riwayat Struk Transaksi (`/pos/history`), dan Mini Game (`/game`).
     - **Manager:** Akses ke Menu Cabang (`/operations/menu`), Inventaris Bahan Cabang (`/inventory`), Kelola Staf Cabang Sendiri (`/users`), Riwayat Struk Transaksi, dan Mini Game.
  3. `Analitik` (`AnalyticsScreen`): Analisis mendalam omzet harian/mingguan/bulanan, jam sibuk (*peak hours*), perbandingan cabang, leaderboard menu, dan modul prediksi AI Forecasting.
  4. `Profil` (`ProfileScreen`): Identitas akun, status biometrik, preferensi kurs mata uang & zona waktu, menu Cabang & Outlet (khusus Owner), Integritas Data Blockchain Ledger, Diagnostik Sensor, Saran & Kesan Matkul PAM, Tentang ARUS, dan Logout.

* **Staff / Kasir (4 Tab):**
  1. `Beranda` (`ShiftSummaryScreen`): Ringkasan operasional shift hari berjalan (total uang masuk, jumlah transaksi, breakdown tunai/QRIS/kartu).
  2. `Kasir` (`PosScreen`): Layar mesin kasir mobile utama, pemilihan menu, keranjang belanja dinamis, kalkulasi kembalian, dan cetak struk digital (online & offline queue).
  3. `Stok` (`InventoryListScreen`): Monitoring ketersediaan bahan mentah di cabangnya sendiri (*Read-Only*).
  4. `Profil` (`ProfileScreen`): Identitas staf, preferensi sesi, diagnostik sensor, Saran/Kesan PAM, Tentang ARUS, dan Logout.

> **Akses ARUS AI Business Copilot:**  
> Fitur AI **tidak ditaruh pada tab navigasi bawah**, melainkan dapat dipanggil secara fleksibel dari halaman mana pun melalui **Global Floating Action Button (FAB) Maskot AI** di pojok kanan bawah. Menekan FAB akan menampilkan *AI Companion Bottom Sheet* atau membuka layar penuh `/ai`. Tombol FAB ini otomatis disembunyikan untuk role Staff/Kasir.

### 2.2 Permission Matrix (Kesesuaian Aktual As-Is)

| Area Fungsional | Owner | Manager | Staff | Implementasi Teknis As-Is |
|---|:---:|:---:|:---:|---|
| **Cakupan Outlet** | Semua Cabang | Cabang Terdaftar | 1 Cabang Tugas | Divalidasi via tabel `user_outlets` |
| **Manajemen User** | CRUD Penuh (Semua Cabang) | CRUD Kasir Cabang Sendiri | Ditolak (403) | Backend mengizinkan Manager membuat & mengelola kasir di cabangnya via `users.service.ts` |
| **Katalog Produk** | CRUD Penuh | Read-Only (`/operations/menu`) | Read-Only | Operasi tulis katalog (`POST/PUT/DELETE`) dan rute `/catalog` dikunci khusus Owner di backend & Flutter route guard |
| **Penyesuaian Stok** | CRUD Penuh | Cabang Sendiri | Ditolak (403) | Manager dapat mencatat Restock, Koreksi Opname, & Waste pada cabang wewenangnya |
| **Kasir POS** | Akses Penuh | Cabang Sendiri | Layar Kasir Utama | Staff mengakses POS via Tab 2 Kasir; Manager/Owner memiliki akses via API dan rute `/pos` |
| **Void Transaksi** | Kapan Saja | Max 24 Jam | Ditolak (403) | Mengembalikan stok bahan baku atomik dan mencatat blok pembatalan di blockchain |
| **Dashboard & Analitik** | Penuh (Semua Cabang) | Cabang Sendiri | Ringkasan Shift | Staff dialihkan ke `ShiftSummaryScreen` |
| **AI Copilot & Voice** | Penuh (Semua Cabang) | Cabang Sendiri | Ditolak (403) | FAB AI disembunyikan dan rute `/ai` diblokir untuk Staff |
| **Blockchain Audit** | Penuh | Cabang Sendiri | Badge Struk Saja | Verifikasi rantai blok dan pemulihan snapshot cadangan |
| **Web3 Public Anchor** | Penuh | Penuh | Publik (Tanpa Login) | Verifikasi bukti transaksi di blockchain publik Sepolia |
| **Peta Cabang (LBS)** | CRUD & Peta Interaktif | Lokasi Terdaftar | Read-Only Lokasi | Rute form cabang `/outlets` dipagari untuk Owner; visualisasi jarak diakses via LBS widget |

### 2.3 Peta Rute Navigasi Mobile (`lib/core/routing/app_router.dart`)

Seluruh perpindahan layar diatur secara deklaratif melalui package `go_router`:

| Path Rute | Widget Layar Utama | Hak Akses Role | Keterangan & Alur Navigasi |
|---|---|---|---|
| `/splash` | `SplashScreen` | Publik | Pengecekan sesi lokal & inisialisasi health check |
| `/login` | `LoginScreen` | Publik | Form login kredensial & otentikasi biometrik |
| `/shell` | `MainShell` | Terotentikasi | Shell navigasi 4 tab + Global Floating Action Button AI |
| `/pos` | `PosScreen` | Terotentikasi | Layar mesin kasir POS, keranjang & pembayaran |
| `/pos/history` | `PosHistoryScreen` | Terotentikasi | Riwayat struk (`scope=dashboard` atau transaksi kasir aktif) |
| `/settings` | `SettingsScreen` | Terotentikasi | Pengaturan aplikasi terpadu |
| `/settings/currency`| `CurrencySettingsScreen`| Terotentikasi | Pemilihan mata uang (IDR, USD, EUR) & kurs real-time |
| `/settings/time` | `TimeSettingsScreen` | Terotentikasi | Pemilihan zona waktu (WIB, WITA, WIT, London) |
| `/sensors` | `SensorTestScreen` | Terotentikasi | Diagnostik sensor Accelerometer, Gyroscope & Biometrik |
| `/notifications` | `NotificationScreen` | Terotentikasi | Kotak masuk notifikasi stok menipis & peringatan sistem |
| `/ai` | `AiHomeScreen` | Owner & Manager | Layar penuh AI Business Copilot & ARUS Voice Mode |
| `/outlets` | `OutletListScreen` | **Khusus Owner** | Daftar cabang & visualisasi peta interaktif LBS |
| `/outlets/new` | `OutletFormScreen` | **Khusus Owner** | Form tambah cabang baru & penentu koordinat peta |
| `/outlets/:id` | `OutletDetailScreen` | **Khusus Owner** | Detail cabang, ringkasan inventaris & staf |
| `/outlets/:id/edit`| `OutletFormScreen` | **Khusus Owner** | Form edit data dan lokasi cabang |
| `/insights` | `InsightsScreen` | Owner & Manager | Layar Rule-Based Decision Support System (R1, R2, R4) |
| `/inventory` | `InventoryListScreen` | Terotentikasi | Monitoring sisa stok bahan baku cabang |
| `/inventory/movements`| `StockMovementScreen`| Owner & Manager | Riwayat audit kartu mutasi keluar-masuk stok |
| `/catalog` | `ProductListScreen` | **Khusus Owner** | Manajemen katalog master produk & resep |
| `/catalog/new` | `MenuCreateScreen` | **Khusus Owner** | Form wizard tambah menu, HPP live & rekomendasi harga AI |
| `/catalog/:id` | `ProductDetailScreen` | **Khusus Owner** | Detail menu, komposisi resep & harga jual |
| `/catalog/:id/edit`| `MenuCreateScreen` | **Khusus Owner** | Edit menu & penyesuaian takaran resep |
| `/operations` | `OperationsHubScreen` | Terotentikasi | Pusat operasional cabang |
| `/operations/menu` | `ManagerMenuScreen` | Manager & Staff | Monitoring menu cabang & proyeksi margin profit (*read-only*) |
| `/integrity` | `IntegrityChainScreen` | Owner & Manager | Audit rantai blok SHA-256 & Web3 Sepolia Ledger |
| `/game` | `GameHomeScreen` | Semua Role | Mini game tebak menu/harga, kontrol giroskop & synth audio |
| `/search` | `GlobalSearchScreen` | Terotentikasi | Pencarian global produk & cabang toko |
| `/about` | `AboutScreen` | Terotentikasi | Profil aplikasi ARUS, versi build, & anggota pengembang |
| `/feedback` | `FeedbackScreen` | Terotentikasi | Formulir kesan & saran perkuliahan PAM |
| `/users` | `UserManagementScreen`| Owner & Manager | Kelola staf (Owner: semua; Manager: cabang sendiri) |
| `/leaderboard` | `LeaderboardScreen` | Owner & Manager | Peringkat produk terlaris berdasarkan volume penjualan |

> **Route Guard RBAC:**  
> Rute `/outlets/*` dan `/catalog/*` diproteksi ketat pada callback `redirect` `AppRouter`: jika role pengguna bukan Owner (`!authState.isOwner`), aplikasi secara otomatis membatalkan navigasi dan mengarahkan kembali ke `/shell`. Rute `/ai` diblokir untuk role Staff.

---

## 3. Daftar 5 Modul & 27 Fitur Utama (Plus Fitur Inovatif)

Sistem ARUS disusun secara modular ke dalam **5 Modul Utama** yang mencakup **27 Fitur Wajib PAM** beserta ekstensi fitur mutakhir:

```text
ARUS Master Modules
├── MOD-1: Autentikasi, Keamanan, Sesi & Profil (Fitur 1–7)
├── MOD-2: Operasional — Menu, Resep, Inventaris Gudang & Kasir POS (Fitur 8–15)
├── MOD-3: Integritas Blockchain SHA-256, Web3 & Notifikasi Mobile (Fitur 16–18)
├── MOD-4: Dashboard Analitik, Forecasting AI, Utilitas, Sensor & LBS (Fitur 19–24)
└── MOD-5: Kecerdasan Buatan (AI Copilot & Voice), DSS & Mini Game (Fitur 25–27)
```

### 3.1 MOD-1: Autentikasi, Keamanan & Profil (Fitur 1–7)
* **Fitur 1 — Login Enkripsi Password:** Autentikasi kredensial email & password menggunakan algoritma hashing modern **`argon2id`** dengan salt unik di backend Express.js. Menghasilkan sepasang JWT (Access Token 15 menit & Refresh Token 7 hari).
* **Fitur 2 — Session Management & Token Rotation:** Penyimpanan token sesi di secure storage (`flutter_secure_storage` via Android Keystore / iOS Keychain) dan tabel PostgreSQL `refresh_tokens` dengan mekanisme Family Rotation.
* **Fitur 3 — Login Biometrik:** Buka kunci aplikasi instan menggunakan sensor biometrik (sidik jari/wajah) via package `local_auth`. Membuka sesi aktif dari secure storage tanpa input ulang kata sandi.
* **Fitur 4 — Profil Akun Bergambar:** Layar akun menampilkan avatar gambar (`avatar_url`), nama lengkap, email, role, daftar cabang aktif pengguna, dan preferensi mata uang/zona waktu.
* **Fitur 5 — Menu Kesan & Saran Matkul PAM:** Formulir testimoni kesan dan saran perkuliahan PAM yang disimpan ke tabel PostgreSQL `feedback`.
* **Fitur 6 — Menu Logout & Revocation:** Menghapus token dari secure storage dan SQLite lokal, merevokasi token refresh di backend, dan mengarahkan pengguna kembali ke Layar Login.
* **Fitur 7 — Manajemen User & Multi-Role (RBAC):** Menu pengelolaan akun pengguna. Owner dapat mengelola seluruh akun (Owner, Manager, Staff) di semua cabang; Manager dapat mendaftarkan dan memperbarui kasir di cabangnya sendiri.

### 3.2 MOD-2: Operasional — Menu, Resep, Inventaris & Kasir POS (Fitur 8–15)
Arsitektur operasional bisnis F&B ARUS memisahkan secara tegas antara **Menu Jualan Kasir (`products`)** dan **Bahan Mentah di Gudang (`ingredients`)**, yang dihubungkan melalui **Resep Porsi (`product_recipes`)**:

1. **Database Menu Jualan (`products`):** Menyimpan nama menu, kode SKU unik, kategori, foto produk (`image_url`), dan harga jual (`price_idr`).
2. **Database Bahan Baku Cabang (`ingredients`):** Menyimpan stok bahan mentah per cabang (`outlet_id`), satuan dasar (`gram`, `ml`, `pcs`), batas peringatan stok menipis (`reorder_level`), dan harga modal modal per unit (`cost_per_unit`).
3. **Resep Menu (`product_recipes`):** Menentukan takaran kebutuhan bahan baku untuk memproduksi 1 porsi menu (`amount_needed`).
4. **Formula Estimasi Porsi Dinamis (*Dynamic Portion Calculation*):**
   $$\text{Estimasi Porsi} = \min_{i \in \text{Resep}} \left\lfloor \frac{\text{Stok Bahan Baku}_i}{\text{Takaran per Porsi}_i} \right\rfloor$$
5. **Dukungan Kasir Offline (*Offline POS Queue*):** Jika jaringan internet terputus di lapangan, transaksi disimpan ke tabel SQLite lokal `offline_transactions` dan disinkronkan secara aman melalui `sync_service.dart`.

* **Fitur 8 — Kelola Menu & Resep (Owner):** [Owner] Menambah, memperbarui, dan menonaktifkan menu beserta takaran bahan bakunya (`product_recipes`). Manager mengakses halaman monitoring menu dan proyeksi HPP di `/operations/menu`.
* **Fitur 9 — Pencarian & Filter Katalog (Estimasi Porsi):** [Semua Role] Mencari menu dan memfilter kategori dengan badge sisa porsi dinamis secara real-time.
* **Fitur 10 — Backup Offline Katalog (SQLite):** [Semua Role] Menyimpan salinan daftar menu dan kuota porsi ke tabel SQLite `cached_products` dan `backup_products`.
* **Fitur 11 — Manajemen & Filter Bahan Baku Cabang:** [Owner, Manager] Monitoring bahan baku per cabang dengan filter status (`ok`, `low`, `out`).
* **Fitur 12 — Penyesuaian Stok Atomik (*Adjustment*):** [Owner, Manager] Mencatat mutasi bahan baku (restock, koreksi opname, waste) secara atomik ke `inventory_movements`.
* **Fitur 13 — Kasir Mobile POS Berbasis Resep Atomik:** [Semua Role] Validasi kebutuhan bahan baku dari seluruh item keranjang, potong stok di `ingredients`, dan catat keluar di `inventory_movements` dalam 1 transaksi atomik Prisma.
* **Fitur 14 — Pencarian Struk & Backup Transaksi (SQLite):** [Semua Role] Mencari struk transaksi dan mencadangkan 50 struk terakhir ke tabel SQLite `backup_transactions`.
* **Fitur 15 — Pembatalan Transaksi (*Void*) & Pengembalian Stok:** [Owner, Manager] Membatalkan struk, mengembalikan kuantitas bahan baku ke `ingredients` (`void_return`), dan mencatat blok pembatalan di blockchain.

### 3.3 MOD-3: Integritas Blockchain SHA-256, Web3 & Notifikasi Mobile (Fitur 16–18)
* **Fitur 16 — Pencatatan Rantai Hash Dual-Layer & Mirror Database:**
  - **Child Block (Transaction Layer):** Menyimpan transaksi individu hari berjalan secara berantai menggunakan SHA-256 (`previousHash` ke transaksi sebelumnya).
  - **Parent Block (Daily Layer):** Menghubungkan ringkasan transaksi harian ke hari sebelumnya (`previousParentHash`) dengan kalkulasi *Merkle Root*.
  - **Database Mirror Persisten:** Dicerminkan ke tabel PostgreSQL `blockchain_records` lengkap dengan snapshot cadangan valid (`backup_*`).
  - **Web3 Public Anchor (Ethereum Sepolia):** Penjangkaran hash transaksi ke jaringan testnet Ethereum Sepolia melalui smart contract untuk pembuktian integritas publik tanpa login via endpoint `/api/integrity/web3/*`.
* **Fitur 17 — Verifikasi Keaslian Data & Tamper Recovery:** Fitur audit rantai blok yang menghitung ulang hash transaksi. Jika data nominal/item di database diubah secara ilegal, status berubah menjadi **TAMPERED**, dan sistem menyediakan pemulihan otomatis dari snapshot cadangan bersih (`recoverBlock`).
* **Fitur 18 — Notifikasi Mobile Stok Menipis:** Pemicu otomatis di backend saat stok bahan baku $\leq$ `reorder_level`. Disajikan melalui *In-App Notification Center* (`notifications`) dengan deduplikasi otomatis via `dedup_key`, evaluasi batch, dan dukungan registrasi `DeviceToken` FCM.

### 3.4 MOD-4: Dashboard Analitik, Forecasting AI, Sensor & LBS (Fitur 19–24)
* **Fitur 19 — Dashboard Analitik KPI & Tren Penjualan:** Ringkasan metrik total omzet, jumlah transaksi, average basket size (ATV), margin laba kotor, dan grafik tren penjualan (`/api/analytics/sales-trend`) dengan opsi periode harian, mingguan, dan bulanan.
* **Fitur Plus — AI Sales & Stockout Forecasting:** Modul prediktif berbasis time-series yang memproyeksikan estimasi omzet 7–30 hari ke depan (`/api/analytics/forecast/sales`) dan perkiraan hari habisnya stok bahan baku berdasarkan laju konsumsi riil (`/api/analytics/forecast/stockout`).
* **Fitur 20 — Konversi 3 Mata Uang (IDR, USD, EUR):** Pengubah mata uang tampilan menggunakan kurs realtime dari Frankfurter API dengan cache in-memory. Data dasar database tetap tersimpan dalam IDR integer.
* **Fitur 21 — Konversi 4 Zona Waktu (WIB, WITA, WIT, London):** Konversi waktu transaksi otomatis berdasarkan zona waktu operasional cabang lokal hingga cabang internasional London.
* **Fitur 22 — Sensor 1: Accelerometer (*Shake to Refresh*):** Deteksi guncangan perangkat untuk memuat ulang data analitik dashboard secara instan melalui package `sensors_plus` dengan pengaturan sensitivitas guncangan.
* **Fitur 23 — Sensor 2: Gyroscope (*Tilt Orientation Test*):** Deteksi sudut kemiringan fisik HP (Pitch, Roll, Yaw) untuk diagnostik orientasi perangkat.
* **Fitur 24 — Peta Cabang LBS (*Location-Based Services*):** Kalkulasi jarak posisi GPS pengguna ke seluruh cabang menggunakan **Haversine Formula**, indikator cabang terdekat, dan visualisasi rute peta OpenStreetMap.

### 3.5 MOD-5: Kecerdasan Buatan (AI Copilot & Voice), DSS & Mini Game (Fitur 25–27)
* **Fitur 25 — Rule-Based Decision Support System (Insights):** Mesin aturan analitik deterministik yang dievaluasi *on-the-fly* terhadap data nyata: R1 (`LOW_STOCK`), R2 (`RESTOCK_URGENT`), dan R4 (`SLOW_MOVING`) disertai bukti angka konkrit (*evidence*).
* **Fitur 26 — ARUS AI Business Assistant (Gemini LLM & Voice):**
  - Chatbot konsultasi bisnis cerdas dengan persona ramah yang *grounded* mutlak pada fakta database nyata (omzet, transaksi, stok bahan baku, basket size).
  - Format respon eksekutif terstruktur: *Ringkasan Penjualan/Stok, Analisis Bisnis, dan Rekomendasi Keputusan (DSS)*.
  - **ARUS Voice Mode:** Integrasi interaksi suara dua arah menggunakan **Microsoft Edge TTS (`id-ID-GadisNeural`)** di backend via endpoint `POST /api/ai/tts` dan tag penanda `[VOICE_SUMMARY]` untuk dibacakan secara audio, serta **Speech-to-Text Push-to-Talk** di Flutter.
  - **AI Menu Price Recommendation:** Rekomendasi harga jual menu baru secara cerdas (`POST /api/ai/recommend-price`) berdasarkan takaran HPP modal dan target margin saat perancangan menu.
* **Fitur 27 — Mini Game ("Guess the Menu"):** Permainan kuis interaktif berbasis katalog menu nyata toko dengan 2 mode permainan: Mode Tebak Nama (*guess_name*) dan Mode Tebak Harga (*guess_price*). Dilengkapi dengan kontrol sensor kemiringan giroskop 2-arah (miring kiri/kanan untuk memilih opsi), timer 10 detik, dan efek suara prosedural via `SynthAudioService`.

---

## 4. Business Rules & Batasan Sistem (BR)

### 4.1 Autentikasi & Keamanan (BR-AUTH)
* **BR-AUTH-01:** Password wajib di-hash menggunakan algoritma **`argon2id`** sebelum disimpan ke database.
* **BR-AUTH-02:** Percobaan login gagal sebanyak 5 kali berturut-turut mengakibatkan akun terkunci sementara selama 15 menit (HTTP 423 Locked).
* **BR-AUTH-03:** Sesi menggunakan Access Token JWT (TTL 15 menit) dan Refresh Token (TTL 7 hari) yang disimpan aman di `flutter_secure_storage` serta dicatat di tabel `refresh_tokens`.
* **BR-AUTH-04:** Setiap pembaruan sesi via `/api/auth/refresh` merotasi refresh token baru (*Family Rotation*) dan membatalkan token lama.
* **BR-AUTH-05:** Preferensi mata uang tampilan pengguna disimpan persisten pada kolom `users.display_currency` di server serta di-cache di SQLite lokal.
* **BR-AUTH-06:** Biometrik bertindak sebagai pengaman sesi lokal untuk mengakses token di Android Keystore tanpa meminta password ulang.

### 4.2 Katalog Produk & Harga (BR-CAT)
* **BR-CAT-01:** Kode SKU bersifat unik global; harga jual (`price_idr`) dan biaya modal bahan baku (`cost_per_unit`) wajib disimpan sebagai tipe data **integer IDR**.
* **BR-CAT-02:** Setiap menu aktif wajib memiliki minimal 1 baris bahan baku pada tabel `product_recipes` agar estimasi porsinya dapat dihitung secara dinamis.
* **BR-CAT-03:** Penambahan, pembaruan resep, dan perubahan harga produk di master katalog dibatasi ketat hanya untuk role **Owner** (`catalog.route.ts`). Role Manager diarahkan ke `/operations/menu` untuk monitoring HPP/profit.
* **BR-CAT-04:** Nilai modal bahan baku (`cost_per_unit`) dan HPP modal produk (`cost_idr`) disaring ketat di backend; role Staff tidak boleh menerima field harga modal di response JSON apa pun.

### 4.3 Inventaris, Bahan Baku & Mutasi Stok (BR-INV)
* **BR-INV-01 (Kalkulasi Porsi Dinamis):**
  $$\text{estimated\_portions} = \min_{i \in \text{Resep}} \left\lfloor \frac{\text{stock\_qty}_i}{\text{amount\_needed}_i} \right\rfloor$$
* **BR-INV-02:** Batasan `stock_qty >= 0` ditegakkan secara absolut di tingkat PostgreSQL (`CHECK constraint`). Stok bahan baku dilarang bernilai minus.
* **BR-INV-03:** Setiap mutasi penambahan atau pengurangan `stock_qty` wajib menulis baris catatan ke `inventory_movements` dalam transaksi database yang sama (Atomik).
* **BR-INV-04:** Klasifikasi status stok:
  - `ok`: Kuantitas > `reorder_level`
  - `low`: Kuantitas $\leq$ `reorder_level` dan Kuantitas > 0
  - `out`: Kuantitas = 0
* **BR-INV-05:** Catatan pada `inventory_movements` bersifat *append-only* (dilarang *hard delete*).

### 4.4 Kasir POS & Transaksi Berbasis Resep (BR-POS)
* **BR-POS-01 (Validasi Bahan Gabungan):** Server menjumlahkan total kebutuhan setiap bahan baku dari seluruh item di keranjang sebelum memotong stok. Jika ada satu saja bahan baku yang kurang, seluruh transaksi digagalkan secara atomik (HTTP 400/409 `INSUFFICIENT_STOCK`).
* **BR-POS-02 (Idempotensi Transaksi):** Endpoint transaksi bersifat idempoten menggunakan UUID `client_request_id`. Request ganda dengan ID yang sama mengembalikan struk asli tanpa memotong stok ulang.
* **BR-POS-03 (Dukungan Offline POS):** Saat offline, transaksi disimpan sementara ke tabel SQLite `offline_transactions` dan disinkronkan otomatis saat online via `sync_service.dart`.
* **BR-POS-04:** Transaksi POS sukses merekam snapshot modal pada `transaction_items.unit_cost_idr` berdasarkan penjumlahan HPP resep saat itu.
* **BR-POS-05:** Void transaksi diizinkan maksimal 24 jam (Manager) atau kapan saja (Owner). Void mengembalikan stok bahan baku (`void_return`) dan mencatat blok pembatalan di blockchain.

### 4.5 Blockchain & Integritas Kriptografis (BR-INT)
* **BR-INT-01 (Dual-Layer Hash):** Child block merangkum transaksi individual dengan SHA-256; Parent block merangkum penutupan hari dengan *Merkle Root*.
* **BR-INT-02 (Database Mirror & Backup):** Setiap rekam blok di `blockchain_records` memuat kolom cadangan `backup_*` untuk verifikasi dan pemulihan otomatis (*self-healing*).
* **BR-INT-03 (Advisory Lock):** Pembuatan blok baru di PostgreSQL menggunakan `pg_advisory_xact_lock(hashtext(outlet_id))` untuk menjamin kerapatan urutan `block_index` tanpa celah (*gap*).
* **BR-INT-04 (Web3 Anchoring):** Hash penutupan blok dapat dijangkarkan ke testnet publik Ethereum Sepolia untuk audit independen konsumen via endpoint `/api/integrity/web3/*`.

### 4.6 Analitik, Konversi & LBS (BR-ANA / LBS)
* **BR-ANA-01:** Perhitungan pergantian hari transaksi mengikuti zona waktu operasional lokal masing-masing cabang (`outlets.timezone`).
* **BR-LBS-01:** Jarak antara posisi GPS pengguna dan cabang toko wajib dihitung menggunakan formula matematika **Haversine Formula**.

### 4.7 Kecerdasan Buatan & Voice (BR-AI)
* **BR-AI-01 (Zero Hallucination pada Angka Bisnis):** Seluruh angka nominal, omzet, margin, dan kuantitas stok wajib berasal dari *factual payload* yang dikumpulkan backend secara real-time dari database.
* **BR-AI-02 (Format Respon Terstruktur & Voice Summary):** Respon AI wajib memuat:
  1. 📌 **Ringkasan Penjualan / Inventaris**
  2. 📊 **Analisis Bisnis & Akar Masalah**
  3. 💡 **Rekomendasi Keputusan (DSS)**
  4. Penanda khusus `[VOICE_SUMMARY]: <ringkasan lisan 1-2 kalimat>` di bagian paling akhir untuk disintesis oleh modul suara Edge TTS `id-ID-GadisNeural`.
* **BR-AI-03:** Rate limit AI: maksimal 10 request per menit dan 100 request per hari per user.

---

## 5. Desain Database Lengkap (17 Model PostgreSQL & 7 Tabel SQLite)

### 5.1 Skema Lengkap PostgreSQL (`api/prisma/schema.prisma` — 17 Model Relasional)

```prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider  = "postgresql"
  url       = env("DATABASE_URL")
  directUrl = env("DIRECT_URL")
}

enum Role {
  owner
  manager
  staff
}

enum MovementType {
  sale
  void_return
  restock
  correction
  waste
}

enum PaymentMethod {
  cash
  qris_simulated
  card_simulated
}

enum TxnStatus {
  completed
  voided
}

enum GameMode {
  guess_name
  guess_price
}

// ==========================================
// MODUL 1: AUTENTIKASI, PENGGUNA & CABANG
// ==========================================

model User {
  id                String       @id @default(uuid()) @db.Uuid
  name              String       @db.VarChar(100)
  email             String       @unique @db.VarChar(255)
  password_hash     String       @db.Text
  role              Role         @default(staff)
  avatar_url        String?      @db.Text
  display_currency  String       @default("IDR") @db.VarChar(10)
  is_active         Boolean      @default(true)
  created_at        DateTime     @default(now()) @db.Timestamptz()
  updated_at        DateTime     @updatedAt @db.Timestamptz()

  outlets        UserOutlet[]
  feedbacks      Feedback[]
  transactions   Transaction[]
  movements      InventoryMovement[]
  notifications  Notification[]
  ai_logs        AiChatLog[]
  game_sessions  GameSession[]
  refresh_tokens RefreshToken[]
  device_tokens  DeviceToken[]

  @@map("users")
}

model Outlet {
  id         String   @id @default(uuid()) @db.Uuid
  name       String   @unique @db.VarChar(100)
  address    String   @db.Text
  latitude   Decimal  @db.Decimal(9, 6)
  longitude  Decimal  @db.Decimal(9, 6)
  timezone   String   @default("Asia/Jakarta") @db.VarChar(40)
  is_active  Boolean  @default(true)
  created_at DateTime @default(now()) @db.Timestamptz()
  updated_at DateTime @updatedAt @db.Timestamptz()

  users        UserOutlet[]
  ingredients  Ingredient[]
  transactions Transaction[]
  blocks       BlockchainRecord[]

  @@map("outlets")
}

model UserOutlet {
  user_id   String @db.Uuid
  outlet_id String @db.Uuid

  user   User   @relation(fields: [user_id], references: [id], onDelete: Cascade)
  outlet Outlet @relation(fields: [outlet_id], references: [id], onDelete: Cascade)

  @@id([user_id, outlet_id])
  @@map("user_outlets")
}

model Feedback {
  id         String   @id @default(uuid()) @db.Uuid
  user_id    String   @db.Uuid
  kesan      String   @db.Text
  saran      String   @db.Text
  created_at DateTime @default(now()) @db.Timestamptz()

  user User @relation(fields: [user_id], references: [id], onDelete: Cascade)

  @@map("feedback")
}

// ==========================================
// MODUL 2: KATALOG & INVENTARIS RESEP
// ==========================================

model ProductCategory {
  id         String   @id @default(uuid()) @db.Uuid
  name       String   @unique @db.VarChar(80)
  created_at DateTime @default(now()) @db.Timestamptz()

  products Product[]

  @@map("product_categories")
}

model Product {
  id          String   @id @default(uuid()) @db.Uuid
  category_id String?  @db.Uuid
  sku         String   @unique @db.VarChar(40)
  name        String   @db.VarChar(120)
  image_url   String?  @db.Text
  price_idr   Int
  is_active   Boolean  @default(true)
  created_at  DateTime @default(now()) @db.Timestamptz()
  updated_at  DateTime @updatedAt @db.Timestamptz()

  category  ProductCategory?  @relation(fields: [category_id], references: [id])
  recipes   ProductRecipe[]
  txn_items TransactionItem[]

  @@map("products")
}

model Ingredient {
  id            String   @id @default(uuid()) @db.Uuid
  outlet_id     String   @db.Uuid
  name          String   @db.VarChar(100)
  unit          String   @db.VarChar(20)
  stock_qty     Int      @default(0)
  reorder_level Int      @default(100)
  cost_per_unit Int      @default(0)
  updated_at    DateTime @updatedAt @db.Timestamptz()

  outlet    Outlet              @relation(fields: [outlet_id], references: [id], onDelete: Cascade)
  recipes   ProductRecipe[]
  movements InventoryMovement[]

  @@unique([outlet_id, name])
  @@map("ingredients")
}

model ProductRecipe {
  id            String @id @default(uuid()) @db.Uuid
  product_id    String @db.Uuid
  ingredient_id String @db.Uuid
  amount_needed Int

  product    Product    @relation(fields: [product_id], references: [id], onDelete: Cascade)
  ingredient Ingredient @relation(fields: [ingredient_id], references: [id], onDelete: Cascade)

  @@unique([product_id, ingredient_id])
  @@map("product_recipes")
}

model InventoryMovement {
  id             String       @id @default(uuid()) @db.Uuid
  outlet_id      String       @db.Uuid
  ingredient_id  String       @db.Uuid
  movement_type  MovementType
  quantity_delta Int
  quantity_after Int
  transaction_id String?      @db.Uuid
  note           String?      @db.VarChar(255)
  created_by     String       @db.Uuid
  created_at     DateTime     @default(now()) @db.Timestamptz()

  ingredient  Ingredient   @relation(fields: [ingredient_id], references: [id], onDelete: Cascade)
  transaction Transaction? @relation(fields: [transaction_id], references: [id])
  creator     User         @relation(fields: [created_by], references: [id])

  @@index([outlet_id, ingredient_id, created_at])
  @@map("inventory_movements")
}

// ==========================================
// MODUL 2 & 3: TRANSAKSI POS & BLOCKCHAIN
// ==========================================

model Transaction {
  id                String        @id @default(uuid()) @db.Uuid
  receipt_no        String        @unique @db.VarChar(30)
  outlet_id         String        @db.Uuid
  cashier_id        String        @db.Uuid
  client_request_id String        @unique @db.Uuid
  subtotal_idr      Int
  discount_idr      Int           @default(0)
  total_idr         Int
  payment_method    PaymentMethod
  paid_idr          Int
  change_idr        Int           @default(0)
  status            TxnStatus     @default(completed)
  created_at        DateTime      @default(now()) @db.Timestamptz()

  outlet             Outlet              @relation(fields: [outlet_id], references: [id])
  cashier            User                @relation(fields: [cashier_id], references: [id])
  items              TransactionItem[]
  movements          InventoryMovement[]
  blockchain_records BlockchainRecord[]

  @@index([outlet_id, created_at])
  @@map("transactions")
}

model TransactionItem {
  id                    String @id @default(uuid()) @db.Uuid
  transaction_id        String @db.Uuid
  product_id            String @db.Uuid
  product_name_snapshot String @db.VarChar(120)
  unit_price_idr        Int
  unit_cost_idr         Int?
  quantity              Int
  line_total_idr        Int

  transaction Transaction @relation(fields: [transaction_id], references: [id], onDelete: Cascade)
  product     Product     @relation(fields: [product_id], references: [id])

  @@map("transaction_items")
}

model BlockchainRecord {
  id                String   @id @default(uuid()) @db.Uuid
  outlet_id         String   @db.Uuid
  block_index       Int
  event_id          String?  @unique @db.VarChar(120)
  event_type        String   @default("sale") @db.VarChar(40)
  transaction_id    String?  @db.Uuid
  event_data        Json?
  data_hash         String   @db.Char(64)
  prev_hash         String   @db.Char(64)
  block_hash        String   @db.Char(64)
  backup_event_data Json?
  backup_data_hash  String?  @db.Char(64)
  backup_prev_hash  String?  @db.Char(64)
  backup_block_hash String?  @db.Char(64)
  created_at        DateTime @default(now()) @db.Timestamptz()

  outlet      Outlet       @relation(fields: [outlet_id], references: [id])
  transaction Transaction? @relation(fields: [transaction_id], references: [id], onDelete: SetNull)

  @@unique([outlet_id, block_index])
  @@index([outlet_id, created_at])
  @@map("blockchain_records")
}

model Notification {
  id         String   @id @default(uuid()) @db.Uuid
  user_id    String   @db.Uuid
  type       String   @db.VarChar(40)
  title      String   @db.VarChar(150)
  body       String   @db.Text
  is_read    Boolean  @default(false)
  dedup_key  String?  @db.VarChar(160)
  created_at DateTime @default(now()) @db.Timestamptz()

  user User @relation(fields: [user_id], references: [id], onDelete: Cascade)

  @@unique([user_id, dedup_key])
  @@index([user_id, created_at])
  @@map("notifications")
}

model DeviceToken {
  id         String   @id @default(uuid()) @db.Uuid
  user_id    String   @db.Uuid
  token      String   @unique @db.Text
  platform   String   @default("android") @db.VarChar(20)
  created_at DateTime @default(now()) @db.Timestamptz()
  updated_at DateTime @updatedAt @db.Timestamptz()

  user User @relation(fields: [user_id], references: [id], onDelete: Cascade)

  @@index([user_id])
  @@map("device_tokens")
}

// ==========================================
// MODUL 5: AI, GAME & REFRESH TOKENS
// ==========================================

model AiChatLog {
  id          String   @id @default(uuid()) @db.Uuid
  user_id     String   @db.Uuid
  question    String   @db.Text
  answer_json Json
  facts_used  Json
  created_at  DateTime @default(now()) @db.Timestamptz()

  user User @relation(fields: [user_id], references: [id], onDelete: Cascade)

  @@map("ai_chat_logs")
}

model GameSession {
  id              String   @id @default(uuid()) @db.Uuid
  user_id         String   @db.Uuid
  mode            GameMode
  score           Int
  correct_count   Int
  total_questions Int      @default(5)
  duration_sec    Int
  played_at       DateTime @default(now()) @db.Timestamptz()

  user User @relation(fields: [user_id], references: [id], onDelete: Cascade)

  @@index([user_id, score(sort: Desc)])
  @@map("game_sessions")
}

model RefreshToken {
  id          String    @id @default(uuid()) @db.Uuid
  user_id     String    @db.Uuid
  token_hash  String    @unique @db.VarChar(64)
  family_id   String    @db.Uuid
  expires_at  DateTime  @db.Timestamptz()
  revoked_at  DateTime? @db.Timestamptz()
  replaced_by String?   @db.VarChar(64)
  created_at  DateTime  @default(now()) @db.Timestamptz()

  user User @relation(fields: [user_id], references: [id], onDelete: Cascade)

  @@index([family_id])
  @@map("refresh_tokens")
}
```

---

### 5.2 Skema DDL SQLite Lokal Flutter (`lib/core/storage/local_db.dart` — 7 Tabel)

```sql
-- 1. Sesi Pengguna, Status Biometrik & Preferensi
CREATE TABLE IF NOT EXISTS local_session_settings (
  user_id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT NOT NULL,
  role TEXT NOT NULL,
  avatar_url TEXT,
  biometric_enabled INTEGER DEFAULT 0,
  display_currency TEXT DEFAULT 'IDR',
  display_timezone TEXT DEFAULT 'WIB',
  shake_sensor_enabled INTEGER DEFAULT 1,
  tilt_sensor_enabled INTEGER DEFAULT 1,
  user_json TEXT,
  access_token TEXT,
  refresh_token TEXT
);

-- 2. Kategori Produk Cache
CREATE TABLE IF NOT EXISTS cached_categories (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  product_count INTEGER DEFAULT 0,
  updated_at TEXT NOT NULL
);

-- 3. Detail Menu & Estimasi Porsi Cache
CREATE TABLE IF NOT EXISTS cached_products (
  id TEXT PRIMARY KEY,
  category_id TEXT,
  category_name TEXT,
  sku TEXT NOT NULL,
  name TEXT NOT NULL,
  unit TEXT DEFAULT 'pcs',
  price_idr INTEGER NOT NULL,
  cost_idr INTEGER,
  image_url TEXT,
  is_active INTEGER DEFAULT 1,
  estimated_portions INTEGER DEFAULT 0,
  stock_quantity INTEGER DEFAULT 0,
  raw_json TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

-- 4. Backup Snapshot Produk per Cabang
CREATE TABLE IF NOT EXISTS backup_products (
  product_id TEXT,
  outlet_id TEXT,
  sku TEXT NOT NULL,
  name TEXT NOT NULL,
  image_url TEXT,
  category_name TEXT,
  price_idr INTEGER NOT NULL,
  estimated_portions INTEGER NOT NULL,
  last_sync_at TEXT NOT NULL,
  PRIMARY KEY (product_id, outlet_id)
);

-- 5. Antrean Transaksi Kasir Offline (Pending Sync Queue)
CREATE TABLE IF NOT EXISTS offline_transactions (
  id TEXT PRIMARY KEY,
  client_request_id TEXT NOT NULL UNIQUE,
  outlet_id TEXT NOT NULL,
  cashier_name TEXT,
  payment_method TEXT NOT NULL,
  paid_idr INTEGER NOT NULL,
  discount_idr INTEGER DEFAULT 0,
  subtotal_idr INTEGER NOT NULL,
  total_idr INTEGER NOT NULL,
  change_idr INTEGER DEFAULT 0,
  items_json TEXT NOT NULL,
  receipt_no TEXT NOT NULL,
  created_at TEXT NOT NULL,
  is_synced INTEGER DEFAULT 0,
  sync_error TEXT
);

-- 6. Backup 50 Struk Terakhir (Receipt History & Hash)
CREATE TABLE IF NOT EXISTS backup_transactions (
  transaction_id TEXT PRIMARY KEY,
  receipt_no TEXT NOT NULL,
  outlet_name TEXT NOT NULL,
  total_idr INTEGER NOT NULL,
  payment_method TEXT NOT NULL,
  data_hash TEXT,
  block_hash TEXT,
  status TEXT DEFAULT 'completed',
  raw_json TEXT,
  created_at TEXT NOT NULL
);

-- 7. Cache Analitik Harian (Daily Offline Fallback)
CREATE TABLE IF NOT EXISTS daily_analytics_cache (
  cache_key TEXT PRIMARY KEY,
  payload TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
```

---

## 6. Katalog API & Konvensi REST Web Service

### 6.1 Format Envelope Respon Seragam

Semua response API Express mengikuti format envelope standar:

**Respon Sukses (HTTP 200 / 201):**
```json
{
  "data": { ... },
  "meta": {
    "page": 1,
    "page_size": 20,
    "total": 42
  }
}
```

**Respon Error (HTTP 4xx / 5xx):**
```json
{
  "error": {
    "code": "INSUFFICIENT_STOCK",
    "message": "Stok bahan Biji Kopi Espresso tidak mencukupi untuk pesanan ini.",
    "details": { ... },
    "request_id": "c92a188e-4f01-443b-85d7-6e4d41fa34c2"
  }
}
```

---

### 6.2 Katalog Endpoint per Modul (Aktual Codebase)

#### MOD-1: Autentikasi, Pengguna & Profil
* `POST /api/auth/login` — Autentikasi email & password, mengembalikan access token JWT & refresh token.
* `POST /api/auth/refresh` — Rotasi refresh token dan penerbitan access token baru.
* `POST /api/auth/logout` — Pemutusan sesi dan pembatalan token di DB & storage.
* `GET /api/auth/me` — Profil user saat ini dan status feature flags.
* `PATCH /api/auth/me` — Memperbarui data profil user aktif saat ini.
* `POST /api/auth/change-password` — Mengubah password user saat ini.
* `GET /api/users` — [Owner, Manager] Daftar user (Manager otomatis tersaring hanya untuk kasir cabang sendiri).
* `POST /api/users` — [Owner, Manager] Mendaftarkan user baru (Manager dibatasi hanya dapat membuat staf di cabangnya).
* `PATCH /api/users/:id` — [Owner, Manager] Memperbarui user (Manager dibatasi hanya dapat mengedit staf cabangnya).
* `GET /api/users/me/settings` — Mengambil preferensi user (currency, timezone, sensor, biometric).
* `PATCH /api/users/me/settings` — Memperbarui preferensi user di memori server dan kolom `display_currency`.
* `POST /api/feedback` — Mengirimkan form kesan & saran PAM.
* `GET /api/feedback` — [Owner, Manager] Melihat daftar kesan & saran PAM.
* `GET /api/health` — Status kesehatan database Supabase dan server Express.

#### MOD-2: Operasional (Katalog Menu, Resep, Bahan Baku & POS)
* `GET /api/categories` — Mengambil daftar kategori menu produk.
* `POST /api/categories` — [Owner only] Membuat kategori produk baru.
* `PATCH /api/categories/:id` — [Owner only] Memperbarui nama kategori produk.
* `GET /api/products` — Daftar menu aktif beserta kalkulasi `estimated_portions` dinamis dari stok cabang terkait (`outlet_id`, `category_id`, `q`, `sort`, `page`).
* `POST /api/products` — [Owner only] Menambah menu baru beserta resep `recipes: [{ ingredient_id, amount_needed }]`.
* `GET /api/products/:id` — Detail menu beserta komposisi takaran bahan bakunya.
* `PUT /api/products/:id` & `PATCH /api/products/:id` — [Owner only] Memperbarui detail menu, harga, atau komposisi resep.
* `DELETE /api/products/:id` — [Owner only] Menonaktifkan menu jualan (`is_active = false`).
* `GET /api/inventory/ingredients` — [Owner, Manager] Daftar bahan baku cabang (filter `outlet_id`, `status=ok|low|out`, `q`).
* `GET /api/inventory/stocks` — [Owner, Manager] Alias kompatibilitas backward daftar bahan baku cabang.
* `POST /api/inventory/ingredients` — [Owner, Manager] Menambah bahan baku baru di cabang tertentu.
* `PUT /api/inventory/ingredients/:id` & `PATCH /api/inventory/ingredients/:id` — [Owner, Manager] Memperbarui bahan baku.
* `DELETE /api/inventory/ingredients/:id` — [Owner, Manager] Menghapus bahan baku dari cabang.
* `POST /api/inventory/adjustments` — [Owner, Manager] Mencatat restock, koreksi opname, atau waste atomik ke `inventory_movements`.
* `GET /api/inventory/movements` — [Owner, Manager] Riwayat audit mutasi keluar-masuk kartu stok bahan baku.
* `POST /api/transactions` — Membuat transaksi penjualan POS atomik berbasis resep.
* `GET /api/transactions` — Riwayat transaksi penjualan POS (filter `outlet_id`, `status`, `receipt_no`, pagination).
* `GET /api/transactions/:id` — Detail struk transaksi spesifik.
* `POST /api/transactions/:id/void` — [Owner, Manager] Membatalkan transaksi, mengembalikan stok bahan baku (`void_return`), dan mencetak blok void di blockchain.
* `GET /api/pos/catalog` — Endpoint alternatif katalog kasir dengan ketersediaan stok & `max_portions`.
* `POST /api/pos/checkout` — Endpoint alternatif eksekusi checkout atomik POS.
* `POST /api/pos/void` — Endpoint alternatif pembatalan transaksi kasir POS.
* `GET /api/search?q=` — Pencarian global lintas produk dan cabang toko.

#### MOD-3: Integritas Blockchain, Web3 & Notifikasi Mobile
* `GET /api/integrity/blockchain/chain/:outletId` — [Owner, Manager] Visualisasi rantai blok transaksi cabang terkait.
* `GET /api/integrity/blockchain/verify/:outletId` — [Owner, Manager] Validasi keutuhan dan integritas kriptografis rantai blok cabang.
* `POST /api/integrity/blockchain/simulate-tamper` — Simulasi manipulasi data transaksi untuk demonstrasi status TAMPERED.
* `POST /api/integrity/blockchain/recover` — Pemulihan blok yang rusak menggunakan snapshot cadangan valid.
* `GET /api/integrity/web3/public-verify/:receiptNo` — Verifikasi publik bukti transaksi di blockchain Ethereum Sepolia (tanpa login).
* `GET /api/integrity/web3/status` — Status koneksi node Web3 Ethereum Sepolia.
* `GET /api/integrity/web3/verify/:receiptNo` — Verifikasi bukti transaksi Web3 untuk pengguna terautentikasi.
* `POST /api/integrity/web3/anchor` — [Owner, Manager] Menjangkarkan hash transaksi aktif ke smart contract Sepolia.
* `GET /api/notifications` — Mengambil daftar notifikasi pengguna dan menghitung total unread count.
* `PATCH /api/notifications/:id/read` — Menandai satu notifikasi telah dibaca.
* `POST /api/notifications/read-all` — Menandai semua notifikasi pengguna telah dibaca.
* `POST /api/notifications/evaluate` — Evaluasi batch pemicu notifikasi stok kritis otomatis.
* `POST /api/notifications/device-token` — Registrasi token FCM perangkat mobile ke tabel `device_tokens`.

#### MOD-4: Dashboard Analitik, Forecasting AI, Sensor & LBS
* `GET /api/analytics/overview` — [Owner, Manager] KPI total omzet, transaksi, ATV, margin kotor, dan pertumbuhan.
* `GET /api/analytics/sales-trend` — [Owner, Manager] Data grafik tren penjualan harian (`daily`, `weekly`, `monthly`).
* `GET /api/analytics/peak-hours` — [Owner, Manager] Distribusi jam-jam paling ramai transaksi kasir.
* `GET /api/analytics/shift-summary` — [Staff, Manager] Ringkasan shift kasir hari berjalan (uang masuk & transaksi).
* `GET /api/analytics/forecast/sales` — [Owner, Manager] AI Time Series Sales Forecasting (proyeksi 7–30 hari ke depan).
* `GET /api/analytics/forecast/stockout` — [Owner, Manager] AI Stock Runout & Velocity Prediction (proyeksi hari kehabisan bahan baku).
* `GET /api/analytics/leaderboard` — [Owner, Manager] Peringkat menu jualan terlaris berdasarkan transaksi database.
* `GET /api/outlets` — Daftar cabang beserta koordinat latitude/longitude dan zona waktu.
* `GET /api/outlets/:id` — Detail informasi cabang spesifik.
* `POST /api/outlets` — [Owner only] Menambah cabang baru.
* `PATCH /api/outlets/:id` — [Owner only] Memperbarui data cabang toko.
* `DELETE /api/outlets/:id` — [Owner only] Menonaktifkan cabang toko (*soft delete*).
* `GET /api/outlets/nearest` — Menghitung cabang terdekat berdasarkan koordinat GPS pengguna (Haversine Formula).
* `GET /api/outlets/performance` — [Owner, Manager] Metrik performa penjualan untuk pewarnaan peta cabang LBS.
* `GET /api/fx/rates` — Kurs mata uang terbaru (IDR, USD, EUR) dari Frankfurter API via in-memory cache backend.
* `GET /api/fx/convert` — Endpoint utilitas konversi nominal mata uang secara on-the-fly.

#### MOD-5: Kecerdasan Buatan (AI Copilot & Voice), DSS & Mini Game
* `GET /api/insights` — [Owner, Manager] Evaluasi real-time (*on-the-fly*) mesin aturan bisnis R1 (`LOW_STOCK`), R2 (`RESTOCK_URGENT`), dan R4 (`SLOW_MOVING`).
* `POST /api/insights/generate` — [Owner, Manager] Evaluasi manual on-demand seluruh rule engine.
* `PATCH /api/insights/:id/status` — [Owner, Manager] Memperbarui status rekomendasi insight (`acknowledged` atau `dismissed`).
* `POST /api/ai/chat` — [Owner, Manager] Tanya jawab bisnis cerdas ke Gemini LLM grounded pada fakta database nyata (format: Ringkasan, Analisis, Rekomendasi, dan tag `[VOICE_SUMMARY]`).
* `POST /api/ai/tts` — [Owner, Manager] Sintesis teks ke audio MP3 suara wanita natural menggunakan **Microsoft Edge TTS (`id-ID-GadisNeural`)** dalam format Base64.
* `POST /api/ai/recommend-price` — [Owner, Manager] Rekomendasi harga jual AI untuk menu baru berbasis HPP live dan margin.
* `GET /api/ai/conversations` — Riwayat percakapan chat AI.
* `GET /api/ai/conversations/:id/messages` — Detail riwayat percakapan spesifik.
* `GET /api/game/questions` — Membangkitkan 5 soal kuis mini-game *"Guess the Menu"* secara dinamis dari produk (Mode `guess_name` & `guess_price`).
* `POST /api/game/sessions` — Mengirimkan hasil jawaban kuis tebak menu/harga dan menyimpan skor ke `game_sessions`.
* `GET /api/game/sessions/me` — Riwayat skor permainan dan statistik capaian user.
* `GET /api/game/scenarios` — Skenario tantangan keputusan operasional bisnis toko.

---

## 7. Aturan Keamanan (Security Requirements)

1. **Penyimpanan Token:** Token autentikasi JWT wajib disimpan menggunakan `flutter_secure_storage` pada platform mobile (menggunakan Android Keystore / iOS Keychain). Dilarang keras menyimpan token pada `SharedPreferences` biasa.
2. **Kueri Terparameter:** Seluruh interaksi database wajib menggunakan Prisma ORM atau parameterized query. Dilarang menggabungkan string mentah (*raw string concatenation*) untuk mencegah celah SQL Injection.
3. **Rahasia Sistem (Secrets):** Kunci rahasia JWT, API Key Gemini, dan connection string Supabase hanya berada di file backend `.env`. Aplikasi Flutter tidak boleh menyimpan rahasia backend di source code.
4. **Sanitasi Log:** Dilarang mencetak password plaintext atau refresh token pada log server (Pino logger).
5. **Rate Limiting:**
   * Login endpoint: Max 5 percobaan / 15 menit per IP (HTTP 423 Locked).
   * AI Assistant: Max 10 request / menit dan 100 request / hari per user.
   * General API: Max 100 request / 15 menit per IP.

---

## 8. Panduan Pre-Production & Setup

### 8.1 File Konfigurasi Environment (`api/.env`)
```env
NODE_ENV=development
PORT=3000
DATABASE_URL="postgresql://postgres.xxx:pass@aws-0-ap-southeast-1.pooler.supabase.com:6543/postgres?pgbouncer=true"
DIRECT_URL="postgresql://postgres.xxx:pass@aws-0-ap-southeast-1.pooler.supabase.com:5432/postgres"
JWT_ACCESS_SECRET=arus_jwt_secret_dev_key_super_secure_32_chars_min
JWT_ACCESS_TTL_SEC=900
REFRESH_TTL_DAYS=7
LLM_PROVIDER=gemini
LLM_API_KEY=AIzaSyYourGeminiApiKeyHere
LLM_MODEL=gemini-2.0-flash
AI_RATE_PER_MIN=10
AI_RATE_PER_DAY=100
FX_API_URL=https://api.frankfurter.dev/v1/latest
FEATURE_INTEGRITY=true
FEATURE_NOTIFICATIONS=true
FEATURE_FX=true
FEATURE_GAME=true
FEATURE_AI=true
LOG_LEVEL=info

# Firebase Cloud Messaging (Opsional)
FIREBASE_PROJECT_ID=
FIREBASE_CLIENT_EMAIL=
FIREBASE_PRIVATE_KEY=

# Web3 Ethereum Sepolia Blockchain (Public Ledger Anchor)
SMART_CONTRACT_ADDRESS="0x910d935f00922A340889Abf8221Db30c03CEE3C1"
SEPOLIA_RPC_URL="https://ethereum-sepolia-rpc.publicnode.com"
SEPOLIA_PRIVATE_KEY=""
```

### 8.2 Konfigurasi Client Mobile Flutter (`lib/core/config/env.dart`)
Aplikasi mobile Flutter dikonfigurasikan secara default untuk terhubung ke Cloud Production Web Service resmi atau local server via argument `--dart-define`:
* **Default Production Cloud URL:** `https://arus-lime.vercel.app/api`
* **Local Development (Emulator Android):** `http://10.0.2.2:3000/api` (atau port 5000)
* **Local Development (Desktop/Web):** `http://localhost:3000/api`
* Perintah eksekusi kustom:
  ```bash
  flutter run --dart-define=API_BASE_URL=http://localhost:3000/api --dart-define=APP_ENV=dev
  ```

### 8.3 Inisialisasi Database & Seeding
```bash
cd api
npm install
npx prisma generate
npx prisma db push
npm run db:seed
```

---

## 9. Aturan Production & Hard Forbids

Setiap pengembang wajib mematuhi **15 Larangan Keras (Hard Forbids)** berikut:

1. **[F1]** DILARANG mengakses database online langsung dari Flutter (wajib melalui REST API Express).
2. **[F2]** DILARANG menaruh logika bisnis berat pada widget UI Flutter.
3. **[F3]** DILARANG menggunakan tipe data `any` (TypeScript) atau `dynamic` (Dart) tanpa penjelasan komentar.
4. **[F4]** DILARANG melakukan cross-feature import antar fitur Flutter kecuali melalui `core/` dan `shared/`.
5. **[F5]** DILARANG mengubah formula hash blockchain atau format canonical JSON yang sudah berjalan.
6. **[F6]** DILARANG mengedit manual file migrasi Prisma yang sudah diaplikasikan di database.
7. **[F7]** DILARANG membocorkan secret/kunci API ke dalam git repository publik.
8. **[F8]** DILARANG menyimpan token sesi di `SharedPreferences` biasa.
9. **[F9]** DILARANG menampilkan stack trace exception mentah ke hadapan pengguna aplikasi.
10. **[F10]** DILARANG memanggil sensor atau GPS langsung dari fungsi `build()` Flutter.
11. **[F11]** DILARANG menggunakan perhitungan floating-point untuk nilai mata uang rupiah.
12. **[F12]** DILARANG menambah dependensi package baru tanpa justifikasi tertulis.
13. **[F13]** DILARANG mengubah keputusan arsitektur secara diam-diam tanpa memperbarui SRS ini.
14. **[F14]** DILARANG menjalankan query SQL mentah dinamis yang digenerate oleh AI LLM.
15. **[F15]** DILARANG melakukan *hard delete* pada tabel transaksi, pergerakan stok, dan rekam blockchain.

---

## 10. Panduan Post-Production, Cron & Maintenance

### 10.1 Tugas Terjadwal & Background Tasks
1. **FX Rate In-Memory Sync:** Memperbarui cache nilai tukar mata uang dari Frankfurter API secara berkala.
2. **Notification & Token Maintenance:** Pembersihan token refresh kedaluwarsa serta deduplikasi notifikasi otomatis.
3. **Daily Blockchain Settlement:** Penutupan blok harian (*Close Day*) untuk mengemas transaksi hari aktif ke dalam *Parent Daily Block*.

### 10.2 Skrip Demo & Testing
* `npm test` — Menjalankan seluruh test suite Vitest di backend.
* `npm run test:blockchain` — Menguji keandalan enkripsi SHA-256 dan rantai hash blockchain internal.
* `npm run test:web3` — Menguji penjangkaran dan verifikasi smart contract publik Ethereum Sepolia.
* `flutter test` — Menjalankan pengujian widget, Riverpod provider, offline sync, dan alur aplikasi mobile.

---

## 11. Panduan UI/UX & Standar Widget Mobile

* **Material Design 3 & Shadcn UI:** Menggunakan token tema terpadu dari `lib/core/theme/app_theme.dart`.
* **State Management:** Setiap layar yang mengambil data online wajib menggunakan widget pembungkus `AsyncStateView` dengan 4 penanganan state: *Loading Skeleton*, *Success View*, *Empty State*, dan *Error State*.
* **Target Layar Mobile HP Portrait (360 dp):**
  - Seluruh layout dioptimalkan untuk layar ponsel genggam portrait (lebar standar 360–412 dp).
  - Teks dinamis wajib diberi batasan `maxLines` dan `overflow: TextOverflow.ellipsis` untuk mencegah kebocoran tata letak (*RenderFlex overflowed*).
  - Elemen scrollable bersarang dilarang keras tanpa pembungkus ukuran pasti (`Expanded` atau tinggi fixed).
* **Format Mata Uang:** Menampilkan uang selalu melalui utilitas `MoneyFormatter.format(amount)` yang mendukung IDR, USD, dan EUR.
* **Ukuran Target Sentuh:** Tombol navigasi dan aksi kasir memiliki ukuran target sentuh minimal **48 x 48 dp** dengan ukuran font teks minimal **14 sp**.
* **Konfirmasi Aksi Destruktif:** Aksi seperti *Void Transaksi*, *Logout*, dan *Penonaktifan Cabang* wajib memunculkan dialog konfirmasi (*Confirmation Modal*).

---

## 12. Feature Flags & Degradasi Fitur

Aplikasi mendukung *graceful degradation* melalui environment variable di backend yang dikirimkan ke aplikasi saat startup (`GET /api/auth/me`):

| Nama Flag | Kontrol Fitur | Respon Jika Dinonaktifkan (`false`) |
|---|---|---|
| `FEATURE_INTEGRITY` | Rantai Hash Blockchain | Transaksi POS tetap berjalan; menu audit disembunyikan |
| `FEATURE_NOTIFICATIONS` | Notifikasi Stok Menipis | Server tidak memicu trigger notifikasi; lonceng disembunyikan |
| `FEATURE_FX` | Konversi Multi-Currency | Nilai mata uang terkunci ke IDR; pemilih kurs disembunyikan |
| `FEATURE_GAME` | Mini Game Tantangan Bisnis | Menu game disembunyikan dari navigasi |
| `FEATURE_AI` | Chatbot Bisnis Gemini | Jawaban dialihkan ke fallback aturan lokal deterministik |

---

## 13. Konvensi Kode & Struktur Direktori Monorepo

### 13.1 Standar Penamaan
* **Dart (Flutter):**
  * File & Direktori: `snake_case` (contoh: `pos_screen.dart`, `pos_provider.dart`)
  * Kelas & Enums: `PascalCase` (contoh: `TransactionRepository`, `StockStatus`)
  * Riverpod Providers: `camelCase` diakhiri Provider (contoh: `outletsListProvider`)
* **TypeScript (Express):**
  * File & Direktori: `kebab-case` (contoh: `transactions.service.ts`)
  * Fungsi & Variabel: `camelCase` (contoh: `calculateTotalRevenue`)
  * Tabel & Kolom Database: `snake_case` (contoh: `transaction_items`, `unit_price_idr`)

### 13.2 Struktur Folder Monorepo
```text
arus/
├── lib/                           # Proyek Flutter Mobile
│   ├── core/                      # Network, storage, routing, theme, auth, sync, push, utilitas
│   ├── shared/                    # Widget global (AsyncStateView, EmptyState, AppWidgets)
│   └── features/                  # UI & State per fitur (auth, pos, dashboard, catalog, ai, game, outlets, dll)
├── test/                          # Unit & Widget Test Flutter
│
├── api/                           # Proyek Express.js REST API
│   ├── src/
│   │   ├── config/                # Environment, Database (Prisma), Logger
│   │   ├── middleware/            # Auth, RBAC, Validator, Rate Limit
│   │   ├── modules/               # Controller, Service, & Route per domain
│   │   └── shared/                # Utilitas hash SHA-256, canonical JSON, error handler
│   ├── prisma/                    # Skema database (schema.prisma) & seeder
│   └── tests/                     # Unit & Integration Test API (Vitest)
└── arus_srs_v3.md                 # Master Dokumen Acuan Tunggal (v3.0 As-Is)
```

---

## 14. Strategi Pengujian & Skenario Demo

### 14.1 Matriks Uji Inti (Core Test Matrix)

| Kode Uji | Skenario yang Diuji | Hasil yang Diharapkan |
|---|---|---|
| **T-AUTH-01** | Login dengan email & password valid | Berhasil 200 OK, menerima token JWT dan role pengguna |
| **T-AUTH-03** | Percobaan login salah 5x berturut-turut | Akun terkunci sementara, request berikutnya menghasilkan HTTP 423 |
| **T-AUTH-07** | Buka kunci aplikasi dengan sidik jari (biometrik) | Berhasil masuk ke Beranda tanpa meminta input password |
| **T-CAT-01** | Input produk dengan kode SKU yang sudah ada | Ditolak dengan respon HTTP 409 `CATALOG_SKU_DUPLICATE` |
| **T-INV-02** | Dua kasir menjual barang sisa 1 secara bersamaan | 1 transaksi berhasil, 1 transaksi ditolak `INSUFFICIENT_STOCK` |
| **T-POS-01** | Input penjualan kasir tunai dengan uang cukup | Berhasil 201 Created, stok terpotong, struk tercatat |
| **T-POS-03** | Transaksi kasir offline saat jaringan terputus | Transaksi tersimpan di SQLite lokal dan berhasil disinkronkan saat online |
| **T-POS-05** | Void transaksi oleh Manager dalam 24 jam | Transaksi dibatalkan, stok dikembalikan, tercatat blok void |
| **T-INT-01** | Verifikasi keaslian rantai transaksi | Menghasilkan status **VALID** dengan kecocokan hash SHA-256 |
| **T-INT-03** | Verifikasi rantai setelah payload database diubah | Menghasilkan status **TAMPERED** dan pulih via snapshot cadangan |
| **T-NOT-01** | Transaksi kasir membuat sisa stok $\leq$ reorder level | Muncul peringatan stok menipis di kotak masuk notifikasi |
| **T-CUR-01** | Mengubah pilihan mata uang ke USD di dashboard | Nilai rupiah terkonversi akurat sesuai kurs realtime Frankfurter |
| **T-TZ-01** | Melihat jam transaksi pada cabang London | Timestamp terkonversi otomatis ke jam lokal London (BST) |
| **T-SEN-01** | Menggoyangkan HP di Dashboard (*Accelerometer*) | Dashboard memuat ulang data analitik terbaru dari server |
| **T-SEN-03** | Menguji sensor Giroskop (*Tilt Orientation*) | Terdeteksi sudut kemiringan Pitch, Roll, dan Yaw secara real-time |
| **T-LBS-01** | Membuka fitur lokasi cabang terdekat | Menghitung jarak km dari posisi GPS user via Haversine Formula |
| **T-AI-01** | Mengajukan pertanyaan kondisi penjualan ke AI | AI menjawab dengan narasi ramah berstruktur dan tag `[VOICE_SUMMARY]` |
| **T-AI-02** | Percakapan ARUS Voice Mode | Suara dibacakan secara audio via Edge TTS `id-ID-GadisNeural` |
| **T-GAME-01**| Menyelesaikan kuis tebak menu/harga ("Guess the Menu") | Skor tersimpan di tabel `game_sessions` dan muncul di riwayat game |

---

## 15. Pembagian Tugas Tim & Requirement Traceability Matrix

### 15.1 Pembagian Tanggung Jawab Tim (Sesuai `MASTER_UNDERSTAND.md`)

* **Orang 1 — Architect, Security, Backend Web Service & Blockchain:**
  * Skema Prisma PostgreSQL (17 model) & Seeding data multi-outlet.
  * Autentikasi JWT (`argon2id`), Refresh Token Rotation, RBAC, dan Outlet Scoping.
  * API Katalog Menu, Bahan Baku Cabang, Mutasi Stok, dan Transaksi Kasir POS atomik di backend.
  * Implementasi **Dual-Layer & Persistent Blockchain SHA-256**, endpoint audit/pemulihan, serta Web3 Sepolia anchor service.
  * Kueri agregasi untuk **Dashboard Analitik KPI, Peak Hours, dan Sales Trend**.

* **Orang 2 — Mobile Client, SQLite Lokal, Offline-First & Utilitas:**
  * Kerangka navigasi multi-role (Bottom Navigation 4 Tab + Global AI FAB).
  * Layar Login & integrasi **Biometric Unlock (`local_auth`)** via Android Keystore.
  * Layar Profil bergambar, **Form Kesan/Saran Matkul PAM**, dan Tentang Aplikasi.
  * Layar Mesin Kasir POS & keranjang belanja interaktif.
  * Sinkronisasi **Offline POS Queue & Backup SQLite (`sqflite`, 7 Tabel)** via `sync_service.dart`.
  * Widget **Konversi Mata Uang (IDR/USD/EUR)** & **Zona Waktu Multi-Timezone**.
  * Modul **In-App Notification Center** & registrasi DeviceToken.

* **Orang 3 — Smart Features, Hardware Sensors, AI Copilot & Mini Game:**
  * Deteksi sensor **Accelerometer (Shake)** & **Gyroscope (Tilt)** via `sensors_plus`.
  * Layar **Manajemen Cabang & LBS** dengan kalkulasi jarak GPS terdekat (*Haversine Formula*).
  * Integrasi **ARUS AI Business Assistant** dengan Google Gemini API & Grounded Facts.
  * Implementasi **ARUS Voice Mode (Edge TTS `id-ID-GadisNeural` + STT Push-to-Talk)** dan Rekomendasi Harga Jual AI.
  * Mesin aturan **Decision Support (Insights)** evaluasi *on-the-fly*.
  * Desain antarmuka & generator soal **Mini Game (*Guess the Menu*)** dinamis dari tabel `products`, kontrol sensor giroskop 2-arah, dan efek audio prosedural `SynthAudioService`.

---

### 15.2 Requirement Traceability Matrix (Pemetaan 27 Fitur & Fitur Inovatif)

| No | Nama Fitur | Modul | Berkas Implementasi Utama | Kriteria Dosen PAM | PIC Utama | Kode Uji |
|:---:|---|:---:|---|---|:---:|:---:|
| 1 | Login Enkripsi Password | MOD-1 | `auth.service.ts` · `login_screen.dart` | Login Enkripsi Non-Firebase | Orang 1 | T-AUTH-01 |
| 2 | Sesi JWT & SQLite | MOD-1 | `auth.service.ts` · `secure_store.dart` · `local_db.dart` | Manajemen Sesi Aplikasi | Orang 1 | T-AUTH-04 |
| 3 | Login Biometrik Keystore | MOD-1 | `biometric_service.dart` · `splash_screen.dart` | Login Sensor Biometrik | Orang 2 | T-AUTH-07 |
| 4 | Profil Akun Bergambar | MOD-1 | `profile_screen.dart` | Bottom Nav: Profil Bergambar | Orang 2 | T-RBAC-01 |
| 5 | Kesan & Saran Matkul PAM | MOD-1 | `feedback_screen.dart` · `feedback.service.ts` | Bottom Nav: Menu Saran PAM | Orang 3 | T-RBAC-01 |
| 6 | Menu Logout & Revoke | MOD-1 | `auth_notifier.dart` · `auth.service.ts` | Bottom Nav: Menu Logout | Orang 1 | T-AUTH-04 |
| 7 | Manajemen User (RBAC) | MOD-1 | `user_management_screen.dart` · `users.service.ts` | Multi-Role Access Control | Orang 1 | T-RBAC-05 |
| 8 | Master Produk & Resep | MOD-2 | `product_list_screen.dart` · `catalog.service.ts` | API Web Service & Online DB | Orang 2 | T-CAT-01 |
| 9 | Cari & Filter Porsi Dinamis | MOD-2 | `product_list_screen.dart` · `catalog.controller.ts` | Fasilitas Pencarian & Pemilihan | Orang 2 | T-CAT-03 |
| 10 | Backup Offline SQLite (7 Tab) | MOD-2 | `local_db.dart` (`backup_products`, `cached_products`) | Database Lokal SQLite & Online | Orang 2 | T-DB-02 |
| 11 | Filter Status Stok Cabang | MOD-2 | `inventory_list_screen.dart` · `inventory.service.ts` | Fasilitas Pemilihan & Filter | Orang 2 | T-INV-04 |
| 12 | Penyesuaian Stok Atomik | MOD-2 | `inventory_list_screen.dart` · `inventory.service.ts` | Decision Support Inventaris | Orang 1 | T-INV-03 |
| 13 | Kasir Mobile POS Resep | MOD-2 | `pos_screen.dart` · `transactions.service.ts` | Konsep Proyek Akhir (POS) | Orang 1 & 2 | T-POS-01 |
| 14 | Struk & Offline Queue Sync | MOD-2 | `local_db.dart` (`offline_transactions`) · `sync_service.dart` | Database Lokal SQLite (Queue) | Orang 2 | T-POS-03 |
| 15 | Void Transaksi & Balik Stok | MOD-2 | `transactions.service.ts` (`voidTransaction`) | Integritas Data Transaksi | Orang 1 | T-POS-05 |
| 16 | Hash Dual Blockchain & Web3 | MOD-3 | `blockchain.service.ts` · `dual_blockchain.ts` · `web3_anchor.service.ts` | Fitur Blockchain Sederhana | Orang 1 | T-INT-01 |
| 17 | Audit Tamper & Recovery | MOD-3 | `integrity_chain_screen.dart` · `blockchain.service.ts` | Fitur Blockchain Sederhana | Orang 1 | T-INT-03 |
| 18 | Notifikasi Stok Menipis & FCM | MOD-3 | `notification_screen.dart` · `notifications.service.ts` | Notifikasi Mobile Sesuai Konsep | Orang 2 | T-NOT-01 |
| 19 | Dashboard Analitik & Tren | MOD-4 | `dashboard_screen.dart` · `analytics.service.ts` | Business Intelligence & Charts | Orang 3 | T-ANA-01 |
| 20 | Konversi 3 Mata Uang Kurs | MOD-4 | `money_formatter.dart` · `fx.service.ts` | Konversi Min. 3 Mata Uang | Orang 2 | T-CUR-01 |
| 21 | Konversi 4 Zona Waktu | MOD-4 | `timezone_converter.dart` · `time_settings_screen.dart` | Konversi 4 Zona Waktu | Orang 2 | T-TZ-01 |
| 22 | Sensor 1: Accelerometer | MOD-4 | `sensor_provider.dart` (Shake to Refresh) · `dashboard_screen.dart` | Sensor 1: Accelerometer | Orang 3 | T-SEN-01 |
| 23 | Sensor 2: Gyroscope | MOD-4 | `sensor_provider.dart` · `sensor_test_screen.dart` | Sensor 2: Gyroscope | Orang 3 | T-SEN-03 |
| 24 | Peta LBS & Haversine GPS | MOD-4 | `outlet_list_screen.dart` · `outlets.service.ts` | Web Service & Fasilitas LBS | Orang 3 | T-LBS-01 |
| 25 | Decision Support (Insights) | MOD-5 | `insights.service.ts` (Evaluasi On-the-Fly R1, R2, R4) | AI Sesuai Konsep Tema | Orang 3 | T-DS-01 |
| 26 | AI Copilot, Voice TTS & Pricing | MOD-5 | `ai.service.ts` · `tts.service.ts` · `ai_home_screen.dart` | Fitur AI & LLM Sesuai Tema | Orang 3 | T-AI-01 |
| 27 | Mini Game Guess the Menu | MOD-5 | `game_home_screen.dart` · `game.service.ts` · `synth_audio_service.dart` | Mini Game Terkait Konsep | Orang 3 | T-GAME-01 |

---

*Akhir Dokumen — ARUS SRS v3 Master Single Source of Truth.*
