# 📦 MOD-2: Operasional — Menu, Resep, Bahan Baku (Inventaris) & Kasir POS

**Versi Modul:** 2.2 (Revisi Arsitektur *Recipe-Driven Inventory / Bill of Materials* & User Flow per Role)  
**Terkait Dokumen Utama:** `arus_srs_v2.md`[span_0](start_span)[span_0](end_span)  
**Cakupan Fitur Wajib PAM:** Fitur #8 s/d Fitur #15[span_1](start_span)[span_1](end_span)  

---

## 1. Konsep Inti Arsitektur: Bahan Baku vs Menu Jualan

Berbeda dengan ritel barang jadi, operasional bisnis F&B multi-outlet ARUS memisahkan secara tegas antara **Bahan Baku di Gudang (`ingredients`)** dan **Menu Jualan di Kasir (`products`)**, namun keduanya saling terhubung erat melalui **Resep (`product_recipes`)**:

1. **Database Menu Jualan (`products`):** Menyimpan informasi produk yang dijual di kasir (nama menu seperti *Cappuccino* atau *Americano*, SKU, kategori, foto `image_url` untuk POS & Mini-Game *"Guess the Menu"*, serta harga jual `price_idr`). Tabel ini **tidak menyimpan angka stok secara langsung**.
2. **Database Bahan Baku & Stok per Cabang (`ingredients`):** Menyimpan stok bahan mentah di masing-masing cabang (`outlets`), seperti *Biji Kopi*, *Air Mineral*, *Susu UHT*, dan *Gula Aren* dalam satuan dasar (`gram`, `ml`, `pcs`).
3. **Jembatan Resep (`product_recipes`):** Menghubungkan Menu dengan Bahan Baku karena setiap produk membutuhkan takaran bahan baku tertentu untuk dibuat menjadi 1 porsi (`amount_needed`).
4. **Kalkulasi Estimasi Porsi Dinamis (*Real-Time Portion Estimation*):**
   Kuota porsi sebuah menu yang tampil di layar Kasir dihitung secara otomatis oleh sistem berdasarkan jumlah bahan baku yang tersedia di cabang tersebut (mengambil nilai porsi terkecil dari bahan baku yang paling cepat habis / *bottleneck*):
   $$\text{Estimasi Porsi} = \min_{i \in \text{Resep}} \left\lfloor \frac{\text{Stok Bahan Baku}_i}{\text{Takaran per Porsi}_i} \right\rfloor$$

---

## 2. Alur Penggunaan Sistem per Role (User Flow)

### 👑 A. Flow Owner (Kendali Penuh Bahan Baku di Semua Cabang)
Owner bertanggung jawab memastikan ketersediaan seluruh bahan baku di setiap cabang aman:
1. **Owner login** ke dalam aplikasi ARUS[span_2](start_span)[span_2](end_span).
2. Owner membuka menu **Inventory & Stock (Bahan Baku)**.
3. Owner **memilih cabang** yang ingin dikelola melalui pemilih cabang (*Outlet Selector*, misalnya memilih Cabang Jakarta, Makassar, Jayapura, atau London)[span_3](start_span)[span_3](end_span).
4. Owner melakukan **Create Bahan Baku** baru untuk cabang tersebut (misal: menginput bahan baku *Air*, *Biji Kopi*, *Susu UHT*, menentukan satuan `ml`/`gram`, stok awal, serta batas minimum peringatan `reorder_level`).
5. Owner dapat **menambah stok (*Restock*)**, melakukan **koreksi stok (*Correction*)**, mencatat bahan baku rusak/terbuang (**Waste**), melihat riwayat mutasi di `inventory_movements`, hingga **menghapus (*Delete*)** data bahan baku dan stok di cabang mana pun.
6. Saat membuat atau mengedit Menu Jualan di Katalog, Owner menghubungkan menu tersebut dengan bahan baku yang dibutuhkan beserta takarannya per porsi.

### 👔 B. Flow Manager (Kendali Penuh Hanya di Cabang yang Ditugaskan)
Manager menjalankan alur operasional bahan baku yang **sama persis dengan Owner**, namun dibatasi oleh cakupan cabang (*outlet scope*)[span_4](start_span)[span_4](end_span):
1. **Manager login** ke dalam aplikasi ARUS[span_5](start_span)[span_5](end_span).
2. Manager membuka menu **Inventory & Stock (Bahan Baku)**.
3. Sistem secara otomatis mengunci tampilan pada **cabang yang telah di-assign oleh Owner** kepada Manager tersebut (melalui tabel `user_outlets`)[span_6](start_span)[span_6](end_span).
4. Di dalam cabangnya sendiri, Manager dapat melakukan **Create bahan baku baru** (misal: *Air*, *Kopi*, dll), **menambah stok (*Restock*)**, mengubah/koreksi stok, mencatat *waste*, serta **menghapus bahan baku dan stok**.
5. Manager tidak dapat melihat atau mengubah stok bahan baku milik cabang lain yang tidak ditugaskan kepadanya (ditolak dengan HTTP 404/403)[span_7](start_span)[span_7](end_span).

### 🛒 C. Flow Kasir / Staff (Melihat Estimasi Porsi Menu & Transaksi POS)
Kasir memiliki tampilan dan alur yang **berbeda total** dari Owner dan Manager karena fokus pada pelayanan pesanan pelanggan:
1. **Kasir login** ke dalam aplikasi ARUS dan langsung masuk ke cakupan cabang tempatnya bertugas[span_8](start_span)[span_8](end_span).
2. Kasir **tidak memiliki akses** untuk menambah, mengedit, melakukan *restock*, atau menghapus bahan baku mentah[span_9](start_span)[span_9](end_span).
3. Ketika Kasir membuka menu **Kasir (POS)** atau tab **Stok Menu**, Kasir **hanya melihat Estimasi Jumlah Porsi Menu** yang siap dijual berdasarkan sisa bahan baku yang ada saat itu.
4. **Simulasi Kasus *Shared Ingredient* (Cappuccino & Americano Saat Toko Baru Buka):**
   * Misalkan toko baru buka pagi hari dengan stok bahan baku di gudang: **Biji Kopi = `200 gram`**, **Air = `3.000 ml`**, dan **Susu UHT = `900 ml`**.
   * Resep **1 porsi Americano** membutuhkan `20 gram` Kopi + `150 ml` Air.
   * Resep **1 porsi Cappuccino** membutuhkan `20 gram` Kopi + `150 ml` Susu UHT.
   * Karena keduanya sama-sama membutuhkan **Biji Kopi**, sistem menghitung estimasi porsi awal di layar Kasir:
     * **Americano:** Kopi cukup untuk $200 \div 20 = 10\text{ porsi}$, Air cukup untuk $3.000 \div 150 = 20\text{ porsi}$ $\rightarrow$ Sistem menampilkan **Estimasi: 10 Porsi**.
     * **Cappuccino:** Kopi cukup untuk $200 \div 20 = 10\text{ porsi}$, Susu cukup untuk $900 \div 150 = 6\text{ porsi}$ $\rightarrow$ Sistem menampilkan **Estimasi: 6 Porsi**.
   * Ketika Kasir menjual **2 porsi Cappuccino**, stok Biji Kopi otomatis berkurang $40\text{ gram}$ (tersisa `160 gram`) dan Susu berkurang $300\text{ ml}$ (tersisa `600 ml`).
   * Detik itu juga, angka di layar Kasir ter-update otomatis: estimasi **Cappuccino** turun menjadi **4 Porsi**, dan estimasi **Americano** ikut turun menjadi **8 Porsi** (karena sisa kopi tinggal `160 gram` dibagi `20 gram`).
5. Jika ada bahan baku yang habis sehingga estimasi porsi bernilai `0`, menu tersebut otomatis berstatus **"Habis (Bahan Baku Kurang)"** dan tidak bisa ditambahkan ke keranjang kasir.

---

## 3. Matriks Perbandingan Hak Akses Modul 2 (RBAC)

| Kemampuan Fungsional | 👑 Owner | 👔 Manager | 🛒 Staff (Kasir) |
| :--- | :--- | :--- | :--- |
| **Pilih Cabang (*Outlet Selector*)** | Semua Cabang[span_10](start_span)[span_10](end_span) | Hanya Cabang yang Di-assign[span_11](start_span)[span_11](end_span) | Terkunci 1 Cabang Tugas[span_12](start_span)[span_12](end_span) |
| **Create Bahan Baku (Air, Kopi, dll)** | ✔ Diizinkan (Semua Cabang) | ✔ Diizinkan (Cabang Sendiri) | ❌ Ditolak (HTTP 403)[span_13](start_span)[span_13](end_span) |
| **Tambah / Restock / Koreksi / Waste Stok** | ✔ Diizinkan (Semua Cabang)[span_14](start_span)[span_14](end_span) | ✔ Diizinkan (Cabang Sendiri)[span_15](start_span)[span_15](end_span) | ❌ Ditolak (HTTP 403)[span_16](start_span)[span_16](end_span) |
| **Hapus (*Delete*) Bahan Baku & Stok** | ✔ Diizinkan (Semua Cabang) | ✔ Diizinkan (Cabang Sendiri) | ❌ Ditolak (HTTP 403)[span_17](start_span)[span_17](end_span) |
| **Lihat Riwayat Mutasi (`inventory_movements`)** | ✔ Semua Cabang[span_18](start_span)[span_18](end_span) | ✔ Cabang Sendiri[span_19](start_span)[span_19](end_span) | ❌ Ditolak (HTTP 403)[span_20](start_span)[span_20](end_span) |
| **Kelola Menu & Komposisi Resep (`products`)** | ✔ CRUD Penuh[span_21](start_span)[span_21](end_span) | ✔ CRUD Penuh[span_22](start_span)[span_22](end_span) | 👁️ Read-Only (Tanpa HPP)[span_23](start_span)[span_23](end_span) |
| **Lihat Estimasi Porsi Menu per Bahan Baku** | ✔ Ya | ✔ Ya | ✔ **Ya (Tampilan Utama Kasir)** |
| **Input Transaksi Penjualan (POS)** | ✔ Semua Cabang[span_24](start_span)[span_24](end_span) | ✔ Cabang Sendiri[span_25](start_span)[span_25](end_span) | ✔ Cabang Sendiri[span_26](start_span)[span_26](end_span) |

---

## 4. Daftar Fitur Modul 2 (Fitur 8 s/d 15)

* **Fitur 8 — Kelola Menu & Resep (CRUD Products & Recipes):** [Owner, Manager] Mengelola daftar menu makanan/minuman beserta foto (`image_url`), harga jual (`price_idr`), dan rincian takaran bahan bakunya (`product_recipes`).
* **Fitur 9 — Pencarian & Filter Katalog Menu (Dengan Estimasi Porsi):** [Semua Role] Mencari menu berdasarkan nama/SKU dan memfilter per kategori[span_27](start_span)[span_27](end_span). Setiap kartu menu menampilkan badge **Estimasi Porsi Tersedia** hasil kalkulasi dari bahan baku cabang.
* **Fitur 10 — Backup Offline Katalog & Estimasi Porsi (SQLite):** [Semua Role] Menyimpan salinan daftar menu beserta angka `estimated_portions` terakhir ke tabel SQLite `backup_products` agar tetap dapat dilihat saat perangkat *offline*[span_28](start_span)[span_28](end_span).
* **Fitur 11 — Manajemen & Filter Bahan Baku Cabang:** [Owner: Semua Cabang | Manager: Cabang Sendiri] Memilih cabang, membuat bahan baku baru (*air, kopi, susu*), menghapus bahan baku, serta memfilter status stok bahan (`ok`, `low`, `out`)[span_29](start_span)[span_29](end_span). *(Bagi Kasir/Staff, layar stok hanya menampilkan daftar estimasi porsi per menu secara Read-Only)*.
* **Fitur 12 — Penyesuaian Stok Bahan Baku (*Ingredient Adjustment*):** [Owner, Manager] Mencatat penambahan stok bahan baku (*restock*), koreksi opname (`correction`), atau bahan baku rusak/basi (`waste`) yang wajib tercatat di tabel audit `inventory_movements`[span_30](start_span)[span_30](end_span).
* **Fitur 13 — Kasir Mobile (POS) Berbasis Resep Atomik:** [Semua Role] Kasir memilih menu ke keranjang berdasarkan kuota estimasi porsi. Saat pembayaran dikonfirmasi, server menghitung total kebutuhan seluruh bahan baku dari item di keranjang, memotong stok di tabel `ingredients`, mencatat log keluar untuk tiap bahan baku di `inventory_movements`, dan menyimpan struk dalam **1 transaksi database atomik**[span_31](start_span)[span_31](end_span).
* **Fitur 14 — Pencarian Struk & Backup Transaksi (SQLite):** [Semua Role] Mencari struk berdasarkan nomor `receipt_no`, tanggal, atau metode bayar, serta mencadangkan 50 struk terakhir ke SQLite `backup_transactions`[span_32](start_span)[span_32](end_span).
* **Fitur 15 — Pembatalan Transaksi (*Void*) & Pengembalian Bahan Baku:** [Owner: Kapan Saja | Manager: Maks. 24 Jam] Membatalkan struk transaksi yang keliru, mengembalikan stok bahan baku ke tabel `ingredients` sesuai takaran resep (`void_return`), dan mencatat blok pembatalan di `blockchain_records`[span_33](start_span)[span_33](end_span).

---

## 5. Business Rules Khusus Modul 2 (BR-CAT, BR-INV, BR-POS)

* **BR-CAT-01:** Kode SKU menu bersifat unik global; harga jual (`price_idr`) dan harga modal bahan baku (`cost_per_unit`) disimpan sebagai **integer IDR**[span_34](start_span)[span_34](end_span).
* **BR-CAT-02:** Setiap menu aktif wajib memiliki minimal 1 baris bahan baku pada tabel `product_recipes` agar estimasi porsinya dapat dihitung.
* **BR-CAT-03:** Field `cost_per_unit` pada bahan baku dan `unit_cost_idr` (HPP resep) disembunyikan secara ketat dari response JSON untuk role **Staff (Kasir)**[span_35](start_span)[span_35](end_span).
* **BR-INV-01:** Rumus kalkulasi estimasi porsi untuk produk $P$ di cabang $O$:
  * Ambil semua resep $R_i$ milik produk $P$ beserta stok bahan baku terkait di cabang $O$.
  * Untuk setiap bahan baku $i$, hitung $\text{porsi}_i = \lfloor \text{stock\_qty}_i \div \text{amount\_needed}_i \rfloor$.
  * Nilai `estimated_portions` untuk produk $P$ adalah nilai terkecil ($\min$) dari seluruh $\text{porsi}_i$. Jika produk belum memiliki resep di cabang tersebut, nilai `estimated_portions = 0`.
* **BR-INV-02:** Stok bahan baku (`ingredients.stock_qty`) tidak boleh bernilai negatif (`CHECK stock_qty >= 0`)[span_36](start_span)[span_36](end_span).
* **BR-INV-03:** Setiap perubahan penambahan/pengurangan `stock_qty` pada `ingredients` wajib menulis baris catatan ke `inventory_movements` dalam transaksi database yang sama[span_37](start_span)[span_37](end_span).
* **BR-POS-01 (Validasi Bahan Baku Gabungan di Keranjang):** Jika pelanggan membeli *2 Cappuccino* dan *2 Americano* dalam satu struk yang sama, server wajib **menjumlahkan total kebutuhan Biji Kopi dari kedua menu tersebut terlebih dahulu** sebelum mengecek kecukupan stok di gudang. Jika total Biji Kopi yang dibutuhkan melebihi `stock_qty` yang ada, seluruh transaksi ditolak dengan kode `INVENTORY_INSUFFICIENT`[span_38](start_span)[span_38](end_span).
* **BR-POS-02:** Saat transaksi POS berhasil, `unit_cost_idr` pada `transaction_items` diisi dengan hasil penjumlahan HPP resep saat itu ($\sum (\text{amount\_needed}_i \times \text{cost\_per\_unit}_i)$) sebagai *snapshot* untuk laporan laba kotor[span_39](start_span)[span_39](end_span)[span_40](start_span)[span_40](end_span).

---

## 6. Skema Database Modul 2 (`prisma/schema.prisma` & SQLite)

### 6.1 Skema Prisma (PostgreSQL — Dua Tabel Terpisah Namun Terhubung Erat)

```prisma
model ProductCategory {
  id         String    @id @default(uuid()) @db.Uuid
  name       String    @unique @db.VarChar(80)
  created_at DateTime  @default(now()) @db.Timestamptz()

  products   Product[]

  @@map("product_categories")
}

// 1. DATABASE MENU / PRODUK JUALAN
model Product {
  id          String            @id @default(uuid()) @db.Uuid
  category_id String?           @db.Uuid
  sku         String            @unique @db.VarChar(40)
  name        String            @db.VarChar(120) // Contoh: "Cappuccino", "Americano"
  image_url   String?           @db.Text         // Foto untuk POS & Mini-Game "Guess the Menu"
  price_idr   Int
  is_active   Boolean           @default(true)
  created_at  DateTime          @default(now()) @db.Timestamptz()
  updated_at  DateTime          @updatedAt @db.Timestamptz()

  category    ProductCategory?  @relation(fields: [category_id], references: [id])
  recipes     ProductRecipe[]   // Terhubung erat ke bahan baku lewat resep
  txn_items   TransactionItem[]

  @@map("products")
}

// 2. DATABASE BAHAN BAKU & STOK PER CABANG
model Ingredient {
  id            String   @id @default(uuid()) @db.Uuid
  outlet_id     String   @db.Uuid
  name          String   @db.VarChar(100) // Contoh: "Biji Kopi Espresso", "Air Mineral", "Susu UHT"
  unit          String   @db.VarChar(20)  // Contoh: "gram", "ml", "pcs"
  stock_qty     Int      @default(0)      // Tidak boleh minus (>= 0)
  reorder_level Int      @default(100)    // Batas peringatan notifikasi stok tipis
  cost_per_unit Int      @default(0)      // Harga modal per 1 gram/ml/pcs dalam IDR
  updated_at    DateTime @updatedAt @db.Timestamptz()

  outlet        Outlet              @relation(fields: [outlet_id], references: [id], onDelete: Cascade)
  recipes       ProductRecipe[]
  movements     InventoryMovement[]

  @@unique([outlet_id, name])
  @@map("ingredients")
}

// 3. TABEL PENGHUBUNG RESEP (Menu <-> Bahan Baku)
model ProductRecipe {
  id            String     @id @default(uuid()) @db.Uuid
  product_id    String     @db.Uuid
  ingredient_id String     @db.Uuid
  amount_needed Int        // Takaran bahan baku untuk membuat 1 porsi menu

  product       Product    @relation(fields: [product_id], references: [id], onDelete: Cascade)
  ingredient    Ingredient @relation(fields: [ingredient_id], references: [id], onDelete: Cascade)

  @@unique([product_id, ingredient_id])
  @@map("product_recipes")
}

// 4. TABEL RIWAYAT MUTASI BAHAN BAKU (Untuk Analisis Bisnis & Audit)
model InventoryMovement {
  id             String       @id @default(uuid()) @db.Uuid
  outlet_id      String       @db.Uuid
  ingredient_id  String       @db.Uuid
  movement_type  MovementType // 'sale', 'void_return', 'restock', 'correction', 'waste'
  quantity_delta Int          // Bertanda: negatif (-) saat terpakai, positif (+) saat restock
  quantity_after Int          // Snapshot sisa stok bahan baku setelah perubahan
  transaction_id String?      @db.Uuid
  note           String?      @db.VarChar(255)
  created_by     String       @db.Uuid
  created_at     DateTime     @default(now()) @db.Timestamptz()

  ingredient     Ingredient   @relation(fields: [ingredient_id], references: [id], onDelete: Cascade)
  transaction    Transaction? @relation(fields: [transaction_id], references: [id])
  creator        User         @relation(fields: [created_by], references: [id])

  @@index([outlet_id, ingredient_id, created_at])
  @@map("inventory_movements")
}
```

### 6.2 Skema Tabel Backup Katalog di SQLite (`lib/core/storage/local_db.dart`)

```sql
CREATE TABLE IF NOT EXISTS backup_products (
  product_id TEXT,
  outlet_id TEXT,
  sku TEXT NOT NULL,
  name TEXT NOT NULL,
  image_url TEXT,
  category_name TEXT,
  price_idr INTEGER NOT NULL,
  estimated_portions INTEGER NOT NULL, -- Hasil kalkulasi estimasi porsi dari bahan baku
  last_sync_at TEXT NOT NULL,
  PRIMARY KEY (product_id, outlet_id)
);
```

---

## 7. Kontrak Endpoint REST API Modul 2

### A. Katalog Menu, Resep & Estimasi Porsi (`/api/catalog/*`)
* `GET /api/catalog/products?outlet_id=...&q=...&category_id=...`
  * **Akses:** Semua Role (Owner bebas pilih `outlet_id`; Manager & Kasir mengikuti cabang penugasan).
  * **Output:** Mengembalikan daftar menu beserta hasil kalkulasi **`estimated_portions`** secara *real-time* berdasarkan sisa bahan baku di cabang tersebut.
* `POST /api/catalog/products` — **[Owner, Manager]** Membuat menu baru beserta array `recipes: [{ ingredient_id, amount_needed }]`.
* `PUT /api/catalog/products/:id` — **[Owner, Manager]** Mengubah detail menu, harga, atau memperbarui komposisi resepnya.
* `DELETE /api/catalog/products/:id` — **[Owner, Manager]** Menonaktifkan menu (`is_active = false`).
* `GET /api/catalog/categories` & `POST /api/catalog/categories` — Mengambil dan menambah kategori menu.

### B. Manajemen Bahan Baku & Mutasi Stok (`/api/inventory/*`)
* `GET /api/inventory/ingredients?outlet_id=...&status=ok|low|out&q=...`
  * **Akses:** **Owner** (bebas pilih `outlet_id` cabang mana saja), **Manager** (hanya untuk `outlet_id` yang di-assign oleh Owner). **Kasir/Staff ditolak (403)** karena Kasir hanya melihat estimasi porsi melalui endpoint `/api/catalog/products`.
* `POST /api/inventory/ingredients` — **[Owner, Manager]** Create bahan baku baru di cabang yang dipilih (`name`, `unit`, `stock_qty` awal, `reorder_level`, `cost_per_unit`).
* `PUT /api/inventory/ingredients/:id` — **[Owner, Manager]** Mengubah detail bahan baku di cabang tersebut.
* `DELETE /api/inventory/ingredients/:id` — **[Owner, Manager]** Menghapus bahan baku dan stoknya dari cabang tersebut.
* `POST /api/inventory/adjustments` — **[Owner, Manager]** Menambah stok (*restock*), koreksi, atau mencatat bahan terbuang (*waste*) pada `ingredient_id` tertentu sekaligus mencatat `inventory_movements`.
* `GET /api/inventory/movements?outlet_id=...&ingredient_id=...` — **[Owner, Manager]** Melihat riwayat keluar-masuk bahan baku untuk analisis bisnis.

### C. Transaksi Kasir POS (`/api/transactions/*`)
* `POST /api/transactions` — **[Semua Role]** Memproses penjualan, memvalidasi total kebutuhan bahan baku gabungan di keranjang, memotong `ingredients.stock_qty`, mencatat `inventory_movements` per bahan baku yang terpakai, menciptakan hash `blockchain_records`, dan memicu notifikasi jika ada bahan baku yang turun $\le$ `reorder_level`.
* `GET /api/transactions` & `GET /api/transactions/:id` — Melihat daftar dan detail struk transaksi.
* `POST /api/transactions/:id/void` — **[Owner, Manager]** Membatalkan transaksi dan mengembalikan seluruh stok bahan baku sesuai resep ke tabel `ingredients`.
*