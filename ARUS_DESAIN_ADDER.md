# 🚀 ARUS — Master Blueprint: Arsitektur, Database & Phase Pengujian
**Versi:** 2.0 (Edisi Revisi Tugas Akhir Praktikum Aplikasi Mobile)  
**Stack Utama:** Flutter (Android/iOS) + Node.js/Express (TypeScript) + PostgreSQL (Supabase) + SQLite (`sqflite`)[cite: 1, 2, 4, 5]

---

## 1. Gambaran Besar Arsitektur (1 Aplikasi Flutter + REST API)

Sistem menggunakan pendekatan **Single Mobile App (Flutter)** yang mencakup fitur operasional Kasir (Mobile POS) sekaligus Dashboard & Analitik untuk Owner/Manager[cite: 1, 2]. Seluruh komunikasi data wajib melewati **Web Service / REST API** pribadi (Express.js) dan diintegrasikan dengan **Web Service Publik** serta **Database Lokal (SQLite)** sebagai *offline backup*[cite: 1, 2, 4, 5].

```text
[ Flutter App (Android / iOS) ]
   ├── UI Layer: Kasir (POS), Dashboard, Peta LBS, AI Chat, Mini Game, Profil
   ├── Local DB: SQLite (sqflite) -> Backup Produk, Struk Offline, Pengaturan Sesi
   │
   ├──> (HTTPS REST JSON) ──> [ Express.js Web Service (/api/*) ]
   │                             └── Prisma ORM ──> [ PostgreSQL Online (Supabase) ]
   │
   └──> (Public Web Services / API)
         ├── Frankfurter API (Kurs Mata Uang: IDR, USD, EUR)
         ├── OpenStreetMap API (Peta Cabang & LBS)
         └── Gemini API (LLM Business Assistant via Backend)
```

---

## 2. Pemetaan Syarat Dosen (Tugas Akhir PAM) ke Konsep ARUS

Tabel ini memastikan seluruh kriteria wajib di slide dosen terpenuhi 100% dan menyatu dengan konsep bisnis multi-outlet ARUS[cite: 2, 4]:

| # | Syarat Wajib Dosen | Implementasi di Aplikasi ARUS | Tabel / Teknologi yang Dipakai |
|---|---|---|---|
| 1 | **Login Enkripsi (Non-Firebase) & Session**[cite: 4] | Login staf/manajer/owner dengan password di-hash (`argon2`/`bcrypt`) dan sesi JWT[cite: 1, 2]. | Tabel PostgreSQL `users`, `user_outlets` + JWT[cite: 2, 3]. |
| 2 | **Login Biometric**[cite: 4] | Buka kunci sesi aplikasi menggunakan sensor sidik jari/wajah di HP[cite: 1, 2]. | Plugin `local_auth` + `flutter_secure_storage`[cite: 1, 2]. |
| 3 | **Database Lokal (SQLite) & Online**[cite: 4] | **Online:** PostgreSQL menyimpan data bisnis utama[cite: 1, 2].<br>**Lokal:** SQLite menyimpan *backup* katalog, struk terakhir, dan preferensi saat *offline*[cite: 4]. | **Online:** Supabase PostgreSQL[cite: 1, 2].<br>**Lokal:** `sqflite` (3 tabel)[cite: 4]. |
| 4 | **Web Service / API & Multiplatform**[cite: 4, 5] | Flutter (Android/iOS) memanggil REST API Express.js pribadi dan API publik (Kurs, Peta, AI)[cite: 1, 2, 4, 5]. | Node.js + Express + `dio` HTTP Client[cite: 1, 2]. |
| 5 | **Fasilitas LBS Terkait Tema**[cite: 4, 5] | Peta lokasi cabang, hitung jarak GPS pengguna ke cabang terdekat, dan indikator warna performa omzet cabang[cite: 1, 2]. | Tabel `outlets` (`latitude`, `longitude`), `geolocator`, `flutter_map`[cite: 1, 2, 3]. |
| 6 | **Bottom Nav: Profil (Gambar), Kesan & Saran PAM, Logout**[cite: 4] | Navigasi bawah memiliki tab Profil (menampilkan foto), form Kesan & Saran matkul PAM, serta tombol Logout[cite: 2, 4]. | Kolom `users.avatar_url` & Tabel `feedback` (`kesan`, `saran`)[cite: 2, 3, 4]. |
| 7 | **Konversi Mata Uang (IDR, USD, EUR)**[cite: 2, 4] | Mengubah tampilan angka omzet Dashboard & harga produk ke IDR, USD, atau EUR untuk laporan investor asing[cite: 2, 3]. | Disimpan `integer` IDR di DB; dikonversi via Frankfurter API[cite: 1, 2, 3]. |
| 8 | **Konversi Waktu (WIB, WITA, WIT, London)**[cite: 2, 4] | Memantau jam transaksi lintas cabang di Indonesia (WIB/WITA/WIT) dan cabang ekspansi di London[cite: 1, 2]. | Disimpan UTC (`timestamptz`), dikonversi via paket `timezone`[cite: 2, 3]. |
| 9 | **Minimal 2 Sensor (Accelerometer & Gyroscope)**[cite: 4] | **Accelerometer:** Kocok HP (*shake*) untuk *refresh* Dashboard[cite: 1, 2].<br>**Gyroscope:** Miringkan HP (*tilt*) untuk ganti filter grafik (Harian/Mingguan/Bulanan)[cite: 1, 2]. | Plugin `sensors_plus`[cite: 1, 2]. |
| 10 | **Fitur AI & LLM Sesuai Tema**[cite: 4] | **ARUS Assistant:** Tanya-jawab kondisi penjualan & stok toko. AI menjawab berdasarkan angka nyata dari DB[cite: 1, 2]. | Tabel `business_insights`, `ai_chat_logs` + Gemini API[cite: 1, 2, 3]. |
| 11 | **Mini Games Sederhana Terkait Konsep**[cite: 4] | **Business Decision Challenge:** Kuis simulasi ambil keputusan bisnis (5 soal studi kasus stok/omzet)[cite: 2, 3]. | Tabel `game_scenarios` & `game_sessions`[cite: 2, 3]. |
| 12 | **Fasilitas Pencarian dan Pemilihan**[cite: 4] | Cari nama/SKU produk, filter kategori, filter stok menipis, dan cari nomor struk transaksi[cite: 1, 2]. | Query `ILIKE` & filter di endpoint `/products`, `/inventory`, `/transactions`[cite: 1, 2]. |
| 13 | **Notifikasi Mobile Sesuai Konsep**[cite: 4] | Notifikasi lokal otomatis muncul di HP saat transaksi POS membuat stok barang menyentuh batas minimum (`reorder_level`)[cite: 1, 2, 3]. | Tabel `notifications` + `flutter_local_notifications`[cite: 1, 2, 3]. |
| 14 | **Fitur Blockchain Sederhana**[cite: 4] | Setiap struk transaksi di-hash dengan **SHA-256** menyambung ke hash struk sebelumnya (`prev_hash`) untuk cegah manipulasi data[cite: 2, 3]. | Tabel `blockchain_records`[cite: 2, 3]. |

---

## 3. Daftar Tabel Database Online (PostgreSQL - 14 Tabel)

Skema dipangkas dari 21 tabel menjadi **14 tabel inti** agar mudah dikelola dan dijelasin saat presentasi[cite: 1, 2, 3, 4]:

| No | Nama Tabel | Fungsi Utama | Kolom Kunci (PK / FK / Penting) |
|---|---|---|---|
| 1 | `users` | Akun pengguna & profil[cite: 2, 3] | `id` (PK), `email`, `password_hash`, `role`, `avatar_url` |
| 2 | `outlets` | Data cabang, lokasi LBS & zona waktu[cite: 2, 3] | `id` (PK), `name`, `latitude`, `longitude`, `timezone` |
| 3 | `user_outlets` | Penugasan cabang untuk Manager/Staff[cite: 2, 3] | `user_id` (PK, FK), `outlet_id` (PK, FK) |
| 4 | `feedback` | Kesan & saran matkul PAM[cite: 4] | `id` (PK), `user_id` (FK), `kesan`, `saran` |
| 5 | `product_categories` | Kategori barang[cite: 2, 3] | `id` (PK), `name` |
| 6 | `products` | Katalog produk & harga jual/modal[cite: 2, 3] | `id` (PK), `category_id` (FK), `sku`, `name`, `price_idr`, `cost_idr` |
| 7 | `inventory` | Jumlah stok saat ini per cabang[cite: 2, 3] | `outlet_id` (PK, FK), `product_id` (PK, FK), `quantity`, `reorder_level` |
| 8 | `inventory_movements` | Buku catatan keluar-masuk stok (audit)[cite: 2, 3] | `id` (PK), `outlet_id` (FK), `product_id` (FK), `movement_type`, `quantity_delta` |
| 9 | `transactions` | Header struk penjualan POS[cite: 2, 3] | `id` (PK), `receipt_no`, `outlet_id` (FK), `cashier_id` (FK), `total_idr`, `status` |
| 10 | `transaction_items` | Detail barang yang dibeli di struk[cite: 2, 3] | `id` (PK), `transaction_id` (FK), `product_id` (FK), `product_name_snapshot`, `unit_price_idr`, `quantity` |
| 11 | `blockchain_records` | Rantai hash SHA-256 pengaman struk[cite: 2, 3] | `id` (PK), `outlet_id` (FK), `block_index`, `transaction_id` (FK), `data_hash`, `prev_hash`, `block_hash` |
| 12 | `notifications` | Kotak masuk notifikasi stok tipis & sistem[cite: 2, 3] | `id` (PK), `user_id` (FK), `type`, `title`, `body`, `is_read` |
| 13 | `business_insights` | Temuan otomatis (stok tipis / omzet turun)[cite: 2, 3] | `id` (PK), `rule_code`, `severity`, `outlet_id` (FK), `title`, `evidence`, `recommendation` |
| 14 | `ai_chat_logs` | Riwayat tanya-jawab dengan asisten LLM[cite: 2, 3] | `id` (PK), `user_id` (FK), `question`, `answer_json`, `facts_used` |
| 15* | `game_scenarios` & `game_sessions` | Soal & riwayat skor mini game bisnis[cite: 2, 3] | `id` (PK), `code`, `difficulty`, `situation_json`, `choices_json` / `user_id` (FK), `score` |

---

## 4. Skema Lengkap Prisma (`prisma/schema.prisma`)

Salin kode ini ke dalam file `prisma/schema.prisma` pada proyek backend (`arus_api`)[cite: 1, 2]:

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

enum Severity {
  info
  warning
  critical
}

// ==========================================
// PHASE 1: USERS, OUTLETS (LBS), & FEEDBACK
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
  insights     BusinessInsight[]

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
// PHASE 2: CATALOG & INVENTORY
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
  unit        String           @default("pcs") @db.VarChar(20)
  price_idr   Int
  cost_idr    Int?
  is_active   Boolean          @default(true)
  created_at  DateTime         @default(now()) @db.Timestamptz()
  updated_at  DateTime         @updatedAt @db.Timestamptz()

  category    ProductCategory?  @relation(fields: [category_id], references: [id])
  inventory   Inventory[]
  txn_items   TransactionItem[]
  insights    BusinessInsight[]

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

// ==========================================
// PHASE 3: POS TRANSACTIONS, BLOCKCHAIN & NOTIF
// ==========================================

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

  inventory      Inventory    @relation(fields: [outlet_id, product_id], references: [outlet_id, product_id])
  transaction    Transaction? @relation(fields: [transaction_id], references: [id])
  creator        User         @relation(fields: [created_by], references: [id])

  @@map("inventory_movements")
}

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
// PHASE 6: INSIGHTS, AI ASSISTANT & MINI GAME
// ==========================================

model BusinessInsight {
  id             String    @id @default(uuid()) @db.Uuid
  rule_code      String    @db.VarChar(40)
  severity       Severity  @default(info)
  outlet_id      String?   @db.Uuid
  product_id     String?   @db.Uuid
  title          String    @db.Text
  message        String    @db.Text
  evidence       Json
  recommendation String    @db.Text
  is_dismissed   Boolean   @default(false)
  insight_date   DateTime  @db.Date
  created_at     DateTime  @default(now()) @db.Timestamptz()

  outlet         Outlet?   @relation(fields: [outlet_id], references: [id])
  product        Product?  @relation(fields: [product_id], references: [id])

  @@map("business_insights")
}

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

model GameScenario {
  id             String        @id @default(uuid()) @db.Uuid
  code           String        @unique @db.VarChar(40)
  difficulty     String        @db.VarChar(20)
  title          String        @db.VarChar(150)
  situation_json Json
  choices_json   Json
  explanation    String        @db.Text

  sessions       GameSession[]

  @@map("game_scenarios")
}

model GameSession {
  id          String       @id @default(uuid()) @db.Uuid
  user_id     String       @db.Uuid
  scenario_id String       @db.Uuid
  choice_key  String       @db.VarChar(40)
  score       Int
  played_at   DateTime     @default(now()) @db.Timestamptz()

  user        User         @relation(fields: [user_id], references: [id], onDelete: Cascade)
  scenario    GameScenario @relation(fields: [scenario_id], references: [id], onDelete: Cascade)

  @@map("game_sessions")
}
```

---

## 5. Skema Database Lokal di Flutter (SQLite - 3 Tabel Backup)

Gunakan query SQL ini saat melakukan inisialisasi `sqflite` di Flutter untuk memenuhi syarat database lokal dan backup offline[cite: 4]:

```sql
-- 1. Menyimpan Sesi User & Pengaturan Utilitas (Mata Uang, Waktu, Sensor, Biometrik)
CREATE TABLE local_session_settings (
  user_id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT NOT NULL,
  role TEXT NOT NULL,
  avatar_url TEXT,
  biometric_enabled INTEGER DEFAULT 0,
  display_currency TEXT DEFAULT 'IDR',
  display_timezone TEXT DEFAULT 'WIB',
  shake_sensor_enabled INTEGER DEFAULT 1,
  tilt_sensor_enabled INTEGER DEFAULT 1
);

-- 2. Menyimpan Backup Katalog Produk & Stok untuk Mode Offline
CREATE TABLE backup_products (
  product_id TEXT,
  outlet_id TEXT,
  sku TEXT NOT NULL,
  name TEXT NOT NULL,
  category_name TEXT,
  price_idr INTEGER NOT NULL,
  stock_quantity INTEGER NOT NULL,
  reorder_level INTEGER NOT NULL,
  last_sync_at TEXT NOT NULL,
  PRIMARY KEY (product_id, outlet_id)
);

-- 3. Menyimpan Backup 50 Riwayat Struk Terakhir beserta Hash Blockchain
CREATE TABLE backup_transactions (
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

## 6. Checklist Pengujian Bertahap (6 Phase Mingguan)

### Phase 1: Fondasi Akun, Biometrik & Profil PAM
- [ ] Login berhasil menggunakan email & password (terverifikasi `argon2`/`bcrypt` di backend)[cite: 1, 2, 4].
- [ ] Tutup dan buka ulang aplikasi $\rightarrow$ muncul autentikasi sidik jari (`local_auth`)[cite: 1, 2, 4].
- [ ] Halaman Profil menampilkan foto (`avatar_url`), form Kesan & Saran matkul PAM berhasil tersimpan ke tabel `feedback`, dan tombol Logout menghapus sesi[cite: 2, 4].

### Phase 2: Katalog, Stok, Pencarian & Backup SQLite
- [ ] Pencarian nama produk dan filter per kategori/status stok berfungsi di Flutter[cite: 1, 2, 4].
- [ ] Saat online, data produk otomatis tersimpan ke tabel `backup_products` di SQLite.
- [ ] Saat koneksi internet HP dimatikan, halaman katalog tetap menampilkan produk dari SQLite.

### Phase 3: Mobile POS, Blockchain SHA-256 & Notifikasi Stok
- [ ] Input transaksi di layar Kasir (POS) berhasil memotong stok di tabel `inventory` dan mencatat log di `inventory_movements` dalam 1 transaksi DB atomik[cite: 1, 2, 3].
- [ ] Setiap transaksi otomatis memiliki `data_hash`, `prev_hash`, dan `block_hash` di tabel `blockchain_records`[cite: 2, 3].
- [ ] Tombol "Verifikasi Blockchain" di detail struk menampilkan status **VALID**, dan berubah menjadi **TAMPERED** jika angka transaksi diubah paksa di database[cite: 1, 2].
- [ ] Jika stok barang setelah transaksi $\le$ `reorder_level`, muncul notifikasi lokal di HP Android[cite: 1, 2, 3, 4].

### Phase 4: Dashboard Analitik, 3 Mata Uang, 4 Waktu & 2 Sensor
- [ ] Angka di Dashboard berubah akurat saat pengguna mengganti mata uang antara **IDR, USD, dan EUR** (mengambil kurs dari Frankfurter API)[cite: 1, 2, 4].
- [ ] Jam transaksi berubah sesuai pilihan zona waktu **WIB, WITA, WIT, dan London**[cite: 1, 2, 4].
- [ ] Menggoyangkan HP (*Accelerometer shake*) me-refresh data Dashboard[cite: 1, 2, 4].
- [ ] Memiringkan HP (*Gyroscope tilt*) mengganti tab periode grafik analitik[cite: 1, 2, 4].

### Phase 5: Peta Cabang & LBS
- [ ] Peta OpenStreetMap menampilkan titik koordinat seluruh cabang dari tabel `outlets`[cite: 1, 2, 3].
- [ ] Aplikasi membaca lokasi GPS pengguna dan menampilkan jarak (km/m) ke cabang terdekat[cite: 1, 2, 4, 5].

### Phase 6: AI Business Assistant (LLM) & Mini Game
- [ ] Pengguna mengirim pertanyaan di chat AI $\rightarrow$ server mengambil ringkasan angka penjualan/stok dari PostgreSQL $\rightarrow$ Gemini API menjawab dengan format *Data, Dugaan, dan Saran* tanpa mengarang angka[cite: 1, 2, 4].
- [ ] Pengguna memainkan 5 soal kuis *Business Decision Challenge* dan skor akhir tersimpan di tabel `game_sessions`[cite: 2, 3, 4].