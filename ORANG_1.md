# ORANG 1 — The System Architect, Security & Blockchain Lead
> **PANDUAN OPERASIONAL AI & KOMANDO SISTEM NYATA**  
> **Target Pengguna:** Anggota Tim 1 & Asisten AI (Antigravity / LLM).  
> **Prasyarat Wajib:** Pastikan AI telah membaca [`MASTER_UNDERSTAND.md`](file:///c:/MyProjects/arus/MASTER_UNDERSTAND.md) terlebih dahulu.

---

## 1. AI OPERATIONAL DIRECTIVE & SYSTEM LOCK

Jika Anda adalah asisten AI yang mendampingi **Orang 1**:
1. **Fokus Terkunci (Role-Lock):** Anda adalah Co-Pilot khusus untuk **Backend Web Service, Database PostgreSQL, Keamanan Sistem, Transaksi Atomik POS, dan Integritas Blockchain**.
2. **Larangan Melebar:** JANGAN membahas secara mendalam logika UI Flutter, SQLite lokal kasir (milik Orang 2), atau sensor hardware/AI Gemini (milik Orang 3), kecuali sebatas antarmuka data API.
3. **Wajib Memeriksa Berkas Kode Nyata:** Sebelum memberikan jawaban, analisis atau penjelasan teknis kepada Orang 1, Anda **WAJIB membaca dan merujuk** berkas-berkas berikut di workspace:
   - Skema Database: [`api/prisma/schema.prisma`](file:///c:/MyProjects/arus/api/prisma/schema.prisma)
   - Keamanan & Auth: [`api/src/modules/auth/auth.service.ts`](file:///c:/MyProjects/arus/api/src/modules/auth/auth.service.ts), [`auth.controller.ts`](file:///c:/MyProjects/arus/api/src/modules/auth/auth.controller.ts)
   - Middleware RBAC & Scope: [`api/src/middleware/auth.ts`](file:///c:/MyProjects/arus/api/src/middleware/auth.ts)
   - Token & JWT: [`api/src/shared/jwt.ts`](file:///c:/MyProjects/arus/api/src/shared/jwt.ts), [`tokens.ts`](file:///c:/MyProjects/arus/api/src/shared/tokens.ts)
   - Transaksi Atomik: [`api/src/modules/transactions/transactions.service.ts`](file:///c:/MyProjects/arus/api/src/modules/transactions/transactions.service.ts)
   - Integritas Blockchain: [`api/src/modules/integrity/blockchain.service.ts`](file:///c:/MyProjects/arus/api/src/modules/integrity/blockchain.service.ts), [`dual_blockchain.ts`](file:///c:/MyProjects/arus/api/src/modules/integrity/dual_blockchain.ts)
   - Manajemen User: [`api/src/modules/users/users.service.ts`](file:///c:/MyProjects/arus/api/src/modules/users/users.service.ts)

---

## 2. Peta Fitur & Tanggung Jawab Orang 1

Orang 1 memegang kendali atas pondasi sistem ARUS:

| Kode Fitur | Nama Fitur | Kriteria Dosen PAM | File Kunci di Codebase |
| :---: | :--- | :--- | :--- |
| **Fitur 1** | Login Enkripsi Password (`argon2id`) | Login Enkripsi Non-Firebase | `api/src/modules/auth/auth.service.ts` |
| **Fitur 2** | Sesi JWT & Refresh Token Rotation | Manajemen Sesi & Token | `api/src/shared/jwt.ts`, `tokens.ts` |
| **Fitur 6** | Menu Logout & Token Revocation | Menu Logout Bottom Nav | `api/src/modules/auth/auth.service.ts` |
| **Fitur 7** | Manajemen Akun User & Multi-Role | Multi-Role Access Control | `api/src/modules/users/users.service.ts` |
| **Fitur 12** | Penyesuaian Stok Atomik (*Adjustment*) | Decision Support Inventaris | `api/src/modules/inventory/inventory.service.ts` |
| **Fitur 13** | Core Backend POS & Validasi Resep | Konsep Proyek Akhir | `api/src/modules/transactions/transactions.service.ts` |
| **Fitur 15** | Pembatalan Transaksi (*Void*) | Integritas Transaksi | `api/src/modules/transactions/transactions.service.ts` |
| **Fitur 16** | Rantai Hash Blockchain SHA-256 | Blockchain Sederhana | `api/src/modules/integrity/blockchain.service.ts` |
| **Fitur 17** | Audit Tamper Check & Self-Healing | Blockchain Sederhana | `api/src/modules/integrity/dual_blockchain.ts` |

---

## 3. Bedah Teknis Sistem Nyata (Deep Dive Codebase)

### 3.1 Mengapa Non-Firebase & Cara Kerja `argon2id`
* **Lokasi Kode:** [`api/src/modules/auth/auth.service.ts`](file:///c:/MyProjects/arus/api/src/modules/auth/auth.service.ts)
* **Mekanisme:**
  - Password pengguna tidak disimpan dalam bentuk plaintext maupun MD5/SHA yang rentan brute-force GPU.
  - Backend menggunakan library `argon2` dengan profil `argon2id` (kombinasi tahan *side-channel attack* dan *memory-hard trade-off*).
  - Format hash yang tersimpan di kolom `password_hash` tabel `users` memiliki salt otomatis 16-byte dan memori cost 64MB.
* **Session Lifecycle (JWT Family Rotation):**
  - **Access Token:** Masa berlaku singkat (15 menit), berisi payload `{ userId, email, role, outletIds }`.
  - **Refresh Token:** Masa berlaku 7 hari, disimpan dalam tabel `refresh_tokens`.
  - **Family Rotation:** Jika pengguna me-refresh token, refresh token lama langsung di-revokasi (`revoked_at = now()`) dan token baru diterbitkan dalam `family_id` yang sama. Jika ada refresh token lama yang coba dipakai ulang (indikasi token pencurian), seluruh keluarga token dibatalkan seketika.

### 3.2 Role-Based Access Control (RBAC) & Outlet Scoping
* **Lokasi Kode:** [`api/src/middleware/auth.ts`](file:///c:/MyProjects/arus/api/src/middleware/auth.ts)
* **Matriks Hak Akses:**
  - `owner`: Akses penuh ke semua endpoint tanpa filter cabang.
  - `manager`: Dibatasi hanya pada cabang yang terdaftar di tabel `user_outlets`. Ditolak jika mengakses endpoint tambah user baru.
  - `staff`: Dibatasi hanya pada 1 cabang kasir aktif. Response JSON katalog disaring ketat di backend; kolom `cost_per_unit` (harga modal) disembunyikan agar kasir tidak tahu margin keuntungan toko.

### 3.3 Transaksi POS Atomik Berbasis Resep (ACID)
* **Lokasi Kode:** [`api/src/modules/transactions/transactions.service.ts`](file:///c:/MyProjects/arus/api/src/modules/transactions/transactions.service.ts)
* **Alur Eksekusi Database:**
  1. Client mengirim keranjang belanja dengan UUID unik `client_request_id`.
  2. Pengecekan idempotensi: jika `client_request_id` sudah ada di tabel `transactions`, server langsung mengembalikan struk yang sudah ada tanpa memotong stok ulang.
  3. Menggunakan `prisma.$transaction`:
     - Server mencari resep dari setiap menu di `product_recipes`.
     - Mengakumulasikan seluruh kebutuhan bahan mentah (`ingredients`).
     - Mengecek ketersediaan stok: jika $\text{kebutuhan} > \text{stok}$, transaksi dibatalkan dengan error `INSUFFICIENT_STOCK`.
     - Mengurangi kuantitas di tabel `ingredients` (`decrement`).
     - Mencatat baris baru di tabel `inventory_movements` dengan tipe `sale`.
     - Menyimpan struk ke tabel `transactions` dan detail item ke `transaction_items`.
     - Memanggil engine blockchain untuk mencetak blok transaksi baru.

### 3.4 Dual-Layer Blockchain SHA-256 & Audit Anti-Manipulasi
* **Lokasi Kode:** [`api/src/modules/integrity/blockchain.service.ts`](file:///c:/MyProjects/arus/api/src/modules/integrity/blockchain.service.ts) & [`dual_blockchain.ts`](file:///c:/MyProjects/arus/api/src/modules/integrity/dual_blockchain.ts)
* **Struktur Rantai Blok:**
  - Setiap cabang (`outlet_id`) memiliki rantai blok independen yang berurutan berdasarkan `block_index`.
  - Setiap blok memiliki:
    $$\text{data\_hash} = \text{SHA256}(\text{JSON.stringify}(\text{transaction\_payload}))$$
    $$\text{block\_hash} = \text{SHA256}(\text{prev\_hash} + \text{data\_hash} + \text{timestamp} + \text{block\_index})$$
* **Deteksi Manipulasi (Tamper Check):**
  - Endpoint `GET /api/integrity/verify/:outletId` membaca ulang seluruh transaksi dan menghitung ulang hash dari blok pertama (*genesis*) hingga terakhir.
  - Jika ada oknum admin yang mengubah nilai transaksi di PostgreSQL secara langsung, `data_hash` yang dihitung ulang tidak cocok dengan `block_hash` yang tercatat. Status rantai blok berubah menjadi **TAMPERED**.
* **Self-Healing Recovery:**
  - Tabel `blockchain_records` menyimpan snapshot cadangan `backup_event_data` dan `backup_block_hash`.
  - Saat proses audit mendeteksi kerusakan, tombol *Restore/Recovery* memulihkan data asli transaksi dari snapshot cadangan yang terenkripsi.

---

## 4. Batasan Narasi Presentasi (Scope Boundaries)

### Yang HARUS Dijelaskan oleh Orang 1:
- Latar belakang ARUS dan masalah operasional multi-cabang.
- Arsitektur client-server: Flutter $\rightarrow$ Express.js API $\rightarrow$ PostgreSQL Supabase (Bukan Firebase).
- Autentikasi `argon2id`, JWT, RBAC multi-role, dan pemisahan hak akses outlet.
- Bagaimana transaksi kasir memotong stok bahan mentah secara atomik di database cloud.
- Mengapa blockchain digunakan untuk mengamankan data transaksi kasir dari fraud internal.

### Yang BUKAN Bagian Orang 1 (Delegasikan ke Rekan):
- "Bagaimana aplikasi kasir tetap bisa checkout saat internet mati?" $\rightarrow$ **Lempar ke Orang 2 (Offline SQLite & Sync).**
- "Bagaimana cara kerja sidik jari di HP?" $\rightarrow$ **Lempar ke Orang 2 (`local_auth` & Keystore).**
- "Bagaimana sensor HP dan AI Gemini bekerja?" $\rightarrow$ **Lempar ke Orang 3 (Sensors & AI).**

---

## 5. Skenario Live Demo (Runbook Presentasi)

Ikuti urutan langkah demo ini agar presentasi berjalan mulus:

```text
[Langkah 1: Demo RBAC Multi-Role]
1. Buka aplikasi di HP/Emulator.
2. Login sebagai Owner (email: owner@arus.com / password sesuai seed).
3. Tunjukkan Bottom Navigation memiliki 5 Tab (Beranda, Operasi, AI, Analitik, Lainnya).
4. Masuk ke menu "Lainnya" -> "Manajemen Pengguna" -> perlihatkan daftar akun Manager dan Staff kasir.
5. Logout, lalu login sebagai Kasir/Staff (staff@arus.com).
6. Perlihatkan Bottom Nav berubah menjadi 4 Tab (Beranda, Kasir, Stok, Lainnya). Tab AI dan Analitik disembunyikan.

[Langkah 2: Demo Core Transaction POS]
1. Dalam akun kasir, masuk ke tab "Kasir (POS)".
2. Pilih 1 atau 2 menu kopi -> klik "Bayar" (Metode Tunai).
3. Selesaikan transaksi hingga struk pembayaran muncul.
4. Tunjukkan struk memiliki nomor nota dan kode "Blockchain Block Hash: #XXXX...".

[Langkah 3: Demo Blockchain Integrity & Tamper Check]
1. Login kembali sebagai Owner/Manager.
2. Buka menu "Operasi" -> pilih "Integritas Blockchain" (Integrity Chain).
3. Tunjukkan seluruh rantai transaksi berstatus "VALID" (berwarna hijau).
4. Klik tombol "Simulasi Uji Manipulasi" (Tamper Simulation).
5. Tunjukkan status blok langsung berubah menjadi "TAMPERED" (berwarna merah) dengan penjelasan bahwa hash tidak cocok.
6. Klik tombol "Pulihkan Rantai Data" (Self-Healing Recovery) -> sistem memvalidasi ulang dan status kembali menjadi "VALID".
```

---

## 6. Cheatsheet Ujian Dosen & Jawaban Mantap

* **Dosen:** *"Kenapa kalian tidak pakai Firebase Authentication dan Firestore saja yang jauh lebih mudah dan otomatis?"*
  * **Jawaban:** *"Sesuai kriteria proyek akhir dan kebutuhan data privacy multi-outlet skala enterprise, kami merancang REST API mandiri menggunakan Node.js Express dan PostgreSQL Supabase. Firebase memiliki keterbatasan dalam menangani relasi database kompleks seperti resep banyak-ke-banyak (`product_recipes`) dan mutasi stok atomik. Selain itu, kami menerapkan algoritma hashing modern `argon2id` dengan salt unik yang jauh lebih aman dari serangan GPU-cracking, serta session stateless JWT dengan Refresh Token Family Rotation yang tersimpan aman di database."*

* **Dosen:** *"Blockchain di sini pakai koin kripto apa? Ethereum atau Bitcoin?"*
  * **Jawaban:** *"Aplikasi kami tidak menggunakan mata uang kripto atau Proof-of-Work yang boros energi, melainkan mengimplementasikan arsitektur **Private Permissioned Integrity Ledger**. Tujuannya murni untuk keamanan data audit (*anti-tamper ledger*). Setiap struk transaksi dihitung hash SHA-256 dan diikat ke hash transaksi sebelumnya (`prev_hash`). Jika database PostgreSQL diretas atau ada oknum admin yang memanipulasi nominal transaksi di tabel database, seluruh rantai hash akan putus (*tampered*) dan sistem mendeteksi kecurangan tersebut secara instan."*

* **Dosen:** *"Bagaimana jika dua kasir menjual menu yang menggunakan bahan baku yang sama secara bersamaan saat stok tinggal sedikit?"*
  * **Jawaban:** *"Kami menggunakan Prisma `$transaction` di backend Express. Di tingkat PostgreSQL, transaksi dijalankan dengan mekanisme row-level locking saat mengecek dan mengurangi kuantitas di tabel `ingredients`. Jika stok tidak mencukupi saat gilirannya dieksekusi, transaksi kedua akan di-rollback secara otomatis dan mengembalikan respon error `INSUFFICIENT_STOCK`, sehingga stok bahan baku tidak akan pernah minus."*
