# ARUS MASTER UNDERSTAND — Global System Architecture & AI Context Anchor

> **DOKUMEN INDUK SISTEM (LEVEL 0 — GLOBAL CONTEXT)**  
> **Status:** Single Source of Truth untuk Seluruh Anggota Tim & Asisten AI (Antigravity / LLM).  
> **Tujuan:** Memberikan pemahaman arsitektur menyeluruh (*system mental model*) dari hulu ke hilir sebelum AI atau anggota tim mengunci fokus ke berkas perorangan (`ORANG_1.md`, `ORANG_2.md`, `ORANG_3.md`).

---

## 1. Protokol Ingesti AI (AI System Ingestion Protocol)

Jika Anda adalah asisten AI (Antigravity / LLM) yang mendampingi salah satu anggota tim:
1. **Wajib Baca Dokumen Ini Dahulu:** Pahami arsitektur global, aliran data end-to-end, dan relasi database sebelum menjawab pertanyaan spesifik.
2. **Keterikatan Codebase:** Sistem ARUS **bukan konsep teoritis semata**, melainkan aplikasi *production-grade* yang sudah terimplementasi di direktori project ini (`c:\MyProjects\arus`). Setiap penjelasan wajib merujuk pada berkas nyata di `lib/` (Flutter) dan `api/src/` (Express.js).
3. **Kepatuhan Kriteria Dosen PAM:** Aplikasi ini dibangun untuk memenuhi 17 kriteria mata kuliah *Pemrograman Aplikasi Mobile*, termasuk larangan penggunaan Firebase (menggunakan custom Express REST API + PostgreSQL Supabase), penyimpanan ganda (Cloud + SQLite offline), sensor perangkat keras, blockchain sederhana, LBS peta, dan kecerdasan buatan.

---

## 2. Gambaran Sistem & Identitas Produk (Executive Summary)

* **Nama Proyek:** ARUS (*Mobile Business Decision-Support System & Multi-Outlet POS*)
* **Domain Bisnis:** Food & Beverage (F&B) serta Ritel Multi-Cabang.
* **Problem yang Diselesaikan:**
  - Kasir di lapangan sering mengalami gangguan sinyal/internet mati, sehingga operasional kasir konvensional terhenti.
  - Pemilik bisnis (*Owner*) kesulitan memantau stok bahan mentah dan mendeteksi kecurangan (*fraud*) manipulasi data transaksi di database.
  - Pengambilan keputusan bisnis (restock, menu kurang laku) seringkali terlambat dan tidak berbasis data analitik riil.
* **Solusi ARUS:**
  - **Offline-First POS:** Kasir tetap bisa melayani checkout saat internet mati berkat antrean lokal SQLite (`sqflite`) yang disinkronisasi otomatis saat online kembali.
  - **Recipe-Based Inventory:** Menghubungkan menu jualan (`products`) dengan bahan baku gudang (`ingredients`) via takaran resep (`product_recipes`), dengan estimasi porsi dinamis.
  - **Integritas Blockchain SHA-256:** Rantai hash kriptografis per transaksi untuk mendeteksi manipulasi data struk di database server (*tamper proofing*).
  - **Decision Support & AI Copilot:** Mesin aturan analitik deterministik dan asisten cerdas Google Gemini yang *grounded* pada angka database riil, didukung interaksi suara (*Voice TTS/STT*).

---

## 3. Diagram Arsitektur Global & Aliran Data

```text
                     ┌────────────────────────────────────────────────────────┐
                     │              FLUTTER MOBILE CLIENT (Android)           │
                     │  - State Management: Riverpod                          │
                     │  - Local DB: SQLite (sqflite: 7 Tabel & Offline Queue) │
                     │  - Hardware: Sensors (Shake/Tilt), Biometrics, GPS     │
                     └───────────┬────────────────────────────────┬───────────┘
                                 │                                │
                (1) HTTPS REST   │                                │ (2) Direct Public
                    JSON API     │                                │     Web Services
                                 ▼                                ▼
┌─────────────────────────────────────────────────┐   ┌───────────────────────────┐
│       EXPRESS.JS BACKEND API (TypeScript)       │   │   PUBLIC WEB SERVICES     │
│  - Security: argon2id, JWT Family Rotation      │   ├───────────────────────────┤
│  - Middleware: Auth, RBAC, Outlet Scoping       │   │ • Frankfurter API (Kurs)  │
│  - Integrity: SHA-256 Blockchain & Tamper Check │   │ • OpenStreetMap (Tiles)   │
│  - AI Grounding Engine & Edge TTS (GadisNeural) │   └───────────────────────────┘
└───────────┬─────────────────────────┬───────────┘
            │                         │
            │ Prisma ORM              │ LLM Query with Factual Context
            ▼                         ▼
┌─────────────────────────┐   ┌───────────────────────────┐
│  PostgreSQL (Supabase)  │   │     Google Gemini API     │
│   (17 Model Relasional) │   │   (Business Copilot LLM)  │
└─────────────────────────┘   └───────────────────────────┘
```

### Pipeline Aliran Data Transaksi:
1. **Input Kasir di Flutter:** Kasir memilih menu -> Flutter menghitung estimasi porsi dari cache lokal / server.
2. **Kondisi Online:** Request dikirim ke `POST /api/pos/checkout` -> Express memverifikasi JWT & outlet scope -> Prisma `$transaction` memotong stok di `ingredients`, mencatat mutasi di `inventory_movements`, menyimpan struk di `transactions`, dan mencetak blok hash di `blockchain_records`.
3. **Kondisi Offline (Putus Sinyal):** Request disimpan ke tabel SQLite `offline_transactions` dengan UUID `client_request_id`. Ketika koneksi pulih, `sync_service.dart` mengirimkan antrean ke server secara idempoten (tanpa duplikasi).

---

## 4. Matriks 5 Modul & 27 Fitur Sistem (Kriteria Dosen PAM)

| Kode | Modul & Nama Fitur | Berkas Implementasi Utama | Kriteria Dosen PAM | PIC Utama |
| :---: | :--- | :--- | :--- | :---: |
| **MOD-1** | **Autentikasi, Keamanan & Profil** | | | |
| 1 | Login Enkripsi Password | [`api/src/modules/auth/auth.service.ts`](file:///c:/MyProjects/arus/api/src/modules/auth/auth.service.ts) | Login Enkripsi Non-Firebase | **Orang 1** |
| 2 | Session JWT & Token Rotation | [`api/src/shared/jwt.ts`](file:///c:/MyProjects/arus/api/src/shared/jwt.ts) & [`api/src/shared/tokens.ts`](file:///c:/MyProjects/arus/api/src/shared/tokens.ts) | Manajemen Sesi & Token | **Orang 1** |
| 3 | Login Biometrik (Sidik Jari/Wajah) | [`lib/core/auth/biometric_service.dart`](file:///c:/MyProjects/arus/lib/core/auth/biometric_service.dart) | Sensor Biometrik | **Orang 2** |
| 4 | Profil Akun Bergambar | [`lib/features/profile/presentation/profile_screen.dart`](file:///c:/MyProjects/arus/lib/features/profile/presentation/profile_screen.dart) | Bottom Nav: Profil Bergambar | **Orang 2** |
| 5 | Menu Kesan & Saran Matkul PAM | [`lib/features/feedback/presentation/feedback_screen.dart`](file:///c:/MyProjects/arus/lib/features/feedback/presentation/feedback_screen.dart) | Bottom Nav: Saran PAM | **Orang 3** |
| 6 | Menu Logout & Token Revocation | [`lib/features/auth/presentation/auth_provider.dart`](file:///c:/MyProjects/arus/lib/features/auth/presentation/auth_provider.dart) | Bottom Nav: Menu Logout | **Orang 1** |
| 7 | Manajemen User & Multi-Role (RBAC) | [`lib/features/users/presentation/user_management_screen.dart`](file:///c:/MyProjects/arus/lib/features/users/presentation/user_management_screen.dart) | Multi-Role Access Control | **Orang 1** |
| **MOD-2** | **Katalog, Resep, Inventaris & POS** | | | |
| 8 | Master Menu & Resep Bahan Baku | [`api/src/modules/catalog/catalog.service.ts`](file:///c:/MyProjects/arus/api/src/modules/catalog/catalog.service.ts) | API Web Service & Cloud DB | **Orang 2** |
| 9 | Cari & Filter Katalog (Porsi Dinamis) | [`lib/features/catalog/presentation/product_list_screen.dart`](file:///c:/MyProjects/arus/lib/features/catalog/presentation/product_list_screen.dart) | Fasilitas Pencarian & Pemilihan | **Orang 2** |
| 10 | Backup Offline Katalog (SQLite) | [`lib/core/storage/local_db.dart`](file:///c:/MyProjects/arus/lib/core/storage/local_db.dart) (`backup_products`) | Database Lokal SQLite & Online | **Orang 2** |
| 11 | Filter Status Stok Bahan Baku Cabang | [`lib/features/inventory/presentation/inventory_list_screen.dart`](file:///c:/MyProjects/arus/lib/features/inventory/presentation/inventory_list_screen.dart) | Fasilitas Pemilihan & Filter | **Orang 2** |
| 12 | Penyesuaian Stok Atomik (*Adjustment*) | [`api/src/modules/inventory/inventory.service.ts`](file:///c:/MyProjects/arus/api/src/modules/inventory/inventory.service.ts) | Decision Support Inventaris | **Orang 1** |
| 13 | Kasir Mobile POS Berbasis Resep | [`lib/features/pos/presentation/pos_screen.dart`](file:///c:/MyProjects/arus/lib/features/pos/presentation/pos_screen.dart) | Konsep Proyek Akhir (POS) | **Orang 1 & 2** |
| 14 | Struk & Offline POS Queue SQLite | [`lib/core/sync/sync_service.dart`](file:///c:/MyProjects/arus/lib/core/sync/sync_service.dart) | Database Lokal SQLite (Queue) | **Orang 2** |
| 15 | Pembatalan Transaksi (*Void*) | [`api/src/modules/transactions/transactions.service.ts`](file:///c:/MyProjects/arus/api/src/modules/transactions/transactions.service.ts) | Integritas Data Transaksi | **Orang 1** |
| **MOD-3** | **Blockchain & Notifikasi Mobile** | | | |
| 16 | Pencatatan Rantai Hash SHA-256 | [`api/src/modules/integrity/blockchain.service.ts`](file:///c:/MyProjects/arus/api/src/modules/integrity/blockchain.service.ts) | Fitur Blockchain Sederhana | **Orang 1** |
| 17 | Verifikasi Keaslian & Tamper Recovery | [`lib/features/integrity/presentation/integrity_chain_screen.dart`](file:///c:/MyProjects/arus/lib/features/integrity/presentation/integrity_chain_screen.dart) | Fitur Blockchain Sederhana | **Orang 1** |
| 18 | Notifikasi Mobile Stok Menipis | [`lib/core/push/notification_service.dart`](file:///c:/MyProjects/arus/lib/core/push/notification_service.dart) | Notifikasi Mobile Sesuai Konsep | **Orang 2** |
| **MOD-4** | **Dashboard, Utilitas, Sensor & LBS** | | | |
| 19 | Dashboard Analitik & Grafik Tren | [`lib/features/dashboard/presentation/dashboard_screen.dart`](file:///c:/MyProjects/arus/lib/features/dashboard/presentation/dashboard_screen.dart) | Business Analytics & fl_chart | **Orang 3** |
| 20 | Konversi 3 Mata Uang (IDR, USD, EUR) | [`lib/core/utils/money_formatter.dart`](file:///c:/MyProjects/arus/lib/core/utils/money_formatter.dart) | Konversi Min. 3 Mata Uang | **Orang 2** |
| 21 | Konversi 4 Zona Waktu (WIB/WITA/WIT/LDN) | [`lib/core/utils/timezone_converter.dart`](file:///c:/MyProjects/arus/lib/core/utils/timezone_converter.dart) | Konversi 4 Zona Waktu | **Orang 2** |
| 22 | Sensor 1: Accelerometer (*Shake*) | [`lib/features/sensors/presentation/sensor_provider.dart`](file:///c:/MyProjects/arus/lib/features/sensors/presentation/sensor_provider.dart) | Sensor 1: Accelerometer | **Orang 3** |
| 23 | Sensor 2: Gyroscope (*Tilt Switch*) | [`lib/features/sensors/presentation/sensor_test_screen.dart`](file:///c:/MyProjects/arus/lib/features/sensors/presentation/sensor_test_screen.dart) | Sensor 2: Gyroscope | **Orang 3** |
| 24 | Peta Cabang LBS (Haversine GPS) | [`lib/features/outlets/presentation/widgets/outlet_map_widget.dart`](file:///c:/MyProjects/arus/lib/features/outlets/presentation/widgets/outlet_map_widget.dart) | Fasilitas LBS & Web Service | **Orang 3** |
| **MOD-5** | **Kecerdasan Buatan (AI) & Mini Game** | | | |
| 25 | Rule-Based Decision Support (Insights) | [`api/src/modules/insights/insights.service.ts`](file:///c:/MyProjects/arus/api/src/modules/insights/insights.service.ts) | Fitur AI Sesuai Tema | **Orang 3** |
| 26 | ARUS AI Copilot (Gemini LLM & Voice) | [`api/src/modules/ai/ai.service.ts`](file:///c:/MyProjects/arus/api/src/modules/ai/ai.service.ts) & [`tts.service.ts`](file:///c:/MyProjects/arus/api/src/modules/ai/tts.service.ts) | Fitur AI & LLM Sesuai Tema | **Orang 3** |
| 27 | Mini Game (*Guess the Menu*) | [`lib/features/game/presentation/game_home_screen.dart`](file:///c:/MyProjects/arus/lib/features/game/presentation/game_home_screen.dart) | Mini Game Terkait Konsep | **Orang 3** |

---

## 5. Arsitektur Database: PostgreSQL Cloud & SQLite Lokal

### 5.1 Skema PostgreSQL Cloud (17 Model Prisma)
Berkas skema lengkap: [`api/prisma/schema.prisma`](file:///c:/MyProjects/arus/api/prisma/schema.prisma)
1. `User`: Akun pengguna, role (`owner`, `manager`, `staff`), password hash, display preferences.
2. `Outlet`: Cabang toko, koordinat GPS (`latitude`, `longitude`), zona waktu (`Asia/Jakarta`, dll).
3. `UserOutlet`: Pemetaan relasi many-to-many user ke cabang yang ditugaskan (*Outlet Scoping*).
4. `Feedback`: Testimoni kesan dan saran perkuliahan PAM.
5. `ProductCategory`: Kategori menu jualan (Kopi, Non-Kopi, Makanan).
6. `Product`: Menu jualan kasir, harga (`price_idr`), foto `image_url` (dipakai juga di Mini Game).
7. `Ingredient`: Stok fisik bahan mentah di masing-masing cabang (`stock_qty`, `reorder_level`, `cost_per_unit`).
8. `ProductRecipe`: Takaran bahan baku untuk membuat 1 porsi menu (`amount_needed`).
9. `InventoryMovement`: Log audit mutasi stok bertanda (`sale`, `void_return`, `restock`, `correction`, `waste`).
10. `Transaction`: Struk penjualan kasir POS (`subtotal_idr`, `total_idr`, `payment_method`, `status`).
11. `TransactionItem`: Rincian item menu pada struk, snapshot harga jual dan HPP saat transaksi terjadi.
12. `BlockchainRecord`: Buku besar transaksi terenkripsi SHA-256 (`data_hash`, `prev_hash`, `block_hash`, serta backup self-healing).
13. `Notification`: Riwayat notifikasi sistem (stok menipis, peringatan tamper).
14. `DeviceToken`: Registrasi token push notification mobile.
15. `AiChatLog`: Riwayat interaksi AI, menyimpan prompt, jawaban JSON, dan snapshot fakta angka yang digunakan (*grounded facts*).
16. `GameSession`: Riwayat sesi permainan mini game (`guess_name` atau `guess_price`), skor, dan durasi.
17. `RefreshToken`: Token sesi JWT rotasi keluarga (`family_id`, `token_hash`, masa berlaku).

### 5.2 Skema Database Lokal SQLite (7 Tabel `local_db.dart`)
Berkas skema lengkap: [`lib/core/storage/local_db.dart`](file:///c:/MyProjects/arus/lib/core/storage/local_db.dart)
1. `local_session_settings`: Data sesi aktif, status biometrik, preferensi mata uang & zona waktu.
2. `cached_categories`: Cache daftar kategori untuk akses cepat UI.
3. `cached_products`: Cache katalog produk aktif.
4. `backup_products`: Snapshot katalog lengkap beserta takaran resep untuk operasional offline.
5. `offline_transactions`: **Antrean transaksi kasir offline (*Offline POS Queue*)** yang menampung transaksi saat internet mati, berstatus `PENDING_SYNC`.
6. `backup_transactions`: Riwayat 50 struk transaksi terakhir yang tersimpan di memori HP.
7. `daily_analytics_cache`: Cache ringkasan omzet dan tren untuk performa instan saat aplikasi dibuka.

---

## 6. Aturan Bisnis Inti (Non-Negotiable Business Rules)

1. **Formula Estimasi Porsi Dinamis (BR-INV-01):**
   $$\text{Estimasi Porsi} = \min_{i \in \text{Resep}} \left\lfloor \frac{\text{Stok Bahan Baku}_i}{\text{Takaran per Porsi}_i} \right\rfloor$$
   *Kasir tidak boleh menjual menu jika salah satu bahan baku resepnya tidak mencukupi.*
2. **Transaksi Atomik Kasir POS (BR-POS-01):**
   Checkout kasir memotong seluruh bahan baku terkait secara serentak dalam 1 transaksi database. Jika ada 1 bahan yang stoknya kurang, transaksi digagalkan secara keseluruhan (*rollback*).
3. **Idempotensi Transaksi Offline (BR-POS-02):**
   Setiap transaksi offline memiliki UUID `client_request_id`. Server menolak memproses ulang jika ID yang sama dikirimkan dua kali saat proses sinkronisasi koneksi internet.
4. **Keamanan Rantai Blockchain (BR-INT-01):**
   Blok baru dihitung dengan formula $\text{SHA256}(\text{prev\_hash} + \text{data\_hash} + \text{timestamp})$. Jika satu angka di PostgreSQL diubah langsung oleh oknum, seluruh hash berikutnya otomatis menjadi **TAMPERED**.

---

## 7. Batas Domain Tanggung Jawab Tim (Team Boundaries)

* **Orang 1 (Architect, Security & Blockchain):** Bertanggung jawab atas backend Express, skema database PostgreSQL, enkripsi password `argon2id`, JWT, RBAC multi-role, transaksi atomik POS di backend, dan rantai integritas Blockchain SHA-256.  
  👉 *Buka panduan operasional di:* [`ORANG_1.md`](file:///c:/MyProjects/arus/ORANG_1.md)
* **Orang 2 (Mobile Client, SQLite & Offline-First):** Bertanggung jawab atas aplikasi Flutter, Riverpod, login biometrik Keystore, 7 tabel SQLite, mekanisme Offline POS Queue & auto-sync, konversi kurs & waktu, dan notifikasi lokal.  
  👉 *Buka panduan operasional di:* [`ORANG_2.md`](file:///c:/MyProjects/arus/ORANG_2.md)
* **Orang 3 (Smart Features, Hardware Sensors & AI):** Bertanggung jawab atas sensor Accelerometer & Gyroscope, Peta LBS OpenStreetMap (Haversine GPS), AI Copilot Gemini (Context Grounding) + Edge TTS Voice, Mini Game Bisnis, dan form Kesan & Saran PAM.  
  👉 *Buka panduan operasional di:* [`ORANG_3.md`](file:///c:/MyProjects/arus/ORANG_3.md)

---

## 8. Template Prompt Inisialisasi AI (Gunakan Ini di Chat Baru)

Salin prompt di bawah ini saat membuka sesi obrolan baru dengan AI / Antigravity untuk mengaktifkan pemahaman sistem secara instan:

```text
Halo AI, saya sedang mengerjakan proyek aplikasi mobile "ARUS" (Mobile POS & Business Decision Support System).
Sebelum kita mulai diskusi, tolong pahami konteks arsitektur sistem ARUS dengan membaca file "MASTER_UNDERSTAND.md".
Setelah Anda memahami arsitektur global, saya akan memberikan file peran saya ("ORANG_1.md" / "ORANG_2.md" / "ORANG_3.md") yang menjadi batasan tugas dan fokus pembahasan saya. Konfirmasi jika Anda sudah siap membaca dokumen tersebut!
```
