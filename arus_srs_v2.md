# ARUS SRS v2.1 — Software Requirements Specification & Master Blueprint

**Versi:** 2.1 (Living System Architecture — Reverse-Engineered Single Source of Truth)  
**Proyek:** ARUS — Multi-Outlet Mobile Business Intelligence & POS System  
**Mata Kuliah:** Pemrograman Aplikasi Mobile (PAM)  
**Stack Utama:** Flutter (Android/iOS) + Node.js/Express (TypeScript) + PostgreSQL (Supabase) + SQLite (`sqflite`)  
**Repository:** `https://github.com/supremeinori/arus` (branch `main`)  
**Dokumen ini menggantikan secara resmi:** `arus_srs_v2.md`, `ARUS_SRS.md`, `ARUS_DESAIN_ADDER.md`, `arus_modul.md`, dan `Modul_guide.md`.

---

## Daftar Isi

1. [Identitas Produk & Arsitektur Global](#1-identitas-produk--arsitektur-global)
2. [Hak Akses Role & Struktur Navigasi (RBAC)](#2-hak-akses-role--struktur-navigasi-rbac)
3. [Daftar 5 Modul & 27 Fitur Utama](#3-daftar-5-modul--27-fitur-utama)
4. [Business Rules & Batasan Sistem (BR)](#4-business-rules--batasan-sistem-br)
5. [Desain Database Lengkap (PostgreSQL & SQLite)](#5-desain-database-lengkap-postgresql--sqlite)
6. [Katalog API & Konvensi REST Web Service](#6-katalog-api--konvensi-rest-web-service)
7. [Aturan Keamanan (Security Requirements)](#7-aturan-keamanan-security-requirements)
8. [Panduan Pre-Production & Setup](#8-panduan-pre-production--setup)
9. [Aturan Production & Hard Forbids](#9-aturan-production--hard-forbids)
10. [Panduan Post-Production, Cron & Maintenance](#10-panduan-post-production-cron--maintenance)
11. [Panduan UI/UX & Standar Widget Mobile](#11-panduan-uiux--standar-widget-mobile)
12. [Feature Flags & Degradasi Fitur](#12-feature-flags--degradasi-fitur)
13. [Konvensi Kode & Struktur Direktori](#13-konvensi-kode--struktur-direktori)
14. [Strategi Pengujian & Skenario Demo](#14-strategi-pengujian--skenario-demo)
15. [Pembagian Tugas Tim & Traceability Matrix](#15-pembagian-tugas-tim--traceability-matrix)

---

## 1. Identitas Produk & Arsitektur Global

### 1.1 Ringkasan Eksekutif
ARUS adalah sistem operasional kasir (Mobile POS) dan pendukung keputusan bisnis multi-cabang (*Mobile Business Decision-Support System*). Aplikasi mobile dibangun menggunakan **Flutter** yang berkomunikasi secara eksklusif ke **Express.js REST API pribadi** (Node.js/TypeScript) dengan database cloud **PostgreSQL (Supabase)**. Untuk menjamin keandalan saat jaringan terputus maupun saat offline sementara di lapangan, Flutter mengimplementasikan database lokal **SQLite (`sqflite`)** yang mendukung pencadangan katalog, riwayat struk, serta **antrean transaksi kasir offline (*Offline POS Queue*)** yang akan disinkronisasikan otomatis ke server cloud ketika koneksi kembali online.

### 1.2 Diagram Arsitektur Sistem

```text
[ Flutter Mobile App (Android / iOS) ]
   ├── UI Layer: Kasir POS, Dashboard KPI, Peta Cabang, Chat AI, Mini Game, Profil
   ├── State Management: Riverpod (AsyncNotifier / FutureProvider / StateProvider)
   ├── Local DB: SQLite (sqflite) -> Cache Katalog, 50 Struk Terakhir, Sesi & Offline POS Queue
   │
   ├──► (HTTPS REST JSON) ──► [ Express.js Backend API (/api/*) ]
   │                             ├── Middleware: Auth JWT, RBAC, Outlet Scope, Zod Validator, Rate Limit
   │                             ├── Blockchain Engine: Dual-Layer In-Memory & Database Mirror
   │                             └── Prisma ORM ──► [ PostgreSQL Cloud (Supabase) ]
   │
   └──► (Public Web Services)
         ├── Frankfurter API (Kurs Realtime: IDR, USD, EUR)
         ├── OpenStreetMap Services (Koordinat Peta Cabang & LBS)
         └── Google Gemini API (LLM Business Copilot via Backend)
```

### 1.3 Scope Sistem
* **Dalam Scope (In-Scope):** 
  - Autentikasi JWT (argon2id) dengan Refresh Token Family Rotation, Biometric Fingerprint/Face Unlock, Profil + Feedback PAM.
  - Multi-Role & Outlet Scoping (Owner, Manager, Staff).
  - Manajemen Produk & Resep Bahan Baku (`product_recipes`), Manajemen Stok Cabang & Mutasi (`inventory_movements`).
  - Kasir POS Atomik Berbasis Resep, Kalkulasi HPP (*Unit Cost*), dan Dukungan Kasir Offline (*Offline POS Queue Sync*).
  - Integritas Data Kriptografis: **Dual-Layer Blockchain** (*Parent Daily Block* & *Child Transaction Block* dengan *Merkle Root* & *Tamper-evident Audit*).
  - Notifikasi Stok Menipis (In-App Notification Center & Background Dispatcher).
  - Dashboard Analitik KPI, Multi-Currency (IDR/USD/EUR via Frankfurter), Multi-Timezone (WIB/WITA/WIT/London).
  - Sensor Accelerometer (*Shake to Refresh*) & Gyroscope (*Tilt Orientation Test*).
  - LBS Peta Cabang & Kalkulasi Jarak Haversine Formula.
  - Rule-Based Decision Support System (Insights Evaluasi *on-the-fly*).
  - ARUS AI Business Assistant (Gemini LLM grounded facts dengan persona ramah & terstruktur).
  - Mini Game *"Guess the Menu"* (Mode Tebak Nama & Tebak Harga secara dinamis dari produk nyata).
* **Luar Scope (Out-of-Scope):** 
  - Cetak struk via thermal printer bluetooth fisik hardware (cukup digital receipt).
  - Push Notification via Firebase FCM pihak ketiga (menggunakan database in-app notification center & secure polling).
  - Multi-tenancy publik terbuka (cabang toko bersifat jaringan internal multi-outlet).

---

## 2. Hak Akses Role & Struktur Navigasi (RBAC)

Aplikasi menerapkan *Role-Based Access Control* (RBAC) ketat dengan 3 role: **Owner**, **Manager**, dan **Staff (Kasir)**.

### 2.1 Struktur Navigasi Bawah (Bottom Navigation Bar)
* **Owner & Manager (5 Tab):**
  1. `Beranda` (Dashboard KPI Jaringan/Cabang)
  2. `Operasi` (Katalog Produk, Stok Inventaris, Riwayat POS)
  3. `AI` (Chatbot Bisnis Copilot Gemini)
  4. `Analitik` (Grafik Penjualan, Jam Sibuk, Perbandingan Cabang)
  5. `Lainnya` (Profil Bergambar, Keamanan Biometrik, Kelola Staf, Feedback PAM, Tentang Aplikasi, Logout)
* **Staff / Kasir (4 Tab):**
  1. `Beranda` (Ringkasan Shift: Uang Masuk & Jumlah Transaksi Hari Ini)
  2. `Kasir` (Layar POS Input Transaksi & Keranjang)
  3. `Stok` (Monitoring Sisa Stok Cabang Sendiri - Read Only)
  4. `Lainnya` (Profil Bergambar, Keamanan Biometrik, Feedback PAM, Tentang Aplikasi, Logout)

*(Menu Spesial seperti Mini Game `/game`, Peta LBS Cabang `/outlets`, dan Audit Blockchain `/integrity` dapat diakses langsung melalui tombol pintas di Beranda, Hub Operasi, atau deep-link routing).*

### 2.2 Permission Matrix

| Area Fungsional | Owner | Manager | Staff | Catatan Teknis |
|---|:---:|:---:|:---:|---|
| **Cakupan Outlet** | Semua Cabang | Cabang Terdaftar | 1 Cabang Tugas | Divalidasi via tabel `user_outlets` |
| **Manajemen User** | CRUD Penuh | Ditolak (403) | Ditolak (403) | Staff & Manager dilarang kelola akun |
| **Katalog Produk** | CRUD Penuh | CRUD Penuh | Read-Only | Staff tidak menerima field `cost_idr` / HPP |
| **Penyesuaian Stok** | CRUD Penuh | Cabang Sendiri | Ditolak (403) | Staff dilarang restock/koreksi manual |
| **Kasir POS** | Semua Cabang | Cabang Sendiri | Cabang Sendiri | Input transaksi & hitung kembalian |
| **Void Transaksi** | Kapan Saja | Max 24 Jam | Ditolak (403) | Kasir dilarang membatalkan struk |
| **Dashboard & Analitik** | Penuh (Semua) | Cabang Sendiri | Ringkasan Shift | Staff tidak melihat analitik margin global |
| **AI Business Copilot** | Penuh | Cabang Sendiri | Ditolak (403) | Tab AI disembunyikan untuk Staff |
| **Blockchain Audit** | Penuh | Cabang Sendiri | Badge Struk Saja | Audit rantai blok hanya untuk manajemen |
| **Peta Cabang (LBS)** | Penuh | Penuh | Read-Only Lokasi | Menghitung jarak GPS ke cabang terdekat |

> **Aturan Keamanan Scope:** Jika Manager atau Staff meminta data di luar cabang yang ditugaskan kepadanya, API wajib mengembalikan respon **HTTP 404 (Not Found)** atau **HTTP 403 (Forbidden)** untuk mencegah enumeration data rahasia cabang lain.

---

## 3. Daftar 5 Modul & 27 Fitur Utama

Sistem ARUS disusun secara modular menjadi **5 Modul Utama** yang membawahi seluruh **27 Fitur Wajib Tugas Akhir PAM**:

```
ARUS System
├── MOD-1: Autentikasi, Keamanan & Profil (Fitur 1–7)
├── MOD-2: Operasional — Menu, Resep, Bahan Baku (Inventaris) & Kasir POS (Fitur 8–15)
├── MOD-3: Blockchain SHA-256 & Notifikasi Mobile (Fitur 16–18)
├── MOD-4: Dashboard Analitik, Konversi, Sensor & LBS (Fitur 19–24)
└── MOD-5: Kecerdasan Buatan (AI/LLM) & Mini Game (Fitur 25–27)
```

### 3.1 MOD-1: Autentikasi, Keamanan & Profil (Fitur 1–7)
* **Fitur 1 — Login Email & Password:** Verifikasi kredensial menggunakan hash `argon2id` di Express API. Menghasilkan sepasang JWT (Access Token 15 menit & Refresh Token 7 hari).
* **Fitur 2 — Session Management:** Penyimpanan token di `flutter_secure_storage` (Android Keystore / iOS Keychain) dan tabel PostgreSQL `refresh_tokens` dengan mekanisme Family Rotation.
* **Fitur 3 — Biometric Unlock:** Buka kunci aplikasi cepat memakai sensor sidik jari/wajah via `local_auth`. Membuka sesi aktif tanpa input ulang password.
* **Fitur 4 — Menu Profil Bergambar:** Halaman akun dengan foto avatar (`avatar_url`), nama, role, dan daftar cabang aktif pengguna.
* **Fitur 5 — Menu Saran & Kesan Matkul PAM:** Formulir testimoni kesan dan saran perkuliahan PAM yang disimpan ke tabel PostgreSQL `feedback`.
* **Fitur 6 — Menu Logout:** Menghapus access token dan refresh token dari secure storage serta SQLite, merevokasi token di backend, lalu mengarahkan ke Layar Login.
* **Fitur 7 — Manajemen Akun Pengguna:** Menu khusus Owner untuk mendaftarkan akun Manager/Staff baru serta memetakan penugasan cabang (`user_outlets`).

### 3.2 MOD-2: Operasional — Menu, Resep, Bahan Baku & POS (Fitur 8–15)
Operasional bisnis F&B multi-outlet ARUS memisahkan secara tegas antara **Bahan Baku di Gudang (`ingredients`)** dan **Menu Jualan di Kasir (`products`)**, yang dihubungkan erat melalui **Resep (`product_recipes`)**:

1. **Database Menu Jualan (`products`):** Menyimpan informasi produk (nama menu, SKU, kategori, foto `image_url` untuk POS & Mini-Game *"Guess the Menu"*, harga jual `price_idr`).
2. **Database Bahan Baku & Stok per Cabang (`ingredients`):** Menyimpan stok bahan mentah di masing-masing cabang (`outlets`), seperti *Biji Kopi*, *Air Mineral*, *Susu UHT*, *Gula Aren* dalam satuan dasar (`gram`, `ml`, `pcs`).
3. **Jembatan Resep (`product_recipes`):** Menghubungkan Menu dengan Bahan Baku dengan takaran 1 porsi menu (`amount_needed`).
4. **Kalkulasi Estimasi Porsi Dinamis (*Real-Time Portion Estimation*):**
   $$\text{Estimasi Porsi} = \min_{i \in \text{Resep}} \left\lfloor \frac{\text{Stok Bahan Baku}_i}{\text{Takaran per Porsi}_i} \right\rfloor$$
5. **Dukungan Kasir Offline (*Offline POS Queue*):** Jika jaringan internet terputus di lapangan, transaksi kasir disimpan sementara ke tabel SQLite `offline_transactions` dan disinkronkan secara aman melalui `sync_service.dart`.

* **Fitur 8 — Kelola Menu & Resep (CRUD Products & Recipes):** [Owner, Manager] Mengelola daftar menu beserta takaran bahan bakunya (`product_recipes`).
* **Fitur 9 — Pencarian & Filter Katalog Menu (Dengan Estimasi Porsi):** [Semua Role] Mencari menu dan memfilter per kategori dengan badge estimasi porsi dinamis.
* **Fitur 10 — Backup Offline Katalog & Estimasi Porsi (SQLite):** [Semua Role] Menyimpan salinan daftar menu dan kuota porsi ke tabel SQLite `backup_products`.
* **Fitur 11 — Manajemen & Filter Bahan Baku Cabang:** [Owner, Manager] Manajemen bahan baku cabang dan filter status (`ok`, `low`, `out`).
* **Fitur 12 — Penyesuaian Stok Bahan Baku (*Ingredient Adjustment*):** [Owner, Manager] Mencatat *restock*, *correction*, atau *waste* atomik ke `inventory_movements`.
* **Fitur 13 — Kasir Mobile (POS) Berbasis Resep Atomik:** [Semua Role] Validasi kebutuhan bahan baku gabungan seluruh keranjang belanja, potong stok di `ingredients`, dan catat keluar di `inventory_movements` dalam 1 transaksi atomik.
* **Fitur 14 — Pencarian Struk & Backup Transaksi (SQLite):** [Semua Role] Mencari struk transaksi dan mencadangkan 50 struk terakhir ke SQLite `backup_transactions`.
* **Fitur 15 — Pembatalan Transaksi (*Void*) & Pengembalian Bahan Baku:** [Owner, Manager] Membatalkan struk, mengembalikan stok bahan baku ke `ingredients` (`void_return`), dan mencatat blok pembatalan di blockchain.

### 3.3 MOD-3: Blockchain SHA-256 & Notifikasi Mobile (Fitur 16–18)
* **Fitur 16 — Pencatatan Hash Blockchain (Dual-Layer Engine & DB Mirror):** Setiap transaksi POS sukses, server otomatis mencatat transaksi ke dalam *Child Block*, merangkumnya ke *Parent Daily Block* dengan *Merkle Root*, serta mencerminkannya ke tabel database `blockchain_records`.
* **Fitur 17 — Verifikasi Keaslian Data (Tamper Check & Recovery):** Fitur audit yang menghitung ulang hash data transaksi saat ini. Jika nilai omzet/item di database diubah secara ilegal, status berubah menjadi **TAMPERED**, dan sistem menyediakan pemulihan dari snapshot cadangan bersih (`backup_*`).
* **Fitur 18 — Notifikasi Mobile Stok Menipis:** Pemicu otomatis di backend saat transaksi membuat stok $\leq$ `reorder_level`. Disajikan melalui In-App Notification Center terpusat (`notifications`).

### 3.4 MOD-4: Dashboard Analitik, Konversi, Sensor & LBS (Fitur 19–24)
* **Fitur 19 — Dashboard KPI & Grafik Penjualan:** Ringkasan metrik total omzet, jumlah transaksi, rata-rata belanja (ATV), persentase pertumbuhan, serta grafik tren penjualan harian/mingguan/bulanan.
* **Fitur 20 — Konversi 3 Mata Uang (IDR, USD, EUR):** Fitur pengubah mata uang tampilan menggunakan kurs realtime dari Frankfurter API. Data dasar database tetap konsisten tersimpan dalam IDR integer.
* **Fitur 21 — Konversi 4 Zona Waktu (WIB, WITA, WIT, London):** Konversi waktu transaksi otomatis berdasarkan zona waktu operasional cabang lokal hingga cabang internasional London.
* **Fitur 22 — Sensor 1: Accelerometer (*Shake to Refresh*):** Deteksi guncangan HP untuk melakukan refresh data analitik dashboard secara interaktif (`sensors_plus`).
* **Fitur 23 — Sensor 2: Gyroscope (*Tilt Orientation Test*):** Deteksi sudut kemiringan HP (Pitch, Roll, Yaw) untuk pengujian orientasi perangkat (`sensors_plus`).
* **Fitur 24 — Peta Cabang & LBS (*Location-Based Services*):** Kalkulasi jarak GPS pengguna ke seluruh cabang menggunakan **Haversine Formula**, indikator cabang terdekat, dan filter cabang terurut.

### 3.5 MOD-5: Kecerdasan Buatan (AI/LLM) & Mini Game (Fitur 25–27)
* **Fitur 25 — Rule-Based Decision Support (Insights):** Mesin aturan analitik deterministik yang dievaluasi *on-the-fly* terhadap data nyata: R1 (`LOW_STOCK`), R2 (`RESTOCK_URGENT`), dan R4 (`SLOW_MOVING`) disertai bukti angka (*evidence*).
* **Fitur 26 — ARUS AI Business Assistant (Gemini LLM):** Chatbot konsultasi bisnis cerdas dengan persona ramah yang grounded pada fakta database nyata (omzet, stok, basket size), mampu diajak percakapan santai, dan menyajikan rekomendasi keputusan berstruktur rapi (*Ringkasan, Analisis, Rekomendasi*).
* **Fitur 27 — Mini Game (Guess the Menu):** Permainan kuis interaktif berbasis katalog menu nyata toko dengan 2 mode permainan: Mode Tebak Nama (*Guess Name*) dan Mode Tebak Harga (*Guess Price*) yang digenerate dinamis dari tabel `products`.

---

## 4. Business Rules & Batasan Sistem (BR)

### 4.1 Autentikasi & Keamanan (BR-AUTH)
* **BR-AUTH-01:** Password wajib di-hash menggunakan algoritma **argon2id** dengan salt unik sebelum disimpan ke tabel `users`.
* **BR-AUTH-02:** Percobaan login gagal sebanyak 5 kali berturut-turut mengakibatkan akun terkunci sementara selama 15 menit (HTTP 423 Locked).
* **BR-AUTH-03:** Sesi menggunakan Access Token JWT (TTL 15 menit) dan Refresh Token (TTL 7 hari) yang disimpan aman di `flutter_secure_storage` serta dicatat di tabel `refresh_tokens`.
* **BR-AUTH-04:** *Token Rotation & Revocation*: Setiap request perpanjangan sesi via `/api/auth/refresh` merotasi refresh token baru dan membatalkan token lama. Logout merevokasi token dari database dan storage.
* **BR-AUTH-05:** Pengguna non-aktif (`is_active = false`) ditolak seketika pada request berikutnya melalui pengecekan DB per request.
* **BR-AUTH-06:** Biometrik bertindak sebagai pengaman sesi lokal untuk mengakses token di Android Keystore tanpa meminta password ulang.

### 4.2 Katalog Produk & Harga (BR-CAT)
* **BR-CAT-01:** Kode SKU bersifat unik global; harga jual (`price_idr`) dan harga modal bahan baku (`cost_per_unit`) wajib disimpan sebagai tipe data **integer IDR**.
* **BR-CAT-02:** Setiap menu aktif wajib memiliki minimal 1 baris bahan baku pada tabel `product_recipes` agar estimasi porsinya dapat dihitung.
* **BR-CAT-03:** Perubahan harga produk di katalog tidak boleh mengubah riwayat harga snapshot di tabel `transaction_items` yang sudah terbit.
* **BR-CAT-04:** Nilai `cost_per_unit` pada bahan baku dan `cost_idr` (HPP resep) disaring ketat di backend; role Staff tidak boleh menerima field harga modal di response JSON apapun.
* **BR-CAT-05:** Produk non-aktif (`is_active = false`) ditolak saat diinput ke keranjang kasir POS (HTTP 404/409).

### 4.3 Inventaris, Bahan Baku & Mutasi Stok (BR-INV)
* **BR-INV-01 (Kalkulasi Porsi Dinamis):**
  $$\text{estimated\_portions} = \min_{i \in \text{Resep}} \left\lfloor \frac{\text{stock\_qty}_i}{\text{amount\_needed}_i} \right\rfloor$$
  Jika produk belum memiliki resep di cabang tersebut, nilai `estimated_portions = 0`.
* **BR-INV-02:** Batasan `stock_qty >= 0` ditegakkan secara absolut di tingkat PostgreSQL (`CHECK constraint`). Stok bahan baku tidak boleh minus.
* **BR-INV-03:** Setiap perubahan penambahan/pengurangan `stock_qty` pada `ingredients` wajib menulis baris catatan ke `inventory_movements` dalam transaksi database yang sama (Atomik).
* **BR-INV-04:** Klasifikasi status stok bahan baku:
  * `ok`: Kuantitas > `reorder_level`
  * `low`: Kuantitas $\leq$ `reorder_level` dan Kuantitas > 0
  * `out`: Kuantitas = 0
* **BR-INV-05:** Catatan pada `inventory_movements` bersifat *append-only* (dilarang *hard delete*).

### 4.4 Kasir POS & Transaksi Berbasis Resep (BR-POS)
* **BR-POS-01 (Validasi Bahan Baku Gabungan):** Server menjumlahkan total kebutuhan setiap bahan baku dari seluruh item di keranjang sebelum memotong stok. Jika ada satu saja bahan baku yang kurang, seluruh transaksi ditolak dengan HTTP 400/409 `INSUFFICIENT_STOCK` beserta nama bahan yang kurang.
* **BR-POS-02 (Idempotensi Transaksi):** Endpoint transaksi bersifat idempoten menggunakan UUID `client_request_id`. Request ganda dengan ID yang sama mengembalikan struk asli tanpa memotong stok ulang.
* **BR-POS-03 (Dukungan Offline POS):** Jika perangkat kasir kehilangan koneksi internet saat input transaksi, aplikasi menyimpan transaksi secara lokal di tabel SQLite `offline_transactions` dan mengeksekusi antrean sinkronisasi idempoten saat online kembali via `sync_service.dart`.
* **BR-POS-04:** Saat transaksi POS berhasil, `unit_cost_idr` pada `transaction_items` diisi dengan hasil penjumlahan HPP resep saat itu ($\sum (\text{amount\_needed}_i \times \text{cost\_per\_unit}_i)$) sebagai snapshot laba kotor.
* **BR-POS-05:** Pembatalan transaksi (*Void*) hanya diizinkan dalam rentang 24 jam setelah transaksi dibuat (Manager) atau kapan saja (Owner). Void mengembalikan stok bahan baku ke tabel `ingredients` (`void_return`) dan mencatat blok pembatalan di blockchain.
* **BR-POS-06:** Transaksi yang berstatus `voided` otomatis dikeluarkan dari seluruh perhitungan omzet dan KPI analitik.
* **BR-POS-07:** Format nomor struk: `TXN-{outlet_id_pendek}-{YYYYMMDD}-{sequence:04d}`.

### 4.5 Blockchain & Integritas Kriptografis (BR-INT)
* **BR-INT-01 (Arsitektur Ganda Dual-Layer):**
  - **Child Block (Transaction Layer):** Menyimpan transaksi individu hari berjalan secara berantai menggunakan SHA-256 (`previousHash` ke transaksi sebelumnya).
  - **Parent Block (Daily Layer):** Pada penutupan hari operasional, seluruh child blocks dirangkum ke dalam 1 Parent Block yang terhubung secara kriptografis ke hari sebelumnya (`previousParentHash`) dan memuat `merkle_root` seluruh transaksi hari itu.
* **BR-INT-02 (Pencerminan Database Persisten):**
  Setiap event transaksi dicatat di tabel PostgreSQL `blockchain_records` dengan snapshot payload (`event_data`), `data_hash`, `prev_hash`, `block_hash`, serta kolom cadangan `backup_*` untuk kebutuhan verifikasi dan pemulihan (*self-healing recovery*).
* **BR-INT-03 (Advisory Lock Konkurensi):** Pembuatan blok baru di PostgreSQL menggunakan `pg_advisory_xact_lock` berbasis `outlet_id` untuk menjamin kerapatan urutan `block_index` tanpa celah (*gap*).
* **BR-INT-04 (Deteksi Tamper):** Jika ada perubahan tidak sah pada data transaksi atau payload database, fungsi `validateChain()` menghasilkan status **TAMPERED** atau **BROKEN_CHAIN**. Pemulihan dilakukan dengan membaca data snapshot cadangan valid via `recoverBlock()`.

### 4.6 Analitik, Konversi & LBS (BR-ANA / LBS)
* **BR-ANA-01:** Perhitungan pergantian hari transaksi mengikuti zona waktu lokal masing-masing cabang (`outlets.timezone`), bukan UTC.
* **BR-ANA-02:** Perhitungan pertumbuhan omzet: jika periode pembanding sebelumnya bernilai 0, sistem mengembalikan `null` (aplikasi menampilkan label "Baru").
* **BR-LBS-01:** Jarak antara koordinat pengguna dengan cabang wajib dihitung menggunakan formula matematika **Haversine Formula**.
* **BR-LBS-02:** Jika izin lokasi GPS ditolak oleh pengguna, aplikasi tetap menampilkan daftar cabang dan menyediakan preset koordinat uji coba.

### 4.7 Kecerdasan Buatan (BR-AI)
* **BR-AI-01 (Zero Hallucination pada Angka Bisnis):** Seluruh angka nominal, omzet, persentase margin, dan kuantitas stok wajib berasal dari payload fakta (*facts*) yang dikumpulkan backend secara real-time dari database.
* **BR-AI-02 (Format Respon Terstruktur):** Jawaban analitis AI disusun dalam format narasi teks/markdown yang terstruktur jelas:
  - 📌 **Ringkasan Penjualan / Inventaris** (Fakta angka terverifikasi).
  - 📊 **Analisis Bisnis** (Akar masalah dan performa).
  - 💡 **Rekomendasi Keputusan (DSS)** (Saran tindakan operasional konkrit).
  - Disertai pertanyaan lanjutan (*quick suggestions*).
* **BR-AI-03 (Persona Ramah & Chitchat):** Sistem mengizinkan sapaan santai, percakapan kasual, dan permintaan panggilan personal pengguna (contoh: panggilan nama akrab) secara ramah, sebelum mengarahkan diskusi kembali ke analitik performa bisnis toko.
* **BR-AI-04:** Pembatasan frekuensi pertanyaan AI (Rate Limit): maksimum 10 pertanyaan per menit dan 100 pertanyaan per hari per akun.
* **BR-AI-05:** Multi-turn memory dipertahankan dalam sesi percakapan untuk memastikan kesinambungan konteks diskusi bisnis.

---

## 5. Desain Database Lengkap (PostgreSQL & SQLite)

Sistem ARUS menggunakan arsitektur database: **15 Tabel Inti PostgreSQL (Supabase)** dan **6 Tabel SQLite (`sqflite`) Lokal di Flutter**.

### 5.1 Skema Lengkap PostgreSQL (`api/prisma/schema.prisma`)

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
  id            String       @id @default(uuid()) @db.Uuid
  name          String       @db.VarChar(100)
  email         String       @unique @db.VarChar(255)
  password_hash String       @db.Text
  role          Role         @default(staff)
  avatar_url    String?      @db.Text
  is_active     Boolean      @default(true)
  created_at    DateTime     @default(now()) @db.Timestamptz()
  updated_at    DateTime     @updatedAt @db.Timestamptz()

  outlets        UserOutlet[]
  feedbacks      Feedback[]
  transactions   Transaction[]
  movements      InventoryMovement[]
  notifications  Notification[]
  ai_logs        AiChatLog[]
  game_sessions  GameSession[]
  refresh_tokens RefreshToken[]

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
// MODUL 2: KATALOG & INVENTARIS
// ==========================================

model ProductCategory {
  id         String    @id @default(uuid()) @db.Uuid
  name       String    @unique @db.VarChar(80)
  created_at DateTime  @default(now()) @db.Timestamptz()

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
// MODUL 2 & 3: TRANSAKSI POS, BLOCKCHAIN & NOTIF
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
  created_at DateTime @default(now()) @db.Timestamptz()

  user User @relation(fields: [user_id], references: [id], onDelete: Cascade)

  @@map("notifications")
}

// ==========================================
// MODUL 5: AI ASSISTANT, GAME & SESSION TOKENS
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

### 5.2 Skema DDL SQLite Lokal Flutter (`sqflite`)

Diterapkan pada file `lib/core/storage/local_db.dart`:

```sql
-- 1. Menyimpan Sesi User, Pengaturan Utilitas & Preferensi
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

-- 3. Detail Produk & Stok Offline Cache
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

-- 4. Backup Produk & Estimasi Porsi (Snapshot Sinkronisasi)
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

-- 5. Antrean Transaksi Offline (Pending Sync Queue)
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

-- 6. Backup 50 Struk Terakhir beserta Status Hash Blockchain
CREATE TABLE IF NOT EXISTS backup_transactions (
  transaction_id TEXT PRIMARY KEY,
  receipt_no TEXT NOT NULL,
  outlet_name TEXT NOT NULL,
  total_idr INTEGER NOT NULL,
  payment_method TEXT NOT NULL,
  data_hash TEXT,
  block_hash TEXT,
  created_at TEXT NOT NULL
);
```

---

## 6. Katalog API & Konvensi REST Web Service

### 6.1 Format Envelope Respon Seragam

Semua response API wajib mengikuti format envelope standar:

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
    "message": "Stok bahan Biji Kopi tidak mencukupi untuk pesanan ini.",
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
* `PUT /api/auth/change-password` — Mengubah password user saat ini.
* `GET /api/users` — [Owner] Daftar semua user beserta penugasan cabang.
* `POST /api/users` — [Owner] Mendaftarkan user baru.
* `PATCH /api/users/:id` — [Owner] Memperbarui role, nama, penugasan cabang, atau status aktif user.
* `GET /api/users/me/settings` — Mengambil preferensi user (currency, timezone, sensor, biometric).
* `PATCH /api/users/me/settings` — Memperbarui preferensi user.
* `POST /api/feedback` — Mengirimkan form kesan & saran PAM.
* `GET /api/feedback` — [Owner, Manager] Melihat daftar kesan & saran PAM.

#### MOD-2: Operasional (Katalog Menu, Resep, Bahan Baku & POS)
* `GET /api/catalog/products` — Daftar menu aktif beserta kalkulasi `estimated_portions` secara real-time dari bahan baku cabang (`outlet_id`, `category_id`, `q`, `sort`, `page`).
* `POST /api/catalog/products` — [Owner, Manager] Menambah menu baru beserta resep `recipes: [{ ingredient_id, amount_needed }]`.
* `GET /api/catalog/products/:id` — Detail menu beserta komposisi resep bahan bakunya.
* `PUT /api/catalog/products/:id` — [Owner, Manager] Memperbarui detail menu, harga, atau komposisi resep.
* `DELETE /api/catalog/products/:id` — [Owner, Manager] Menonaktifkan menu (`is_active = false`).
* `GET /api/catalog/categories` & `POST /api/catalog/categories` & `PUT /api/catalog/categories/:id` — Manajemen kategori produk.
* `GET /api/inventory/ingredients?outlet_id=...&status=ok|low|out&q=...` — [Owner, Manager] Daftar bahan baku cabang (Staff ditolak 403).
* `POST /api/inventory/ingredients` — [Owner, Manager] Menambah bahan baku baru di cabang tertentu.
* `PUT /api/inventory/ingredients/:id` — [Owner, Manager] Memperbarui nama, unit, reorder level, atau biaya modal bahan baku.
* `DELETE /api/inventory/ingredients/:id` — [Owner, Manager] Menghapus bahan baku dari cabang.
* `POST /api/inventory/adjustments` — [Owner, Manager] Mencatat restock, koreksi opname, atau waste atomik ke `inventory_movements`.
* `GET /api/inventory/movements` — [Owner, Manager] Riwayat audit mutasi keluar-masuk bahan baku.
* `POST /api/transactions` — Membuat transaksi penjualan POS atomik berbasis resep (validasi stok agregat, potong stok `ingredients`, catat `inventory_movements`, segel ke blockchain).
* `GET /api/transactions` — Riwayat transaksi POS (filter `outlet_id`, `status`, `receipt_no`, pagination).
* `POST /api/transactions/:id/void` — [Owner, Manager] Membatalkan transaksi, mengembalikan stok bahan baku sesuai resep (`void_return`), dan mencatat blok pembatalan di blockchain.
* `GET /api/pos/catalog?outlet_id=...` — Endpoint alternatif katalog kasir dengan ketersediaan stok & `max_portions`.
* `POST /api/pos/checkout` — Endpoint alternatif eksekusi checkout POS.
* `POST /api/pos/void` — Endpoint alternatif pembatalan transaksi POS.
* `GET /api/search?q=` — Pencarian global (produk, transaksi, cabang).

#### MOD-3: Blockchain & Notifikasi Mobile
* `GET /api/integrity/blockchain/chain/:outletId` — [Owner, Manager] Visualisasi rantai blok transaksi cabang terkait.
* `GET /api/integrity/blockchain/verify/:outletId` — [Owner, Manager] Validasi keutuhan dan integritas kriptografis rantai blok cabang.
* `POST /api/integrity/blockchain/simulate-tamper` — Simulasi manipulasi data transaksi untuk demonstrasi status TAMPERED.
* `POST /api/integrity/blockchain/recover` — Pemulihan blok yang rusak menggunakan snapshot cadangan valid.
* `GET /api/notifications` — Daftar kotak masuk notifikasi user.
* `GET /api/notifications/count` — Mengambil jumlah notifikasi yang belum dibaca.
* `POST /api/notifications/:id/read` — Menandai notifikasi telah dibaca.
* `POST /api/notifications/read-all` — Menandai semua notifikasi telah dibaca.

#### MOD-4: Dashboard Analitik, Konversi & LBS
* `GET /api/analytics/overview` — [Owner, Manager] KPI total omzet, transaksi, ATV, margin kotor, dan pertumbuhan.
* `GET /api/analytics/sales` — [Owner, Manager] Data grafik tren penjualan (`daily`, `weekly`, `monthly`).
* `GET /api/analytics/products` — [Owner, Manager] Produk terlaris (*top-selling*) dan barang mati (*slow-moving*).
* `GET /api/analytics/peak-hours` — [Owner, Manager] Distribusi jam-jam paling ramai transaksi.
* `GET /api/outlets` — Daftar cabang beserta koordinat latitude/longitude dan timezone.
* `POST /api/outlets` — [Owner] Menambah cabang baru.
* `PUT /api/outlets/:id` — [Owner] Memperbarui data cabang toko.
* `GET /api/outlets/nearest` — Menghitung cabang terdekat berdasarkan koordinat GPS pengguna.
* `GET /api/outlets/performance` — [Owner, Manager] Indeks performa penjualan cabang.
* `GET /api/fx/rates` — Kurs mata uang terbaru (IDR, USD, EUR) dari Frankfurter API via in-memory cache backend.

#### MOD-5: Kecerdasan Buatan & Mini Game
* `GET /api/insights` — [Owner, Manager] Evaluasi real-time (*on-the-fly*) mesin aturan bisnis R1 (`LOW_STOCK`), R2 (`RESTOCK_URGENT`), dan R4 (`SLOW_MOVING`).
* `POST /api/insights/generate` — [Owner, Manager] Evaluasi manual on-demand seluruh rule engine.
* `PATCH /api/insights/:id/status` — [Owner, Manager] Memperbarui status rekomendasi insight (`acknowledged` atau `dismissed`).
* `POST /api/ai/chat` — [Owner, Manager] Tanya jawab bisnis cerdas ke Gemini LLM grounded pada fakta database nyata (format narasi terstruktur: Ringkasan, Analisis, Rekomendasi).
* `GET /api/ai/conversations` — Riwayat percakapan chat AI.
* `GET /api/ai/conversations/:id/messages` — Detail riwayat percakapan spesifik.
* `GET /api/game/questions` — Membangkitkan 5 soal kuis mini-game *"Guess the Menu"* secara dinamis dari produk (Mode `guess_name` & `guess_price`).
* `POST /api/game/sessions` — Mengirimkan hasil jawaban kuis tebak menu/harga dan menyimpan skor ke `game_sessions`.
* `GET /api/game/sessions/me` — Riwayat skor permainan dan statistik capaian user.
* `GET /api/game/scenarios` — Skenario simulasi tantangan keputusan bisnis toko.

---

## 7. Aturan Keamanan (Security Requirements)

1. **Penyimpanan Token:** Token autentikasi JWT wajib disimpan menggunakan `flutter_secure_storage` pada platform mobile (menggunakan Android Keystore / iOS Keychain). Dilarang keras menyimpan token pada `SharedPreferences` biasa.
2. **Kueri Terparameter:** Seluruh interaksi database wajib menggunakan Prisma ORM atau parameterized query. Dilarang menggabungkan string mentah (*raw string concatenation*) untuk mencegah celah SQL Injection.
3. **Rahasia Sistem (Secrets):** Kunci rahasia JWT, API Key Gemini, dan connection string Supabase hanya berada di file backend `.env`. Aplikasi Flutter tidak boleh menyimpan rahasia backend di source code.
4. **Sanitasi Log:** Dilarang mencetak password plaintext atau refresh token pada log server (Pino logger).
5. **Rate Limiting:**
   * Login endpoint: Max 5 percobaan / 15 menit per IP.
   * AI Assistant: Max 10 request / menit per user.
   * General API: Max 100 request / 15 menit per IP.

---

## 8. Panduan Pre-Production & Setup

### 8.1 File Konfigurasi Environment (`api/.env`)
```env
NODE_ENV=development
PORT=5000
DATABASE_URL="postgresql://postgres.xxx:pass@aws-0-ap-southeast-1.pooler.supabase.com:6543/postgres?pgbouncer=true"
DIRECT_URL="postgresql://postgres.xxx:pass@aws-0-ap-southeast-1.pooler.supabase.com:5432/postgres"
JWT_ACCESS_SECRET=arus_jwt_secret_dev_key_super_secure_32_chars_min
JWT_ACCESS_TTL_SEC=900
REFRESH_TTL_DAYS=7
LLM_PROVIDER=gemini
LLM_API_KEY=AIzaSyYourGeminiApiKeyHere
LLM_MODEL=gemini-3.5-flash-lite
AI_RATE_PER_MIN=10
AI_RATE_PER_DAY=100
FX_API_URL=https://api.frankfurter.dev/v1/latest
FEATURE_INTEGRITY=true
FEATURE_NOTIFICATIONS=true
FEATURE_FX=true
FEATURE_GAME=true
FEATURE_AI=true
LOG_LEVEL=info
```

### 8.2 Inisialisasi Database & Seeding
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
2. **Notification & Token Maintenance:** Pembersihan token refresh kedaluwarsa serta pengelolaan status notifikasi terbaca.
3. **Daily Blockchain Settlement:** Penutupan blok harian (*Close Day*) untuk mengemas transaksi hari aktif ke dalam *Parent Daily Block*.

### 10.2 Skrip Demo & Testing
* `npm test` — Menjalankan seluruh test suite Vitest di backend.
* `npm run test:blockchain` — Menguji keandalan enkripsi SHA-256 dan rantai hash blockchain.

---

## 11. Panduan UI/UX & Standar Widget Mobile

* **Material Design 3:** Tampilan wajib konsisten mengikuti token Material 3 dari `lib/core/theme/`.
* **State Management:** Setiap layar yang mengambil data online wajib menggunakan widget pembungkus `AsyncStateView` dengan 4 penanganan state: *Loading Skeleton*, *Success View*, *Empty State*, dan *Error State*.
* **Format Mata Uang:** Menampilkan uang selalu melalui utilitas `MoneyFormatter.format(amount)` yang mendukung IDR, USD, dan EUR.
* **Ukuran Target Sentuh:** Tombol navigasi dan aksi kasir memiliki ukuran target sentuh minimal **48 x 48 dp** dengan ukuran font teks minimal **14 sp**.
* **Konfirmasi Aksi Destruktif:** Aksi seperti *Void Transaksi*, *Logout*, dan *Tutup Hari Blockchain* wajib memunculkan dialog konfirmasi (*Confirmation Modal*).

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

## 13. Konvensi Kode & Struktur Direktori

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
│   ├── core/                      # Network, storage, routing, theme, auth, sync, utilitas
│   ├── shared/                    # Widget global (AsyncStateView, EmptyState, AppWidgets)
│   └── features/                  # UI & State per fitur (auth, pos, dashboard, catalog, dll)
├── test/                          # Unit & Widget Test Flutter
│
├── api/                           # Proyek Express.js REST API
│   ├── src/
│   │   ├── config/                # Environment, Database, & Logger
│   │   ├── middleware/            # Auth, RBAC, Validator, Rate Limit
│   │   ├── modules/               # Controller, Service, & Route per domain
│   │   └── shared/                # Utilitas hash, canonical JSON, error handler
│   ├── prisma/                    # Skema database & seeder
│   └── tests/                     # Unit & Integration Test API (Vitest)
└── arus_srs_v2.md                 # Master Dokumen Acuan Tunggal (v2.1)
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
| **T-AI-01** | Mengajukan pertanyaan kondisi penjualan ke AI | AI menjawab dengan narasi ramah berstruktur: Ringkasan, Analisis, dan Rekomendasi |
| **T-GAME-01**| Menyelesaikan kuis tebak menu/harga ("Guess the Menu") | Skor tersimpan di tabel `game_sessions` dan muncul di riwayat game |

---

## 15. Pembagian Tugas Tim & Traceability Matrix

### 15.1 Pembagian Tanggung Jawab Tim (3 Anggota)

* **Anggota 1 — Backend Web Service, Database & Blockchain:**
  * Skema Prisma PostgreSQL (15 tabel) & Seeding data multi-outlet.
  * Autentikasi JWT (argon2id), Refresh Token Rotation, RBAC, dan Outlet Scoping.
  * API Katalog, Resep, Inventaris, dan Transaksi Kasir POS atomik.
  * Implementasi **Dual-Layer & Persistent Blockchain SHA-256** serta endpoint audit/pemulihan.
  * Kueri agregasi untuk **Dashboard Analitik KPI & Peak Hours**.

* **Anggota 2 — Flutter Core UI, SQLite Lokal & Utilitas Mobile:**
  * Kerangka navigasi multi-role (Bottom Navigation 4 & 5 tab).
  * Layar Login & integrasi **Biometric Unlock (`local_auth`)**.
  * Layar Profil bergambar, **Form Kesan/Saran Matkul PAM**, dan Tentang Aplikasi.
  * Layar Kasir POS & keranjang belanja interaktif.
  * Sinkronisasi **Offline POS Queue & Backup SQLite (`sqflite`)** via `sync_service.dart`.
  * Widget **Konversi Mata Uang (IDR/USD/EUR)** & **Zona Waktu Multi-Timezone**.
  * Modul **In-App Notification Center**.

* **Anggota 3 — Fitur Spesial (Sensor, LBS Peta, AI/LLM & Mini Game):**
  * Deteksi sensor **Accelerometer (Shake)** & **Gyroscope (Tilt)** via `sensors_plus`.
  * Layar **Manajemen Cabang & LBS** dengan kalkulasi jarak GPS terdekat (*Haversine Formula*).
  * Integrasi **ARUS AI Business Assistant** dengan Google Gemini API & Grounded Facts.
  * Mesin aturan **Decision Support (Insights)** evaluasi *on-the-fly*.
  * Desain antarmuka & generator soal **Mini Game (*Guess the Menu*)** dinamis dari tabel `products`.

---

### 15.2 Requirement Traceability Matrix (Pemetaan 27 Fitur)

| No | Nama Fitur | Modul | Berkas Implementasi Utama | Kriteria Dosen PAM | Kode Uji |
|:---:|---|:---:|---|---|:---:|
| 1 | Login Enkripsi | MOD-1 | `auth.service.ts` · `login_screen.dart` | Login Enkripsi Non-Firebase | T-AUTH-01 |
| 2 | Sesi JWT & SQLite | MOD-1 | `auth.service.ts` · `secure_store.dart` · `local_db.dart` | Manajemen Sesi Aplikasi | T-AUTH-04 |
| 3 | Login Biometrik | MOD-1 | `biometric_service.dart` · `splash_screen.dart` | Login Sensor Biometrik | T-AUTH-07 |
| 4 | Profil Bergambar | MOD-1 | `profile_screen.dart` | Bottom Nav: Profil Bergambar | T-RBAC-01 |
| 5 | Kesan & Saran PAM | MOD-1 | `feedback_screen.dart` · `feedback.service.ts` | Bottom Nav: Menu Saran PAM | T-RBAC-01 |
| 6 | Menu Logout | MOD-1 | `auth_notifier.dart` · `auth.service.ts` | Bottom Nav: Menu Logout | T-AUTH-04 |
| 7 | Manajemen User | MOD-1 | `user_management_screen.dart` · `users.service.ts` | Multi-Role Access Control | T-RBAC-05 |
| 8 | Master Produk & Resep | MOD-2 | `product_list_screen.dart` · `catalog.service.ts` | API Web Service & Online DB | T-CAT-01 |
| 9 | Cari & Filter Katalog | MOD-2 | `product_list_screen.dart` · `catalog.controller.ts` | Fasilitas Pencarian & Pemilihan | T-CAT-03 |
| 10 | Backup Offline SQLite | MOD-2 | `local_db.dart` (`backup_products`, `cached_products`) | Database Lokal SQLite & Online | T-DB-02 |
| 11 | Filter Status Stok | MOD-2 | `inventory_list_screen.dart` · `inventory.service.ts` | Fasilitas Pemilihan & Filter | T-INV-04 |
| 12 | Penyesuaian Stok | MOD-2 | `inventory_list_screen.dart` · `inventory.service.ts` | Decision Support Inventaris | T-INV-03 |
| 13 | Kasir Mobile POS | MOD-2 | `pos_screen.dart` · `transactions.service.ts` | Konsep Proyek Akhir (POS) | T-POS-01 |
| 14 | Struk & Offline Queue | MOD-2 | `local_db.dart` (`offline_transactions`) · `sync_service.dart` | Pencarian + DB Lokal SQLite | T-POS-03 |
| 15 | Void Transaksi | MOD-2 | `transactions.service.ts` (`voidTransaction`) | Integritas Data Transaksi | T-POS-05 |
| 16 | Hash Blockchain | MOD-3 | `blockchain.service.ts` · `dual_blockchain.ts` | Fitur Blockchain Sederhana | T-INT-01 |
| 17 | Audit Tamper Check | MOD-3 | `integrity_chain_screen.dart` · `blockchain.service.ts` | Fitur Blockchain Sederhana | T-INT-03 |
| 18 | Notifikasi Stok Tipis | MOD-3 | `notification_screen.dart` · `notifications.service.ts` | Notifikasi Mobile Sesuai Konsep | T-NOT-01 |
| 19 | Dashboard Analitik | MOD-4 | `dashboard_screen.dart` · `analytics.service.ts` | Business Intelligence & Charts | T-ANA-01 |
| 20 | Konversi 3 Kurs | MOD-4 | `money_formatter.dart` · `fx.service.ts` | Konversi Mata Uang (IDR, USD, EUR) | T-CUR-01 |
| 21 | Konversi 4 Waktu | MOD-4 | `timezone_converter.dart` | Konversi 4 Zona Waktu | T-TZ-01 |
| 22 | Sensor Accelerometer | MOD-4 | `sensor_provider.dart` (Shake to Refresh) · `dashboard_screen.dart` | Sensor 1: Accelerometer | T-SEN-01 |
| 23 | Sensor Gyroscope | MOD-4 | `sensor_provider.dart` · `sensor_test_screen.dart` | Sensor 2: Gyroscope | T-SEN-03 |
| 24 | Peta LBS & Haversine | MOD-4 | `outlet_list_screen.dart` · `outlets.service.ts` | Web Service & Fasilitas LBS | T-LBS-01 |
| 25 | Decision Support | MOD-5 | `insights.service.ts` (Evaluasi On-the-Fly) | AI Sesuai Konsep Tema | T-DS-01 |
| 26 | Chatbot AI Gemini | MOD-5 | `ai.service.ts` · `ai_home_screen.dart` | Fitur AI & LLM Sesuai Tema | T-AI-01 |
| 27 | Mini Game Guess Menu | MOD-5 | `game_home_screen.dart` · `game.service.ts` | Mini Games Terkait Konsep | T-GAME-01 |

---

*Akhir Dokumen — ARUS SRS v2.1 Master Single Source of Truth.*
