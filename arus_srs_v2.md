# ARUS SRS v2 — Software Requirements Specification & Master Blueprint

**Versi:** 2.0 (Master Single Source of Truth)  
**Proyek:** ARUS — Multi-Outlet Mobile Business Intelligence & POS System  
**Mata Kuliah:** Pemrograman Aplikasi Mobile (PAM)  
**Stack Utama:** Flutter (Android/iOS) + Node.js/Express (TypeScript) + PostgreSQL (Supabase) + SQLite (`sqflite`)  
**Repository:** `https://github.com/supremeinori/arus` (branch `main`)  
**Dokumen ini menggantikan secara resmi:** `ARUS_SRS.md`, `ARUS_DESAIN_ADDER.md`, `arus_modul.md`, dan `Modul_guide.md`.

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
ARUS adalah sistem operasional kasir (Mobile POS) dan pendukung keputusan bisnis multi-cabang (*Mobile Business Decision-Support System*). Aplikasi mobile dibangun menggunakan **Flutter** yang berkomunikasi secara eksklusif ke **Express.js REST API pribadi** (Node.js/TypeScript) dengan database cloud **PostgreSQL (Supabase)**. Untuk menjamin keandalan saat jaringan terputus, Flutter mengimplementasikan database lokal **SQLite (`sqflite`)** sebagai *read-only offline backup*.

### 1.2 Diagram Arsitektur Sistem

```text
[ Flutter Mobile App (Android / iOS) ]
   ├── UI Layer: Kasir POS, Dashboard KPI, Peta Cabang, Chat AI, Mini Game, Profil
   ├── State Management: Riverpod (AsyncNotifier / Notifier)
   ├── Local DB: SQLite (sqflite) -> Backup Katalog, 50 Struk Terakhir, Sesi & Preferensi
   │
   ├──► (HTTPS REST JSON) ──► [ Express.js Backend API (/api/*) ]
   │                             ├── Middleware: Auth JWT, RBAC, Outlet Scope, Zod Validator, Rate Limit
   │                             └── Prisma ORM ──► [ PostgreSQL Cloud (Supabase) ]
   │
   └──► (Public Web Services)
         ├── Frankfurter API (Kurs Mata Uang: IDR, USD, EUR)
         ├── OpenStreetMap Tile Server / flutter_map (Peta & LBS)
         └── Google Gemini API (LLM Business Assistant via Backend)
```

### 1.3 Scope Sistem
* **Dalam Scope (In-Scope):** Autentikasi JWT (argon2), Biometric Fingerprint/Face, Profil + Feedback PAM, Multi-Role & Outlet Scoping, Manajemen Produk & Kategori, Manajemen Stok & Mutasi, Kasir POS Atomik, Verifikasi Rantai Hash Blockchain SHA-256, Notifikasi Stok Menipis, Dashboard Analitik KPI, Multi-Currency (IDR/USD/EUR), Multi-Timezone (WIB/WITA/WIT/London), Sensor Accelerometer (Shake) & Gyroscope (Tilt), LBS Peta Cabang & Jarak Haversine, Decision Support Rules (R1–R8), Asisten AI Gemini (Data/Dugaan/Saran), dan Mini Game Business Decision Challenge.
* **Luar Scope (Out-of-Scope):** Transaksi penjualan offline (offline write POS tidak diizinkan demi integritas stok), Push Notification via FCM/APNs (cukup polling & local notifications), cetak struk via thermal printer bluetooth fisik, multi-tenancy dinamis (cabang bersifat internal multi-outlet).

---

## 2. Hak Akses Role & Struktur Navigasi (RBAC)

Aplikasi menerapkan *Role-Based Access Control* (RBAC) ketat dengan 3 role: **Owner**, **Manager**, dan **Staff (Kasir)**.

### 2.1 Struktur Navigasi Bawah (Bottom Navigation Bar)
* **Owner & Manager (5 Tab):**
  1. `Beranda` (Dashboard KPI Jaringan/Cabang)
  2. `Operasi` (Katalog Produk, Stok Inventaris, Riwayat POS)
  3. `AI Assistant` (Chatbot Bisnis Gemini)
  4. `Analitik` (Grafik Penjualan, Jam Sibuk, Perbandingan Cabang)
  5. `Lainnya` (Profil Bergambar, Feedback PAM, Mini Game, Peta LBS, Pengaturan, Logout)
* **Staff / Kasir (4 Tab):**
  1. `Beranda` (Ringkasan Shift: Uang Masuk & Jumlah Transaksi Hari Ini)
  2. `Kasir` (Layar POS Input Transaksi)
  3. `Stok` (Monitoring Sisa Stok Cabang Sendiri - Read Only)
  4. `Lainnya` (Profil Bergambar, Feedback PAM, Mini Game, Peta LBS, Pengaturan, Logout)

### 2.2 Permission Matrix

| Area Fungsional | Owner | Manager | Staff | Catatan Teknis |
|---|:---:|:---:|:---:|---|
| **Cakupan Outlet** | Semua Cabang | Cabang Terdaftar | 1 Cabang Tugas | Divalidasi via tabel `user_outlets` |
| **Manajemen User** | CRUD Penuh | Ditolak (403) | Ditolak (403) | Staff & Manager tidak bisa kelola akun |
| **Katalog Produk** | CRUD Penuh | CRUD Penuh | Read-Only | Staff tidak menerima field `cost_idr` |
| **Penyesuaian Stok** | CRUD Penuh | Cabang Sendiri | Ditolak (403) | Staff dilarang restock/koreksi manual |
| **Kasir POS** | Semua Cabang | Cabang Sendiri | Cabang Sendiri | Input transaksi & hitung kembalian |
| **Void Transaksi** | Kapan Saja | Max 24 Jam | Ditolak (403) | Kasir dilarang membatalkan struk |
| **Dashboard & Analitik** | Penuh (Semua) | Cabang Sendiri | Ringkasan Shift | Staff tidak melihat analitik margin/omzet global |
| **AI Business Assistant** | Penuh | Cabang Sendiri | Ditolak (403) | Tab AI disembunyikan untuk Staff |
| **Blockchain Audit** | Penuh | Cabang Sendiri | Badge Struk Saja | Audit rantai blok hanya untuk manajemen |
| **Peta Cabang (LBS)** | Penuh + Warna | Penuh + Warna | Read-Only Lokasi | Menghitung jarak GPS ke cabang terdekat |

> **Aturan Keamanan Scope:** Jika Manager atau Staff meminta data di luar cabang yang ditugaskan kepadanya, API wajib mengembalikan respon **HTTP 404 (Not Found)**, bukan 403, untuk mencegah enumeration data rahasia cabang lain.

---

## 3. Daftar 5 Modul & 27 Fitur Utama

Sistem ARUS disusun secara modular menjadi **5 Modul Utama** yang membawahi seluruh **27 Fitur Wajib Tugas Akhir PAM**:

```
ARUS System
├── MOD-1: Autentikasi, Keamanan & Profil (Fitur 1–7)
├── MOD-2: Operasional — Katalog, Stok, Kasir POS & Pencarian (Fitur 8–15)
├── MOD-3: Blockchain SHA-256 & Notifikasi Mobile (Fitur 16–18)
├── MOD-4: Dashboard Analitik, Konversi, Sensor & LBS (Fitur 19–24)
└── MOD-5: Kecerdasan Buatan (AI/LLM) & Mini Game (Fitur 25–27)
```

### 3.1 MOD-1: Autentikasi, Keamanan & Profil (Fitur 1–7)
Modul pengelola identitas, sesi aman, biometrik, profil pengguna, dan feedback akademik.

* **Fitur 1 — Login Email & Password:** Verifikasi kredensial menggunakan hash `argon2id` di Express API. Menghasilkan sepasang JWT (Access Token 15 menit & Refresh Token 7 hari).
* **Fitur 2 — Session Management:** Penyimpanan token di `flutter_secure_storage` (Android Keystore). Refresh token otomatis dirotasi berkala.
* **Fitur 3 — Biometric Unlock:** Buka kunci aplikasi cepat memakai sensor sidik jari/wajah via `local_auth`. Membuka sesi aktif tanpa input ulang password.
* **Fitur 4 — Menu Profil Bergambar:** Halaman akun dengan foto avatar (`avatar_url`), nama, role, dan daftar cabang aktif pengguna.
* **Fitur 5 — Menu Saran & Kesan Matkul PAM:** Formulir testimoni kesan dan saran perkuliahan PAM yang disimpan ke tabel PostgreSQL `feedback`.
* **Fitur 6 — Menu Logout:** Menghapus access token dan refresh token dari secure storage serta SQLite, lalu mengarahkan ke Layar Login.
* **Fitur 7 — Manajemen Akun Pengguna:** Menu khusus Owner untuk mendaftarkan akun Manager/Staff baru serta memetakan penugasan cabang (`user_outlets`).

**Tautan Source Code:**
* Flutter UI: [`lib/features/auth/`](https://github.com/supremeinori/arus/tree/main/app/lib/features/auth) · [`lib/features/profile/`](https://github.com/supremeinori/arus/tree/main/app/lib/features/profile) · [`lib/features/users/`](https://github.com/supremeinori/arus/tree/main/app/lib/features/users) · [`lib/features/feedback/`](https://github.com/supremeinori/arus/tree/main/app/lib/features/feedback)
* Flutter Core: [`lib/core/auth/biometric_service.dart`](https://github.com/supremeinori/arus/blob/main/app/lib/core/auth/biometric_service.dart) · [`lib/core/storage/secure_store.dart`](https://github.com/supremeinori/arus/blob/main/app/lib/core/storage/secure_store.dart)
* Backend API: [`api/src/modules/auth/`](https://github.com/supremeinori/arus/tree/main/api/src/modules/auth) · [`api/src/modules/users/`](https://github.com/supremeinori/arus/tree/main/api/src/modules/users) · [`api/src/modules/feedback/`](https://github.com/supremeinori/arus/tree/main/api/src/modules/feedback) · [`api/src/middleware/auth.ts`](https://github.com/supremeinori/arus/blob/main/api/src/middleware/auth.ts)

---

### 3.2 MOD-2: Operasional — Katalog, Stok, Kasir POS & Pencarian (Fitur 8–15)
Modul transaksi penjualan harian, master produk, mutasi inventaris, dan pencarian.

* **Fitur 8 — CRUD Produk & Kategori:** Mengelola katalog barang, SKU unik, kategori, harga jual (`price_idr`), dan harga modal (`cost_idr`).
* **Fitur 9 — Pencarian & Filter Katalog:** Pencarian instan berdasarkan nama/SKU produk dan filter kategori atau status aktif.
* **Fitur 10 — Backup Offline Katalog (SQLite):** Sinkronisasi otomatis saat online ke tabel SQLite `backup_products`. Jika internet mati, kasir tetap bisa melihat katalog barang.
* **Fitur 11 — Filter Status Stok Cabang:** Monitoring stok cabang dengan indikator warna status (`ok` > reorder_level, `low` <= reorder_level, `out` = 0) serta estimasi *days of cover*.
* **Fitur 12 — Penyesuaian Stok (*Stock Adjustment*):** Pencatatan perubahan stok non-penjualan (`restock`, `correction`, `waste`) yang wajib masuk ke `inventory_movements`.
* **Fitur 13 — Kasir Mobile (POS):** Pemilihan produk ke keranjang belanja, kalkulasi total dan kembalian di server, serta pengurangan stok secara atomik. Idempoten menggunakan `client_request_id`.
* **Fitur 14 — Pencarian Struk & Backup Transaksi (SQLite):** Riwayat transaksi dengan pencarian nomor struk/tanggal/metode bayar, serta penyimpanan 50 struk terakhir ke `backup_transactions`.
* **Fitur 15 — Pembatalan Transaksi (*Void*):** Pembatalan transaksi salah (khusus Manager/Owner, batas 24 jam) yang mengembalikan stok dan mencatat blok pembatalan di blockchain.

**Tautan Source Code:**
* Flutter UI: [`lib/features/catalog/`](https://github.com/supremeinori/arus/tree/main/app/lib/features/catalog) · [`lib/features/inventory/`](https://github.com/supremeinori/arus/tree/main/app/lib/features/inventory) · [`lib/features/pos/`](https://github.com/supremeinori/arus/tree/main/app/lib/features/pos) · [`lib/features/search/`](https://github.com/supremeinori/arus/tree/main/app/lib/features/search)
* Flutter Core: [`lib/core/storage/local_db.dart`](https://github.com/supremeinori/arus/blob/main/app/lib/core/storage/local_db.dart)
* Backend API: [`api/src/modules/catalog/`](https://github.com/supremeinori/arus/tree/main/api/src/modules/catalog) · [`api/src/modules/inventory/`](https://github.com/supremeinori/arus/tree/main/api/src/modules/inventory) · [`api/src/modules/transactions/`](https://github.com/supremeinori/arus/tree/main/api/src/modules/transactions) · [`api/src/modules/search/`](https://github.com/supremeinori/arus/tree/main/api/src/modules/search)

---

### 3.3 MOD-3: Blockchain SHA-256 & Notifikasi Mobile (Fitur 16–18)
Modul penjamin integritas anti-manipulasi data transaksi serta sistem peringatan dini.

* **Fitur 16 — Pencatatan Hash Blockchain (SHA-256):** Setiap transaksi POS sukses, server otomatis membuat `data_hash` dari canonical JSON transaksi dan menghubungkannya dengan `prev_hash` blok sebelumnya ke tabel `blockchain_records`.
* **Fitur 17 — Verifikasi Keaslian Data (Tamper Check):** Fitur audit yang menghitung ulang hash data transaksi saat ini. Jika nilai omzet/item di database diubah secara ilegal, status berubah seketika menjadi **TAMPERED**.
* **Fitur 18 — Notifikasi Mobile Stok Menipis:** Pemicu otomatis di backend saat transaksi membuat stok $\leq$ `reorder_level`. Menampilkan notifikasi lokal di HP kasir dan manajer via `flutter_local_notifications`.

**Tautan Source Code:**
* Flutter UI: [`lib/features/integrity/`](https://github.com/supremeinori/arus/tree/main/app/lib/features/integrity) · [`lib/features/notifications/`](https://github.com/supremeinori/arus/tree/main/app/lib/features/notifications)
* Backend API: [`api/src/modules/integrity/`](https://github.com/supremeinori/arus/tree/main/api/src/modules/integrity) · [`api/src/modules/notifications/`](https://github.com/supremeinori/arus/tree/main/api/src/modules/notifications)

---

### 3.4 MOD-4: Dashboard Analitik, Konversi, Sensor & LBS (Fitur 19–24)
Modul visualisasi performa bisnis, utilitas internasional, sensor gerak perangkat, dan peta cabang.

* **Fitur 19 — Dashboard KPI & Grafik Penjualan:** Ringkasan metrik total omzet, jumlah transaksi, rata-rata belanja (ATV), persentase pertumbuhan, serta grafik tren penjualan harian/mingguan/bulanan (`fl_chart`).
* **Fitur 20 — Konversi 3 Mata Uang (IDR, USD, EUR):** Fitur pengubah mata uang tampilan menggunakan kurs realtime dari Frankfurter API. Data dasar database tetap konsisten tersimpan dalam IDR integer.
* **Fitur 21 — Konversi 4 Zona Waktu (WIB, WITA, WIT, London):** Konversi waktu transaksi otomatis berdasarkan zona waktu operasional cabang lokal hingga cabang ekspansi internasional di London.
* **Fitur 22 — Sensor 1: Accelerometer (*Shake to Refresh*):** Deteksi guncangan HP untuk melakukan refresh data analitik dashboard secara interaktif (`sensors_plus`).
* **Fitur 23 — Sensor 2: Gyroscope (*Tilt Chart Switch*):** Deteksi kemiringan sudut HP untuk mengganti rentang filter waktu grafik analitik secara otomatis.
* **Fitur 24 — Peta Cabang & LBS (*Location-Based Services*):** Visualisasi titik koordinat cabang di OpenStreetMap (`flutter_map`), kalkulasi jarak GPS pengguna ke cabang terdekat (*Haversine Formula*), dan pewarnaan pin berdasarkan performa penjualan.

**Tautan Source Code:**
* Flutter UI: [`lib/features/dashboard/`](https://github.com/supremeinori/arus/tree/main/app/lib/features/dashboard) · [`lib/features/analytics/`](https://github.com/supremeinori/arus/tree/main/app/lib/features/analytics) · [`lib/features/outlets/`](https://github.com/supremeinori/arus/tree/main/app/lib/features/outlets) · [`lib/features/sensors/`](https://github.com/supremeinori/arus/tree/main/app/lib/features/sensors)
* Flutter Core: [`lib/core/utils/money_formatter.dart`](https://github.com/supremeinori/arus/blob/main/app/lib/core/utils/money_formatter.dart) · [`lib/core/utils/timezone_converter.dart`](https://github.com/supremeinori/arus/blob/main/app/lib/core/utils/timezone_converter.dart)
* Backend API: [`api/src/modules/analytics/`](https://github.com/supremeinori/arus/tree/main/api/src/modules/analytics) · [`api/src/modules/outlets/`](https://github.com/supremeinori/arus/tree/main/api/src/modules/outlets) · [`api/src/modules/fx/`](https://github.com/supremeinori/arus/tree/main/api/src/modules/fx)

---

### 3.5 MOD-5: Kecerdasan Buatan (AI/LLM) & Mini Game (Fitur 25–27)
Modul penalaran cerdas berbasis data nyata dan simulasi pelatihan keputusan bisnis.

* **Fitur 25 — Rule-Based Decision Support (Insights):** Mesin aturan analitik deterministik (R1 s/d R8) yang mendeteksi stok kritis, barang mati (*slow-moving*), anomali jam ramai, dan penurunan omzet disertai bukti angka (*evidence*).
* **Fitur 26 — ARUS AI Business Assistant (Gemini LLM):** Chatbot konsultasi bisnis cerdas di mana backend mengumpulkan fakta angka dari PostgreSQL, lalu memintakan kesimpulan ke Gemini API dengan format wajib: **Data / Dugaan / Saran** tanpa mengarang angka.
* **Fitur 27 — Mini Game (Guess the Menu): Permainan kuis kasual interaktif berbasis data katalog POS untuk melatih pengenalan produk (product knowledge). Memiliki 2 mode permainan: Mode Tebak Nama (melihat foto menu dan memilih nama produk yang tepat) dan Mode Tebak Harga (melihat foto beserta nama menu dan menebak harga jual price_idr yang benar). Soal dibangkitkan secara dinamis dari tabel products dengan batas waktu hitung mundur dan sistem poin, serta mengacu pada spesifikasi lengkap di dokumen C:\MyProjects\arus\minigame_design.md

**Tautan Source Code:**
* Flutter UI: [`lib/features/insights/`](https://github.com/supremeinori/arus/tree/main/app/lib/features/insights) · [`lib/features/ai_assistant/`](https://github.com/supremeinori/arus/tree/main/app/lib/features/ai_assistant) · [`lib/features/game/`](https://github.com/supremeinori/arus/tree/main/app/lib/features/game)
* Backend API: [`api/src/modules/insights/`](https://github.com/supremeinori/arus/tree/main/api/src/modules/insights) · [`api/src/modules/ai/`](https://github.com/supremeinori/arus/tree/main/api/src/modules/ai) · [`api/src/modules/game/`](https://github.com/supremeinori/arus/tree/main/api/src/modules/game)

---

## 4. Business Rules & Batasan Sistem (BR)

### 4.1 Autentikasi & Keamanan (BR-AUTH)
* **BR-AUTH-01:** Password wajib di-hash menggunakan algoritma **argon2id** dengan salt unik sebelum disimpan ke tabel `users`.
* **BR-AUTH-02:** Percobaan login gagal sebanyak 5 kali berturut-turut mengakibatkan akun terkunci selama 15 menit (HTTP 423 Locked).
* **BR-AUTH-03:** Sesi autentikasi menggunakan Stateless JWT (TTL 7 hari) yang disimpan aman di `flutter_secure_storage` (Android Keystore) pada perangkat mobile.
* **BR-AUTH-04:** *Client-Side Session Revocation*: Logout dilakukan dengan menghapus JWT dari secure storage dan SQLite lokal; validasi sesi dilakukan secara berkala ke endpoint `/api/auth/me`.
* **BR-AUTH-05:** Pengguna non-aktif (`is_active = false`) ditolak seketika pada request berikutnya melalui pengecekan DB per request.
* **BR-AUTH-06:** Biometrik bertindak sebagai pengaman sesi lokal untuk mengakses token di Android Keystore tanpa meminta password ulang.
* **BR-AUTH-07:** Tiga kali kegagalan otentikasi biometrik memaksa aplikasi kembali meminta input email & password manual.

### 4.2 Katalog Produk & Harga (BR-CAT)
* **BR-CAT-01:** Kode SKU bersifat unik global; duplikasi memicu respon HTTP 409 `CATALOG_SKU_DUPLICATE`.
* **BR-CAT-02:** Seluruh nilai harga (`price_idr`) dan biaya modal (`cost_idr`) wajib disimpan sebagai tipe data **integer IDR**. Tidak diperkenankan desimal floating-point.
* **BR-CAT-03:** Perubahan harga produk di katalog tidak boleh mengubah riwayat harga snapshot di tabel `transaction_items` yang sudah terbit.
* **BR-CAT-04:** Nilai `cost_idr` disaring ketat di backend; role Staff tidak boleh menerima field harga modal di response JSON apapun.
* **BR-CAT-05:** Produk non-aktif (`is_active = false`) ditolak saat diinput ke keranjang kasir POS (HTTP 409 `TXN_PRODUCT_INACTIVE`).

### 4.3 Inventaris & Mutasi Stok (BR-INV)
* **BR-INV-01:** Setiap perubahan kuantitas stok wajib dicatat di tabel `inventory_movements` pada transaksi database yang sama (Atomik).
* **BR-INV-02:** Batasan `quantity >= 0` ditegakkan secara absolut di tingkat PostgreSQL (`CHECK constraint`). Stok tidak boleh minus dalam kondisi apapun.
* **BR-INV-03:** Dua kasir yang menjual sisa barang terakhir secara bersamaan: kasir tercepat berhasil, kasir kedua menerima respon HTTP 409 `INVENTORY_INSUFFICIENT`.
* **BR-INV-04:** Klasifikasi status stok:
  * `ok`: Kuantitas > `reorder_level`
  * `low`: Kuantitas $\leq$ `reorder_level` dan Kuantitas > 0
  * `out`: Kuantitas = 0
* **BR-INV-05:** Catatan pada `inventory_movements` bersifat *append-only* (dilarang *hard delete*).

### 4.4 Kasir POS & Transaksi (BR-POS)
* **BR-POS-01:** Subtotal, diskon, dan total akhir **wajib dikalkulasi ulang di server**. Nilai nominal harga dari client diabaikan total demi mencegah kecurangan harga.
* **BR-POS-02:** Endpoint `POST /transactions` bersifat idempoten menggunakan UUID `client_request_id`. Request ganda dengan ID yang sama mengembalikan struk asli tanpa memotong stok ulang.
* **BR-POS-03:** Transaksi POS bersifat *all-or-nothing* (atomik). Jika satu barang kehabisan stok, seluruh transaksi dan pemotongan stok dibatalkan (rollback).
* **BR-POS-04:** Nominal pembayaran tunai yang kurang dari total belanja (`paid_idr < total_idr`) menghasilkan error HTTP 422 `TXN_PAYMENT_INSUFFICIENT`.
* **BR-POS-05:** Pembatalan transaksi (*Void*) hanya diizinkan dalam rentang 24 jam setelah transaksi dibuat. Void mengembalikan stok secara otomatis dan mencatat blok pembatalan di blockchain.
* **BR-POS-06:** Transaksi yang berstatus `voided` otomatis dikeluarkan dari seluruh perhitungan omzet dan KPI analitik.
* **BR-POS-07:** Format nomor struk: `TXN-{outlet_id_pendek}-{YYYYMMDD}-{sequence:04d}`.

### 4.5 Blockchain & Integritas Data (BR-INT)
* **BR-INT-01:** Rantai hash bersifat independen per cabang (*per-outlet hash chain*).
* **BR-INT-02:** Formula pembuatan hash:
  * `canonical_json` = JSON transaksi dengan urutan key terurut alfabet tanpa spasi kosong.
  * `data_hash` = SHA-256(`canonical_json`)
  * `block_hash` = SHA-256(`outlet_id` + `block_index` + `data_hash` + `prev_hash`)
* **BR-INT-03:** Blok transaksi pertama (Genesis Block) memiliki `prev_hash` berupa 64 karakter nol (`0000000000000000000000000000000000000000000000000000000000000000`).
* **BR-INT-04:** Indeks blok (`block_index`) harus berurutan rapat tanpa loncatan (gap). Backend menggunakan *PostgreSQL Advisory Lock* per outlet saat pembuatan blok untuk mencegah konflik pada konkurensi tinggi.
* **BR-INT-05:** Jika ada modifikasi ilegal pada data transaksi langsung di database, verifikasi rantai blok menghasilkan status **TAMPERED**. Jika sebuah baris blok dihapus, status menghasilkan **BROKEN_CHAIN**.

### 4.6 Analitik, Konversi & LBS (BR-ANA / LBS)
* **BR-ANA-01:** Perhitungan pergantian hari transaksi pada analitik mengikuti zona waktu lokal masing-masing cabang (`outlets.timezone`), bukan UTC.
* **BR-ANA-02:** Perhitungan pertumbuhan omzet: jika periode pembanding sebelumnya bernilai 0, sistem mengembalikan `null` (aplikasi menampilkan label "Baru").
* **BR-ANA-03:** Rentang filter waktu analitik: tanggal mulai (`from`) harus $\leq$ tanggal selesai (`to`), dengan durasi maksimum 366 hari.
* **BR-LBS-01:** Jarak antara koordinat pengguna dengan cabang wajib dihitung menggunakan formula matematika **Haversine Formula**.
* **BR-LBS-02:** Jika izin lokasi GPS ditolak oleh pengguna HP, peta cabang tetap ditampilkan dengan jarak diberi tanda strip ("—") dan banner imbauan izin lokasi.

### 4.7 Kecerdasan Buatan (BR-AI)
* **BR-AI-01:** LLM dilarang keras mengarang angka (*zero hallucination*). Seluruh angka nominal, persentase, dan kuantitas wajib berasal dari payload fakta (*facts*) yang disuntikkan backend.
* **BR-AI-02:** Respon asisten AI wajib berupa JSON terstruktur dengan tiga kunci: `data` (fakta terverifikasi), `dugaan` (analisis akar masalah), dan `saran` (tindakan yang direkomendasikan).
* **BR-AI-03:** Pertanyaan non-bisnis (lelucon, politik, resep masakan) langsung ditolak oleh backend tanpa memanggil API LLM.
* **BR-AI-04:** Pembatasan frekuensi pertanyaan AI (Rate Limit): maksimum 10 pertanyaan per menit dan 100 pertanyaan per hari per akun.
* **BR-AI-05:** Backend mengimplementasikan cache respon selama 5 menit untuk pertanyaan yang sama. Jika LLM gagal/timeout dua kali, sistem beralih ke *rule-based fallback* deterministik.

---

## 5. Desain Database Lengkap (PostgreSQL & SQLite)

Sistem ARUS menggunakan arsitektur database ramping dan padat: **14 Tabel Inti PostgreSQL (Supabase)** dan **3 Tabel Backup Offline SQLite (`sqflite`)**.

### 5.0 Daftar Final 14 Tabel PostgreSQL & Rationale Perampingan

**4 Tabel yang Dihapus dari Rancangan Awal:**
* ❌ `game_scenarios` — Dihapus karena soal mini-game *"Guess the Menu"* diambil secara dinamis langsung dari tabel master `products` (`image_url`, `name`, `price_idr`).
* ❌ `refresh_tokens` — Dihapus dan disederhanakan menjadi **Stateless JWT (7 hari)** yang disimpan aman di `flutter_secure_storage` dengan perlindungan kunci biometrik perangkat.
* ❌ `exchange_rates` — Dihapus dari cloud DB. Nilai kurs dari Frankfurter API disimpan di in-memory cache backend Express.js dan di-backup ke tabel `local_session_settings` SQLite di HP.
* ❌ `business_insights` — Dihapus dari penyimpanan tabel statis. Mesin aturan bisnis (R1–R8) dievaluasi secara **real-time (*on-the-fly*)** setiap kali endpoint `/api/insights` dipanggil, sehingga data temuan selalu segar (*reactive*) saat demo transaksi baru.

**14 Tabel Inti PostgreSQL yang Dipertahankan:**
1. `users` — Akun pengguna, role RBAC (`owner`, `manager`, `staff`), hash password, dan avatar.
2. `outlets` — Master cabang toko, koordinat LBS (`latitude`, `longitude`), dan zona waktu IANA (`timezone`).
3. `user_outlets` — Relasi penugasan cabang untuk Manager dan Staff (penegakan *outlet scoping*).
4. `feedback` — Formulir testimoni kesan dan saran mata kuliah PAM.
5. `product_categories` — Kategori barang dagangan untuk filter dan navigasi POS.
6. `products` — Katalog master menu/produk POS + kolom `image_url` untuk katalog dan kuis game.
7. `inventory` — Sisa kuantitas stok aktif per cabang beserta batas `reorder_level`.
8. `inventory_movements` — (Dipertahankan) Ledger audit keluar-masuk stok (`sale`, `void_return`, `restock`, `correction`, `waste`).
9. `transactions` — Header struk transaksi penjualan kasir POS, omzet, dan metode bayar.
10. `transaction_items` — Detail barang belanjaan per transaksi dengan snapshot harga jual dan modal.
11. `blockchain_records` — Rantai hash SHA-256 independen per cabang untuk mendeteksi manipulasi struk.
12. `notifications` — Kotak masuk notifikasi stok menipis dan pengumuman sistem.
13. `ai_chat_logs` — Riwayat tanya-jawab konsultasi bisnis dengan asisten AI Gemini.
14. `game_sessions` — Riwayat skor dan capaian permainan kuis *"Guess the Menu"*.

---

### 5.1 Skema Lengkap PostgreSQL (`prisma/schema.prisma`)

Salin skema Prisma lengkap berikut ke `api/prisma/schema.prisma` di backend Express.js:

```prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
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

  outlets       UserOutlet[]
  feedbacks     Feedback[]
  transactions  Transaction[]
  movements     InventoryMovement[]
  notifications Notification[]
  ai_logs       AiChatLog[]
  game_sessions GameSession[]

  @@map("users")
}

model Outlet {
  id         String       @id @default(uuid()) @db.Uuid
  name       String       @unique @db.VarChar(100)
  address    String       @db.Text
  latitude   Decimal      @db.Decimal(9, 6)
  longitude  Decimal      @db.Decimal(9, 6)
  timezone   String       @default("Asia/Jakarta") @db.VarChar(40)
  is_active  Boolean      @default(true)
  created_at DateTime     @default(now()) @db.Timestamptz()
  updated_at DateTime     @updatedAt @db.Timestamptz()

  users        UserOutlet[]
  inventory    Inventory[]
  transactions Transaction[]
  blocks       BlockchainRecord[]

  @@map("outlets")
}

model UserOutlet {
  user_id   String @db.Uuid
  outlet_id String @db.Uuid

  user      User   @relation(fields: [user_id], references: [id], onDelete: Cascade)
  outlet    Outlet @relation(fields: [outlet_id], references: [id], onDelete: Cascade)

  @@id([user_id, outlet_id])
  @@map("user_outlets")
}

model Feedback {
  id         String   @id @default(uuid()) @db.Uuid
  user_id    String   @db.Uuid
  kesan      String   @db.Text
  saran      String   @db.Text
  created_at DateTime @default(now()) @db.Timestamptz()

  user       User     @relation(fields: [user_id], references: [id], onDelete: Cascade)

  @@map("feedback")
}

// ==========================================
// MODUL 2: KATALOG & INVENTARIS (DENGAN MUTASI)
// ==========================================

model ProductCategory {
  id         String    @id @default(uuid()) @db.Uuid
  name       String    @unique @db.VarChar(80)
  created_at DateTime  @default(now()) @db.Timestamptz()

  products   Product[]

  @@map("product_categories")
}

model Product {
  id          String           @id @default(uuid()) @db.Uuid
  category_id String?          @db.Uuid
  sku         String           @unique @db.VarChar(40)
  name        String           @db.VarChar(120)
  image_url   String?          @db.Text // Dipakai untuk Katalog POS & Mini-Game "Guess the Menu"
  unit        String           @default("pcs") @db.VarChar(20)
  price_idr   Int
  cost_idr    Int?
  is_active   Boolean          @default(true)
  created_at  DateTime         @default(now()) @db.Timestamptz()
  updated_at  DateTime         @updatedAt @db.Timestamptz()

  category    ProductCategory?  @relation(fields: [category_id], references: [id])
  inventory   Inventory[]
  txn_items   TransactionItem[]

  @@map("products")
}

model Inventory {
  outlet_id          String   @db.Uuid
  product_id         String   @db.Uuid
  quantity           Int      @default(0)
  reorder_level      Int      @default(5)
  avg_lead_time_days Int      @default(3)
  updated_at         DateTime @updatedAt @db.Timestamptz()

  outlet             Outlet              @relation(fields: [outlet_id], references: [id], onDelete: Cascade)
  product            Product             @relation(fields: [product_id], references: [id], onDelete: Cascade)
  movements          InventoryMovement[]

  @@id([outlet_id, product_id])
  @@map("inventory")
}

model InventoryMovement {
  id             String       @id @default(uuid()) @db.Uuid
  outlet_id      String       @db.Uuid
  product_id     String       @db.Uuid
  movement_type  MovementType
  quantity_delta Int
  quantity_after Int
  transaction_id String?      @db.Uuid
  note           String?      @db.VarChar(255)
  created_by     String       @db.Uuid
  created_at     DateTime     @default(now()) @db.Timestamptz()

  inventory      Inventory    @relation(fields: [outlet_id, product_id], references: [outlet_id, product_id], onDelete: Cascade)
  transaction    Transaction? @relation(fields: [transaction_id], references: [id])
  creator        User         @relation(fields: [created_by], references: [id])

  @@index([outlet_id, product_id, created_at])
  @@map("inventory_movements")
}

// ==========================================
// MODUL 2 & 3: TRANSAKSI POS, BLOCKCHAIN & NOTIF
// ==========================================

model Transaction {
  id                String            @id @default(uuid()) @db.Uuid
  receipt_no        String            @unique @db.VarChar(30)
  outlet_id         String            @db.Uuid
  cashier_id        String            @db.Uuid
  client_request_id String            @unique @db.Uuid
  subtotal_idr      Int
  discount_idr      Int               @default(0)
  total_idr         Int
  payment_method    PaymentMethod
  paid_idr          Int
  change_idr        Int               @default(0)
  status            TxnStatus         @default(completed)
  created_at        DateTime          @default(now()) @db.Timestamptz()

  outlet            Outlet              @relation(fields: [outlet_id], references: [id])
  cashier           User                @relation(fields: [cashier_id], references: [id])
  items             TransactionItem[]
  movements         InventoryMovement[]
  blockchain_record BlockchainRecord?

  @@index([outlet_id, created_at])
  @@map("transactions")
}

model TransactionItem {
  id                    String      @id @default(uuid()) @db.Uuid
  transaction_id        String      @db.Uuid
  product_id            String      @db.Uuid
  product_name_snapshot String      @db.VarChar(120)
  unit_price_idr        Int
  unit_cost_idr         Int?
  quantity              Int
  line_total_idr        Int

  transaction           Transaction @relation(fields: [transaction_id], references: [id], onDelete: Cascade)
  product               Product     @relation(fields: [product_id], references: [id])

  @@map("transaction_items")
}

model BlockchainRecord {
  id             String      @id @default(uuid()) @db.Uuid
  outlet_id      String      @db.Uuid
  block_index    Int
  transaction_id String      @unique @db.Uuid
  data_hash      String      @db.Char(64)
  prev_hash      String      @db.Char(64)
  block_hash     String      @db.Char(64)
  created_at     DateTime    @default(now()) @db.Timestamptz()

  outlet         Outlet      @relation(fields: [outlet_id], references: [id])
  transaction    Transaction @relation(fields: [transaction_id], references: [id])

  @@unique([outlet_id, block_index])
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

  user       User     @relation(fields: [user_id], references: [id], onDelete: Cascade)

  @@map("notifications")
}

// ==========================================
// MODUL 5: AI ASSISTANT & MINI GAME "GUESS THE MENU"
// ==========================================

model AiChatLog {
  id          String   @id @default(uuid()) @db.Uuid
  user_id     String   @db.Uuid
  question    String   @db.Text
  answer_json Json
  facts_used  Json
  created_at  DateTime @default(now()) @db.Timestamptz()

  user        User     @relation(fields: [user_id], references: [id], onDelete: Cascade)

  @@map("ai_chat_logs")
}

model GameSession {
  id              String   @id @default(uuid()) @db.Uuid
  user_id         String   @db.Uuid
  mode            GameMode // 'guess_name' atau 'guess_price'
  score           Int
  correct_count   Int
  total_questions Int      @default(5)
  duration_sec    Int
  played_at       DateTime @default(now()) @db.Timestamptz()

  user            User     @relation(fields: [user_id], references: [id], onDelete: Cascade)

  @@index([user_id, score(sort: Desc)])
  @@map("game_sessions")
}
```

---

### 5.2 Skema DDL SQLite Lokal Flutter (`sqflite`)

Jalankan query DDL berikut di Flutter saat inisialisasi database lokal (`lib/core/storage/local_db.dart`) untuk memenuhi syarat database lokal dan backup offline:

```sql
--- 1. Menyimpan Sesi User, Pengaturan Utilitas & Cache Kurs Terakhir
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
  cached_usd_rate REAL DEFAULT 0.000064,
  cached_eur_rate REAL DEFAULT 0.000059
);

-- 2. Backup Katalog Produk, Gambar & Stok untuk Mode Offline / Mini-Game
CREATE TABLE IF NOT EXISTS backup_products (
  product_id TEXT,
  outlet_id TEXT,
  sku TEXT NOT NULL,
  name TEXT NOT NULL,
  image_url TEXT,
  category_name TEXT,
  price_idr INTEGER NOT NULL,
  stock_quantity INTEGER NOT NULL,
  reorder_level INTEGER NOT NULL,
  last_sync_at TEXT NOT NULL,
  PRIMARY KEY (product_id, outlet_id)
);

-- 3. Backup 50 Struk Terakhir beserta Status Hash Blockchain
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
    "limit": 20,
    "total": 42
  }
}
```

**Respon Error (HTTP 4xx / 5xx):**
```json
{
  "error": {
    "code": "INVENTORY_INSUFFICIENT",
    "message": "Stok produk Kopi Susu (SKU-001) tidak mencukupi.",
    "details": {
      "product_id": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
      "available": 2,
      "requested": 5
    }
  }
}
```

### 6.2 Katalog Endpoint per Modul

#### MOD-1: Autentikasi, Pengguna & Profil
* `POST /api/auth/login` — Autentikasi email & password, mengembalikan Stateless JWT token.
* `POST /api/auth/refresh` — Verifikasi dan perpanjangan sesi token aktif.
* `POST /api/auth/logout` — Pemutusan sesi dan pembersihan token lokal dari storage.
* `GET /api/auth/me` — Profil user saat ini dan status feature flags.
* `PUT /api/auth/change-password` — Mengubah password user saat ini.
* `GET /api/users` — [Owner] Daftar semua user beserta penugasan cabang.
* `POST /api/users` — [Owner] Mendaftarkan user baru.
* `PUT /api/users/:id` — [Owner] Memperbarui status / cabang user.
* `DELETE /api/users/:id` — [Owner] Menonaktifkan user (`is_active = false`).
* `POST /api/feedback` — Mengirimkan form kesan & saran PAM.

#### MOD-2: Operasional (Katalog, Inventaris & POS)
* `GET /api/catalog/products` — Daftar produk aktif (filter: `q`, `category_id`, `status`).
* `POST /api/catalog/products` — [Owner, Manager] Menambah produk baru.
* `PUT /api/catalog/products/:id` — [Owner, Manager] Memperbarui produk.
* `DELETE /api/catalog/products/:id` — [Owner, Manager] Menonaktifkan produk.
* `GET /api/catalog/categories` — Daftar kategori produk.
* `POST /api/catalog/categories` — [Owner, Manager] Menambah kategori baru.
* `GET /api/inventory` — Monitoring stok cabang saat ini.
* `POST /api/inventory/adjustments` — [Owner, Manager] Restock/koreksi/waste stok.
* `GET /api/inventory/movements` — Riwayat audit mutasi keluar-masuk barang.
* `GET /api/inventory/low-stock` — Daftar barang dengan kuantitas $\leq$ `reorder_level`.
* `POST /api/transactions` — Membuat transaksi penjualan POS atomik (idempoten via `client_request_id`).
* `GET /api/transactions` — Riwayat transaksi (Staff: hanya cabang sendiri & hari ini).
* `GET /api/transactions/:id` — Detail struk transaksi lengkap.
* `POST /api/transactions/:id/void` — [Owner, Manager] Membatalkan transaksi ($\leq$ 24 jam).
* `GET /api/search?q=` — Pencarian global (produk, transaksi, cabang).

#### MOD-3: Blockchain & Notifikasi Mobile
* `GET /api/integrity/verify/:transactionId` — Verifikasi hash satu transaksi (VALID / TAMPERED).
* `GET /api/integrity/chain/:outletId` — [Owner, Manager] Audit keutuhan seluruh rantai blok cabang.
* `GET /api/notifications` — Daftar kotak masuk notifikasi user.
* `POST /api/notifications/:id/read` — Menandai notifikasi telah dibaca.
* `POST /api/notifications/read-all` — Menandai semua notifikasi telah dibaca.
* `GET /api/notifications/count` — Mengambil jumlah notifikasi yang belum dibaca.

#### MOD-4: Dashboard Analitik, Konversi & LBS
* `GET /api/analytics/overview` — [Owner, Manager] KPI total omzet, transaksi, ATV, dan pertumbuhan.
* `GET /api/analytics/sales` — [Owner, Manager] Data grafik tren penjualan (`daily`, `weekly`, `monthly`).
* `GET /api/analytics/products` — [Owner, Manager] Produk terlaris (*top-selling*) dan barang mati (*slow-moving*).
* `GET /api/analytics/peak-hours` — [Owner, Manager] Jam-jam paling ramai transaksi.
* `GET /api/outlets` — Daftar cabang beserta koordinat latitude/longitude.
* `POST /api/outlets` — [Owner] Menambah cabang baru.
* `PUT /api/outlets/:id` — [Owner] Memperbarui koordinat/alamat cabang.
* `GET /api/outlets/nearest` — Cabang terdekat berdasarkan koordinat GPS pengguna.
* `GET /api/outlets/performance` — [Owner, Manager] Indeks performa penjualan cabang.
* `GET /api/fx/rates` — Kurs mata uang terbaru (IDR, USD, EUR) dari in-memory cache backend.
* `GET /api/settings` — Mengambil preferensi user (currency, timezone, sensor, biometrik).
* `PUT /api/settings` — Memperbarui preferensi user.

#### MOD-5: Kecerdasan Buatan & Mini Game
* `GET /api/insights` — [Owner, Manager] Evaluasi real-time (*on-the-fly*) mesin aturan bisnis (R1–R8) terhadap data stok & transaksi terkini.
* `GET /api/insights/:id` — [Owner, Manager] Detail temuan aturan dan bukti angka (*evidence*).
* `POST /api/insights/:id/dismiss` — [Owner, Manager] Mengabaikan rekomendasi insight.
* `POST /api/ai/ask` — [Owner, Manager] Tanya jawab bisnis ke LLM Gemini (format: Data, Dugaan, Saran).
* `GET /api/ai/conversations` — Riwayat tanya jawab chat AI.
* `DELETE /api/ai/conversations/:id` — Menghapus percakapan AI.
* `GET /api/game/questions` — Membangkitkan 5 soal kuis mini-game *"Guess the Menu"* secara dinamis dari tabel `products`.
* `POST /api/game/sessions` — Mengirimkan hasil jawaban kuis tebak menu/harga dan menyimpan skor ke `game_sessions`.
* `GET /api/game/sessions` — Riwayat skor permainan dan capaian user.

---

## 7. Aturan Keamanan (Security Requirements)

1. **Penyimpanan Token:** Token autentikasi JWT wajib disimpan menggunakan `flutter_secure_storage` pada platform mobile (menggunakan Android Keystore / iOS Keychain). Dilarang keras menyimpan token pada `SharedPreferences` atau logcat console.
2. **Kueri Terparameter:** Seluruh interaksi database wajib menggunakan Prisma ORM atau parameterized query. Dilarang menggabungkan string mentah (*raw string concatenation*) untuk mencegah celah SQL Injection.
3. **Rahasia Sistem (Secrets):** Kunci rahasia JWT, API Key Gemini, dan connection string Supabase hanya berada di file backend `.env`. Aplikasi Flutter tidak boleh menyimpan rahasia backend apapun di dalam source code.
4. **Sanitasi Log:** Dilarang mencetak password plaintext, refresh token, atau data pribadi nasabah pada log server (Pino logger).
5. **Rate Limiting:**
   * Login endpoint: Max 5 percobaan / 15 menit per IP.
   * AI Assistant: Max 10 request / menit per user.
   * General API: Max 100 request / 15 menit per IP.

---

## 8. Panduan Pre-Production & Setup

### 8.1 File Konfigurasi Environment (`api/.env`)
Pastikan file `.env` di folder `api/` terisi lengkap sesuai contoh:

```env
NODE_ENV=development
PORT=3000
DATABASE_URL=postgresql://postgres.xxx:pass@aws-0-ap-southeast-1.pooler.supabase.com:6543/postgres?pgbouncer=true
JWT_ACCESS_SECRET=super_secret_jwt_access_key_min_32_chars_long!
JWT_ACCESS_TTL_SEC=900
REFRESH_TTL_DAYS=7
LLM_PROVIDER=gemini
LLM_API_KEY=AIzaSyYourGeminiApiKeyHere
LLM_MODEL=gemini-1.5-flash
AI_RATE_PER_MIN=10
AI_RATE_PER_DAY=100
FX_API_URL=https://api.frankfurter.dev/v1/latest?base=IDR&symbols=USD,EUR
FEATURE_INTEGRITY=true
FEATURE_NOTIFICATIONS=true
FEATURE_FX=true
FEATURE_GAME=true
FEATURE_AI=true
LOG_LEVEL=info
```

### 8.2 Inisialisasi Database & Seeding
Jalankan perintah berikut di direktori `api/`:
```bash
npx prisma generate
npx prisma migrate deploy
npm run db:seed
```

Data seed minimal mencakup:
* 3 akun pengguna: Owner (`owner@arus.com`), Manager (`manager@arus.com`), Staff (`staff@arus.com`) password `Password123!`.
* 4 outlet: 3 outlet di Indonesia (Jakarta - WIB, Makassar - WITA, Jayapura - WIT) dan 1 outlet di London (`Europe/London`).
* 40 produk terbagi ke dalam 5 kategori dengan field `image_url` terisi untuk katalog dan kuis.
* 90 hari riwayat transaksi untuk kalkulasi KPI analitik dan audit mutasi stok.

---

## 9. Aturan Production & Hard Forbids

Setiap pengembang (manusia maupun AI coding assistant) wajib mematuhi **15 Larangan Keras (Hard Forbids)** berikut:

1. **[F1]** DILARANG mengakses database online langsung dari Flutter (wajib melalui REST API Express).
2. **[F2]** DILARANG menaruh logika bisnis pada widget UI Flutter.
3. **[F3]** DILARANG menggunakan tipe data `any` (TypeScript) atau `dynamic` (Dart) tanpa penjelasan komentar.
4. **[F4]** DILARANG melakukan cross-feature import antar fitur Flutter kecuali melalui `core/` dan `shared/`.
5. **[F5]** DILARANG mengubah formula hash blockchain atau format canonical JSON yang sudah berjalan.
6. **[F6]** DILARANG mengedit manual file migrasi Prisma yang sudah diaplikasikan di database.
7. **[F7]** DILARANG membocorkan secret/kunci API ke dalam source code atau git repository.
8. **[F8]** DILARANG menyimpan token sesi di `SharedPreferences` biasa.
9. **[F9]** DILARANG menampilkan stack trace exception mentah ke hadapan pengguna aplikasi.
10. **[F10]** DILARANG memanggil sensor atau GPS langsung dari fungsi `build()` Flutter.
11. **[F11]** DILARANG menggunakan perhitungan floating-point untuk nilai mata uang rupiah.
12. **[F12]** DILARANG menambah dependensi package baru tanpa justifikasi tertulis.
13. **[F13]** DILARANG mengubah keputusan arsitektur secara diam-diam tanpa memperbarui SRS v2 ini.
14. **[F14]** DILARANG menjalankan query SQL mentah dinamis yang digenerate oleh AI LLM.
15. **[F15]** DILARANG melakukan *hard delete* pada tabel transaksi, pergerakan stok, dan rekam blockchain.

---

## 10. Panduan Post-Production, Cron & Maintenance

### 10.1 Tugas Terjadwal (Cron Jobs) & Background Tasks
Backend mengeksekusi tugas otomatis berikut menggunakan `node-cron`:
1. **FX Rate In-Memory Sync (Daily 06:00 UTC):** Mengambil nilai tukar mata uang terbaru dari Frankfurter API dan memperbarui cache in-memory Express.js serta diteruskan ke SQLite lokal HP (tanpa membebani DB cloud).
2. **Notification Cleanup (Monthly):** Menghapus notifikasi terbaca yang sudah berusia lebih dari 30 hari.
*(Catatan: Business Insights R1–R8 tidak memerlukan cron statis karena dihitung secara real-time / on-the-fly saat endpoint dipanggil).*

### 10.2 Skrip Demo Presentasi
Tersedia skrip otomatis di backend untuk kebutuhan pengujian dan presentasi dosen:
* `npm run demo:reset` — Menyetel ulang seluruh data database ke kondisi awal yang bersih.
* `npm run demo:tamper <transaction_id>` — Melakukan manipulasi ilegal pada kolom `total_idr` di PostgreSQL untuk mendemonstrasikan status **TAMPERED** pada audit blockchain di HP.

---

## 11. Panduan UI/UX & Standar Widget Mobile

* **Material Design 3:** Tampilan wajib konsisten mengikuti token Material 3 dari `lib/core/theme/`.
* **State Management:** Setiap layar yang mengambil data online wajib menggunakan widget pembungkus `AsyncStateView` dengan 4 penanganan state: *Loading Skeleton*, *Success View*, *Empty State*, dan *Error State*.
* **Format Mata Uang:** Menampilkan uang selalu melalui utilitas `MoneyFormatter.format(amount)` yang mendukung IDR, USD, dan EUR.
* **Ukuran Target Sentuh:** Tombol navigasi dan aksi kasir memiliki ukuran target sentuh minimal **48 x 48 dp** dengan ukuran font teks minimal **14 sp**.
* **Konfirmasi Aksi Destruktif:** Aksi seperti *Void Transaksi*, *Logout*, dan *Dismiss Insight* wajib memunculkan dialog konfirmasi (*Confirmation Modal*).

---

## 12. Feature Flags & Degradasi Fitur

Aplikasi mendukung *graceful degradation* melalui environment variable di backend yang dikirimkan ke aplikasi saat startup (`GET /api/auth/me`):

| Nama Flag | Kontrol Fitur | Respon Jika Dinonaktifkan (`false`) |
|---|---|---|
| `FEATURE_INTEGRITY` | Rantai Hash Blockchain | Transaksi POS tetap berjalan normal; menu audit disembunyikan |
| `FEATURE_NOTIFICATIONS` | Notifikasi Stok Menipis | Server tidak memicu trigger notifikasi; lonceng disembunyikan |
| `FEATURE_FX` | Konversi Multi-Currency | Nilai mata uang terkunci ke IDR; pemilih kurs disembunyikan |
| `FEATURE_GAME` | Mini Game Tantangan Bisnis | Menu game disembunyikan dari tab navigasi |
| `FEATURE_AI` | Chatbot Bisnis Gemini | Jawaban dialihkan ke fallback aturan lokal deterministik |

---

## 13. Konvensi Kode & Struktur Direktori

### 13.1 Standar Penamaan
* **Dart (Flutter):**
  * File & Direktori: `snake_case` (contoh: `pos_screen.dart`, `cart_notifier.dart`)
  * Kelas & Enums: `PascalCase` (contoh: `TransactionRepository`, `StockStatus`)
  * Riverpod Providers: `camelCase` diakhiri Provider (contoh: `cartProvider`)
* **TypeScript (Express):**
  * File & Direktori: `kebab-case` (contoh: `transactions.service.ts`)
  * Fungsi & Variabel: `camelCase` (contoh: `calculateTotalRevenue`)
  * Tabel & Kolom Database: `snake_case` (contoh: `transaction_items`, `unit_price_idr`)

### 13.2 Struktur Folder Monorepo
```text
arus/
├── app/                           # Proyek Flutter Mobile
│   ├── lib/
│   │   ├── core/                  # Network, storage, routing, theme, utilitas
│   │   ├── shared/                # Widget global (AsyncStateView, MoneyText)
│   │   └── features/              # UI & State per fitur (auth, pos, dashboard, dll)
│   └── test/                      # Unit & Widget Test Flutter
│
├── api/                           # Proyek Express.js REST API
│   ├── src/
│   │   ├── config/                # Environment & Logger
│   │   ├── middleware/            # Auth, RBAC, Validator, Rate Limit
│   │   ├── modules/               # Controller, Service, & Route per domain
│   │   └── shared/                # Utilitas hash, canonical JSON, error handler
│   ├── prisma/                    # Skema database & file migrasi
│   ├── scripts/                   # Skrip demo tamper & seed
│   └── tests/                     # Unit & Integration Test API
└── arus_srs_v2.md                 # Master Dokumen Acuan Tunggal
```

---

## 14. Strategi Pengujian & Skenario Demo

### 14.1 Matriks Uji Inti (Core Test Matrix)

| Kode Uji | Skenario yang Diuji | Hasil yang Diharapkan |
|---|---|---|
| **T-AUTH-01** | Login dengan email & password valid | Berhasil 200 OK, menerima token JWT dan role pengguna |
| **T-AUTH-03** | Percobaan login salah 5x berturut-turut | Akun terkunci, request ke-6 menghasilkan HTTP 423 |
| **T-AUTH-07** | Buka kunci aplikasi dengan sidik jari (biometrik) | Berhasil masuk ke Beranda tanpa meminta input password |
| **T-CAT-01** | Input produk dengan kode SKU yang sudah ada | Ditolak dengan respon HTTP 409 `CATALOG_SKU_DUPLICATE` |
| **T-INV-02** | Dua kasir menjual barang sisa 1 secara bersamaan | 1 transaksi berhasil, 1 transaksi ditolak `INSUFFICIENT` |
| **T-POS-01** | Input penjualan kasir tunai dengan uang cukup | Berhasil 201 Created, stok terpotong, struk tercatat |
| **T-POS-04** | Client memodifikasi harga produk di payload HTTP | Server mengabaikan harga client dan memakai harga DB |
| **T-POS-05** | Void transaksi oleh Manager dalam 24 jam | Transaksi dibatalkan, stok dikembalikan, tercatat blok void |
| **T-INT-01** | Verifikasi keaslian struk normal | Menghasilkan status **VALID** dengan kecocokan hash SHA-256 |
| **T-INT-03** | Verifikasi struk setelah kolom `total_idr` diubah | Menghasilkan status **TAMPERED** secara seketika |
| **T-NOT-01** | Transaksi kasir membuat sisa stok $\leq$ reorder level | Muncul notifikasi lokal stok menipis di perangkat HP |
| **T-CUR-01** | Mengubah pilihan mata uang ke USD di dashboard | Nilai rupiah terkonversi akurat sesuai kurs Frankfurter |
| **T-TZ-01** | Melihat jam transaksi pada cabang London | Timestamp terkonversi otomatis ke jam lokal London |
| **T-SEN-01** | Menggoyangkan HP di Dashboard (*Accelerometer*) | Dashboard memuat ulang data analitik terbaru dari server |
| **T-SEN-03** | Memiringkan HP (*Gyroscope*) pada grafik analitik | Filter rentang waktu grafik berganti secara otomatis |
| **T-LBS-01** | Membuka peta lokasi cabang | Menampilkan titik cabang dan jarak km dari posisi GPS user |
| **T-AI-01** | Mengajukan pertanyaan kondisi penjualan ke AI | AI menjawab dengan format: Data, Dugaan, dan Saran |
| **T-GAME-01**| Menyelesaikan 5 soal kuis tebak menu/harga ("Guess the Menu") | Skor tersimpan di tabel `game_sessions` dan muncul di riwayat game |

---

### 14.2 Skenario Demo Penerimaan (10 Langkah UAT)

1. **Pemanasan Server:** Nyalakan backend Express dan login sebagai **Owner**; verifikasi metrik dashboard terisi dari 90 hari riwayat transaksi.
2. **Uji Konversi Utilitas:** Ubah preferensi mata uang ke **USD** dan zona waktu ke **London**; saksikan angka omzet dan jam transaksi menyesuaikan secara realtime.
3. **Operasional Kasir & Notifikasi:** Login sebagai **Staff** di HP kedua; lakukan transaksi barang hingga menyentuh batas minimum; amati stok terpotong dan notifikasi stok menipis muncul di HP Manager/Owner.
4. **Interaksi Sensor:** Goyangkan HP (*shake*) untuk memperbarui data dashboard; miringkan HP (*tilt*) untuk mengubah periode grafik analitik.
5. **Decision Support & Bukti Data:** Buka menu Insights; periksa temuan stok kritis atau penurunan omzet lengkap beserta bukti data angkanya (dihitung *on-the-fly* secara real-time).
6. **Konsultasi AI Cerdas:** Tanyakan *"Produk apa yang perlu direstock?"* ke AI Assistant; periksa respon terstruktur **Data / Dugaan / Saran** yang angkanya cocok dengan dashboard.
7. **Peta Cabang & LBS:** Buka Peta Cabang; periksa titik lokasi cabang, indikator warna performa, dan kalkulasi jarak terdekat dari GPS perangkat.
8. **Audit Keaslian Blockchain:** Buka detail struk terbaru; klik tombol audit blockchain $\rightarrow$ status **VALID**. Jalankan skrip `npm run demo:tamper` di backend, refresh struk $\rightarrow$ status berubah menjadi **TAMPERED**.
9. **Mini Game Guess the Menu:** Buka menu Game; tebak nama menu dan harga dari foto produk toko nyata; periksa kalkulasi skor akhir dan sistem poinnya.
10. **Pengujian Biometrik:** Tutup aplikasi, buka kembali dari latar belakang; lakukan pemindaian sidik jari untuk membuka sesi secara instan.

---

## 15. Pembagian Tugas Tim & Traceability Matrix

### 15.1 Pembagian Tanggung Jawab Tim (3 Anggota)

* **Anggota 1 — Backend Web Service, Database & Blockchain:**
  * Skema Prisma PostgreSQL (Supabase 14 tabel) & Seeding data 90 hari.
  * Autentikasi Stateless JWT (argon2), RBAC, dan Outlet Scoping.
  * API Katalog, Inventaris, dan Transaksi Kasir POS atomik.
  * Implementasi rantai hash **Blockchain SHA-256** & endpoint verifikasi integritas.
  * Kueri SQL agregasi untuk **Dashboard Analitik KPI**.

* **Anggota 2 — Flutter Core UI, SQLite Lokal & Utilitas Mobile:**
  * Kerangka navigasi multi-role (Bottom Navigation 4 & 5 tab).
  * Layar Login & integrasi **Biometric Unlock (`local_auth`)**.
  * Layar Profil bergambar & **Form Kesan/Saran Matkul PAM**.
  * Layar Kasir POS & keranjang belanja interaktif.
  * Sinkronisasi **Backup Offline SQLite (`sqflite`)**.
  * Widget **Konversi Mata Uang (IDR/USD/EUR)** & **Zona Waktu**.
  * Integrasi **Notifikasi Lokal (`flutter_local_notifications`)**.

* **Anggota 3 — Fitur Spesial (Sensor, LBS Peta, AI/LLM & Mini Game):**
  * Deteksi sensor **Accelerometer (Shake)** & **Gyroscope (Tilt)** via `sensors_plus`.
  * Layar **Peta Cabang LBS** (`flutter_map`) & kalkulasi jarak GPS (`geolocator`).
  * Integrasi **ARUS AI Business Assistant** dengan Google Gemini API.
  * Mesin aturan **Decision Support (Insights)** R1–R8 (evaluasi *on-the-fly*).
  * Desain antarmuka & logika generator soal **Mini Game (*Guess the Menu*)**.

---

### 15.2 Requirement Traceability Matrix (Pemetaan 27 Fitur)

| No | Nama Fitur | Modul | Berkas Implementasi Utama | Kriteria Dosen PAM | Kode Uji |
|:---:|---|:---:|---|---|:---:|
| 1 | Login Enkripsi | MOD-1 | `auth.service.ts` · `login_screen.dart` | Login Enkripsi Non-Firebase | T-AUTH-01 |
| 2 | Sesi JWT & SQLite | MOD-1 | `auth.ts` · `secure_store.dart` | Manajemen Sesi Aplikasi | T-AUTH-04 |
| 3 | Login Biometrik | MOD-1 | `biometric_service.dart` · `splash_screen.dart` | Login Sensor Biometrik | T-AUTH-07 |
| 4 | Profil Bergambar | MOD-1 | `profile_screen.dart` | Bottom Nav: Profil Bergambar | T-RBAC-01 |
| 5 | Kesan & Saran PAM | MOD-1 | `feedback_screen.dart` · `feedback.service.ts` | Bottom Nav: Menu Saran PAM | T-RBAC-01 |
| 6 | Menu Logout | MOD-1 | `auth_notifier.dart` | Bottom Nav: Menu Logout | T-AUTH-04 |
| 7 | Manajemen User | MOD-1 | `users_screen.dart` · `users.service.ts` | Multi-Role Access Control | T-RBAC-05 |
| 8 | Master Produk | MOD-2 | `catalog_screen.dart` · `catalog.service.ts` | API Web Service & Online DB | T-CAT-01 |
| 9 | Cari & Filter Katalog | MOD-2 | `search_bar.dart` · `catalog.controller.ts` | Fasilitas Pencarian & Pemilihan | T-CAT-03 |
| 10 | Backup Offline SQLite | MOD-2 | `local_db.dart` (`backup_products`) | Database Lokal SQLite & Online | T-DB-02 |
| 11 | Filter Status Stok | MOD-2 | `inventory_screen.dart` | Fasilitas Pemilihan & Filter | T-INV-04 |
| 12 | Penyesuaian Stok | MOD-2 | `stock_adjustment_dialog.dart` | Decision Support Inventaris | T-INV-03 |
| 13 | Kasir Mobile POS | MOD-2 | `pos_screen.dart` · `transactions.service.ts` | Konsep Proyek Akhir (POS) | T-POS-01 |
| 14 | Cari Struk & SQLite | MOD-2 | `local_db.dart` (`backup_transactions`) | Pencarian + DB Lokal SQLite | T-POS-02 |
| 15 | Void Transaksi | MOD-2 | `transactions.service.ts` (`voidTransaction`) | Integritas Data Transaksi | T-POS-05 |
| 16 | Hash Blockchain | MOD-3 | `integrity.service.ts` | Fitur Blockchain Sederhana | T-INT-01 |
| 17 | Audit Tamper Check | MOD-3 | `integrity_screen.dart` | Fitur Blockchain Sederhana | T-INT-03 |
| 18 | Notifikasi Stok Tipis | MOD-3 | `notification_service.dart` | Notifikasi Mobile Sesuai Konsep | T-NOT-01 |
| 19 | Dashboard Analitik | MOD-4 | `dashboard_screen.dart` · `analytics.service.ts` | Business Intelligence & Charts | T-ANA-01 |
| 20 | Konversi 3 Kurs | MOD-4 | `money_formatter.dart` · `fx.service.ts` | Konversi Mata Uang (IDR, USD, EUR) | T-CUR-01 |
| 21 | Konversi 4 Waktu | MOD-4 | `timezone_converter.dart` | Konversi 4 Zona Waktu | T-TZ-01 |
| 22 | Sensor Accelerometer | MOD-4 | `sensor_service.dart` (Shake Detection) | Sensor 1: Accelerometer | T-SEN-01 |
| 23 | Sensor Gyroscope | MOD-4 | `sensor_service.dart` (Tilt Detection) | Sensor 2: Gyroscope | T-SEN-03 |
| 24 | Peta LBS & Haversine | MOD-4 | `outlet_map_screen.dart` · `outlets.service.ts` | Web Service & Fasilitas LBS | T-LBS-01 |
| 25 | Decision Support | MOD-5 | `insights.service.ts` (Rules R1–R8) | AI Sesuai Konsep Tema | T-DS-01 |
| 26 | Chatbot AI Gemini | MOD-5 | `ai.service.ts` · `ai_chat_screen.dart` | Fitur AI & LLM Sesuai Tema | T-AI-01 |
| 27 | Mini Game Guess Menu | MOD-5 | `game_screen.dart` · `game.service.ts` | Mini Games Terkait Konsep | T-GAME-01 |

---

*Akhir Dokumen — ARUS SRS v2 Master Single Source of Truth.*
