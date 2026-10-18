# ARUS UI/UX Overhaul & Visual Redesign Plan
**Dokumen Spesifikasi & Rencana Arsitektur Visual**  
**Target:** `lib/features/dashboard/presentation/dashboard_screen.dart` & `lib/features/pos/presentation/pos_screen.dart`  
**Tema:** Clean Modern Light Enterprise (White Canvas `#F8FAFC` + Crisp White `#FFFFFF` + Jade Tosca `#00A896`)  
**Penulis:** Senior UI/UX Engineer & Flutter Expert  

---

## 1. Filosofi Desain & Standar Visual Baru

### A. Palet Warna (Clean Modern Light)
- **Scaffold Canvas Background:** `#F8FAFC` (Slate-50 soft, bersih dan nyaman di mata).
- **Card & Surface Surface:** `#FFFFFF` (Pure White crisp).
- **Surface Hover / Subtle Tint:** `#F1F5F9` (Slate-100).
- **Hairline Border:** `1px solid #E2E8F0` (Slate-200, bebas drop-shadow tebal sesuai prinsip *anti-ai-slop*).
- **Primary Brand Accent:** **Jade Tosca (`#00A896`)** & Deep Teal (`#0D9488`).
- **Accent Glow / Fill Subtil:** `rgba(0, 168, 150, 0.08)` hingga `rgba(0, 168, 150, 0.15)`.
- **Typographic Hierarchy (GoogleFonts Lexend):**
  - KPI Hero Numerals: `26px - 30px` Bold, Slate-900 (`#0F172A`).
  - Section Titles / Sub-headings: `15px - 17px` Bold, Slate-800 (`#1E293B`).
  - Body & Interactive Labels: `13px - 14px` Medium/SemiBold, Slate-700 (`#334155`).
  - Muted / Caption Labels: `11px - 12.5px` Regular/Medium, Slate-500 (`#64748B`).
  - Status Alert: Danger Red (`#EF4444`), Warning Amber (`#F59E0B`), Success Emerald (`#10B981`).
- **Corner Radii:** Konsisten `14px - 20px` pada card bento, dan `8px - 12px` pada pills/chips.

---

## 2. Tabel Pemetaan Konteks (Visual Reference vs Data Asli ARUS)

### A. `dashboard_screen.dart` (Adaptasi Gaya "Inventix" ke Konteks ARUS)

| Komponen Visual "Inventix" | Elemen Desain Referensi | Sumber Data / State Asli Sistem ARUS | Logika & Interaktivitas Sistem |
| :--- | :--- | :--- | :--- |
| **Top Executive Header** | Profil, Logo Inventix, Search, Notifikasi | `authProvider.user`, `unreadNotificationCountProvider`, `displayCurrencyProvider`, `displayTimezoneProvider`, `integrityChainProvider` | **Kiri:** Avatar inisial user, nama outlet terpilih, badge *Blockchain Valid* (`#00A896`).<br>**Kanan:** Switcher Kurs Cepat (IDR/USD/EUR), Pill Zona Waktu (WIB/WITA/WIT), & Icon Bell notifikasi ber-badge. |
| **Hero KPI Bento (Row 2 Kartu)** | 1. *Total Revenue* (29.960 +17%)<br>2. *Product sold* (18.960 -0.6%) | `dailyProfitComparisonProvider` & `analyticsOverviewProvider` | **Kartu 1 (Omzet & Laba):** Nilai `todayRevenue` diformat via `MoneyFormatter` + Badge selisih omzet/laba (`revenuePctChange` / `profitPctChange` hijau tosca `↑` atau merah `↓`).<br>**Kartu 2 (Transaksi & ATV):** `transactionCount` total transaksi hari ini + subtitle Rata-rata Struk (ATV) `avgBasketSizeIdr`. |
| **Operational Trends Card** | Grafik batang/garis bersih + Dropdown periode bulanan | `salesTrendProvider`, `selectedDateFilterProvider`, `shakeEventProvider` | **Grafik `fl_chart`**: *Curved Area Line Chart* tosca dengan gradasi memudar ke transparan tanpa gridline semrawut.<br>**Header:** Pill filter periode (`Hari Ini`, `Kemarin`, `7 Hari`, `30 Hari`) + Indikator telemetri interaktif (*Shake/Tilt phone to refresh*). |
| **Critical Action Card** | *"Product running out of stock"* + tombol panah `→` | `ingredientsListProvider` / `inventoryListProvider` (Filter `status: 'low'`) | Menampilkan 3-4 bahan baku/stok kritis (nama, sisa kuantitas, satuan, status badge *Hampir Habis*).<br>Tombol panah `→` melakukan navigasi cepat via `context.push('/inventory')`. |
| **Performance: Top Menu** | *"Best Selling"* (List produk, foto, total sales) | `catalogItems` / `salesTrendPoint` agregat | Menampilkan menu terlaris hari ini dengan foto thumbnail circular, kategori produk, dan jumlah pesanan. |
| **Performance: Stok Health** | *"Warehouse Storage"* (Progress bar terfragmentasi %) | `ingredientsListProvider` kalkulasi rasio stok aman vs kritis | Indikator visual progres kapasitas/kesehatan stok: persentase bahan baku dalam status normal vs perlu *restock*. |

---

### B. `pos_screen.dart` (Adaptasi Gaya "RestroBit" / "Foodigo" ke Konteks ARUS)

| Komponen Visual "RestroBit" | Elemen Desain Referensi | Sumber Data / State Asli Sistem ARUS | Logika & Interaktivitas Sistem |
| :--- | :--- | :--- | :--- |
| **Header Kasir** | Logo, Search (Ctrl+I), Tombol aksi meja/draft | `posCartProvider`, `syncServiceProvider`, GoRouter `/pos/history` | Judul *Kasir POS*, Tombol Sinkronisasi Offline (dengan status indikator), Riwayat Transaksi Hari Ini, dan Tombol Reset Keranjang. |
| **Search & Kategori Pills** | Search input + Pill Kategori ("Show All", "Rice", "Beverages") | `_searchController`, `categoriesProvider`, `selectedCategoryId` | Field pencarian berlatar putih dengan border slate halus. Deretan ChoiceChip kategori horizontal dengan *pill aktif berwarna Jade Tosca*. |
| **Product Card (Grid)** | Foto makanan dominan atas, nama menu, harga, tombol `+` | `posCatalogProvider` -> `CatalogItemWithAvailability` (`product`, `maxPortions`, `isAvailable`) | **1. Atas (45-50% tinggi kartu):** Foto menu proporsional via `PosMenuThumbnail` (anti crash, selalu bounded).<br>**2. Tengah:** Nama menu (bold, max 2 baris), nama kategori (muted), dan **Badge khas ARUS `"Estimasi: X Porsi"`** (Jade Tosca) atau `"Habis"` (Merah).<br>**3. Bawah:** Harga dalam format `Rp` + Tombol **`+ ADD`** berlatar Jade Tosca (`#00A896`). |
| **Panel Keranjang (Split Desktop/Tablet)** | Panel Order #20 tetap di kanan dengan list item & tombol checkout | `posCartProvider` (`items`, `totalItemsCount`, `subtotalIdr`, `discountIdr`, `totalIdr`) | Aktif pada layar lebar (`maxWidth >= 800`). Daftar baris item dengan kontrol increment/decrement kuantitas (`-` `qty` `+`), subtotal, diskon, tombol "Kosongkan", dan tombol utama **"Checkout / Bayar"**. |
| **Floating Cart Bar (Mobile)** | Floating bottom bar / Bottom Sheet saat layar sempit | `posCartProvider`, `PosCartSheet`, `PosCheckoutSheet` | Aktif pada layar HP (`maxWidth < 800`). Bar bawah menempel rapi di atas SafeArea dengan ringkasan jumlah item, total rupiah, tombol rincian keranjang, dan tombol checkout cepat. |

---

## 3. Arsitektur Widget & Mekanisme Responsivitas

### A. Widget Hierarchy: `dashboard_screen.dart`
```text
Scaffold (backgroundColor: #F8FAFC)
├── AppBar (White, elevation 0, hairline border-bottom #E2E8F0)
│    ├── Title: "Beranda Eksekutif"
│    └── Actions: Currency Switcher (IDR/USD/EUR), Timezone Pill, Refresh Button
└── RefreshIndicator (color: Jade Tosca)
    └── SingleChildScrollView (Satu controller utama, ZERO nested-scroll collision)
        └── Padding (horizontal: 16, vertical: 16)
            └── Column
                ├── _ExecutiveHeaderCard (Avatar, Nama User, Outlet Aktif, Status Blockchain)
                ├── SizedBox(16)
                ├── _DashboardFilterBar (Dropdown Cabang & Pill Periode Hari)
                ├── SizedBox(16)
                ├── _HeroKpiBentoRow (Bento Grid 2 Kolom: Card 1 Omzet & Laba; Card 2 Transaksi & ATV)
                ├── SizedBox(16)
                ├── _OperationalTrendsCard (Curved Area Chart fl_chart + Shake Telemetry Indicator)
                ├── SizedBox(16)
                ├── _CriticalStockCard ("Stok Bahan Baku Kritis" -> Arrow ke /inventory)
                ├── SizedBox(16)
                └── _PerformanceRow (Split atau Stack: "Top Menu Terlaris" & Bar "Kesehatan Stok")
```

### B. Widget Hierarchy & LayoutBuilder: `pos_screen.dart`
```text
Scaffold (backgroundColor: #F8FAFC)
├── AppBar (White, elevation 0, border-bottom #E2E8F0)
│    ├── Leading: Back button (jika canPop)
│    ├── Title: "Kasir POS" + Outlet Name
│    └── Actions: Offline Sync Status, Riwayat Transaksi (/pos/history), Clear Cart
└── LayoutBuilder (constraints)
    └── IF constraints.maxWidth >= 800 (Tablet / Desktop Split-View)
        │
        └── Row (crossAxisAlignment: stretch)
            ├── Expanded (flex: 65) -> Katalog Area
            │   └── Column
            │       ├── _PosSearchAndCategoryHeader (Search Input + ChoiceChips Kategori)
            │       └── Expanded
            │           └── GridView.builder (crossAxisCount: 3 atau 4, childAspectRatio: 0.78 - 0.82)
            │               └── _RedesignedProductCard (Foto atas 45-50%, Judul, Badge Estimasi Porsi, Harga + ADD)
            │
            ├── VerticalDivider (width: 1, color: #E2E8F0)
            │
            └── SizedBox (width: 360 - 390) -> Permanent Right Cart Panel
                └── _PosCartDesktopPanel
                    ├── Header: "Daftar Pesanan" + Total Item
                    ├── Expanded -> ListView.separated (Item baris pesanan, minus, qty, plus, hapus)
                    └── _OrderSummaryFooter (Subtotal, Diskon, Total Bayar, Tombol "Proses Pembayaran")
        │
        └── ELSE (Mobile View < 800)
            │
            └── Column
                ├── _PosSearchAndCategoryHeader (Search Input + ChoiceChips Kategori)
                ├── Expanded
                │   └── GridView.builder (crossAxisCount: 2, childAspectRatio: 0.74 - 0.78)
                │       └── _RedesignedProductCard (Kompak dengan proporsi gambar & badge porsi jelas)
                └── _PosMobileBottomBar (Permanent SafeArea bottom bar, counter, total rupiah, tombol modal)
```

---

## 4. Spesifikasi Kartu Produk POS Baru (`_RedesignedProductCard`)

Sesuai referensi gambar "RestroBit" / "Foodigo" dan aturan khusus ARUS:
1. **Container Luar:** 
   - Latar belakang: `#FFFFFF` (Putih), border `1px solid #E2E8F0`.
   - Radius: `16px`. Efek hover/tap lembut: jika item masuk keranjang, border berubah menjadi `Jade Tosca (#00A896)` dengan background tint tipis `#F0FDFA`.
   - Jika habis (`!isAvailable`), opacity kartu `0.65`, border merah lembut `#FEE2E2`.
2. **Bagian Atas (Foto Menu Proporsional ~45% - 50% Tinggi Kartu):**
   - Menggunakan `ClipRRect(borderRadius: BorderRadius.vertical(top: Radius.circular(15)))`.
   - Memastikan hygiene layout (anti crash render box): gambar dimuat aman lewat NetworkImage dengan fallback icon fastfood estetik berlatar `#F1F5F9`.
3. **Bagian Tengah (Identitas Menu & Badge ARUS):**
   - Nama Menu: Bold `13.5px`, maksimal 2 baris, warna Slate-900 (`#0F172A`).
   - Kategori Produk: Muted `11px`, warna Slate-500 (`#64748B`).
   - **Badge Estimasi Porsi Khas ARUS:**
     - Tersedia: Background `#CCFBF1` (Tosca muda), teks Jade Tosca (`#0F766E`), tulisan: `"Estimasi: X Porsi"` (atau `"Sisa: Y / X Porsi"` jika sebagian sudah di keranjang).
     - Habis: Background `#FEE2E2` (Merah muda), teks Merah (`#B91C1C`), tulisan: `"Habis (Bahan Baku Kurang)"`.
4. **Bagian Bawah (Harga & Aksi Tambah):**
   - Harga: `product.formattedPrice` bold `13.5px`, warna Jade Tosca (`#00A896`).
   - Tombol **`+ ADD`**:
     - Tombol kapsul atau sirkular berwarna Jade Tosca (`#00A896`) dengan icon `+` putih.
     - Jika habis, tombol berubah menjadi abu-abu nonaktif dengan ikon `block`.

---

## 5. Checklist Keamanan Fungsi & Anti-Regresi

| No | Modul / Fitur | Status Garansi | Keterangan Verifikasi |
| :---: | :--- | :---: | :--- |
| 1 | **Sensor Shake-to-Refresh** | 100% Terjaga | Listener `shakeEventProvider` dipertahankan di build method untuk invalidate provider data otomatis. |
| 2 | **Sensor Gyroscope / Tilt** | 100% Terjaga | Telemetri sensor tetap aktif di modul background tanpa interferensi UI. |
| 3 | **Multi-Currency & FX Converter** | 100% Terjaga | Konversi nilai rupiah ke USD/EUR menggunakan `displayCurrencyProvider` dan `fxRatesProvider` tetap terikat. |
| 4 | **Blockchain Integrity Check** | 100% Terjaga | Validasi snapshot blok SHA-256 via `integrityChainProvider` tetap terhubung di badge status header. |
| 5 | **Perhitungan Porsi Dinamis (Bahan Baku)** | 100% Terjaga | Validasi `catalogItem.maxPortions` dan sisa porsi realtime (`remainingPortions`) saat add-to-cart tetap dicegah bila melebihi stok. |
| 6 | **Keranjang & Checkout POS** | 100% Terjaga | Mutasi keranjang `addProduct`, `decrementProduct`, `removeProduct`, `clearCart` di `posCartProvider` 100% identik. |
| 7 | **Offline Sync Engine** | 100% Terjaga | Panggilan `syncPendingTransactions()` saat inisialisasi dan via tombol AppBar tetap berfungsi penuh. |
| 8 | **Zero-Hit-Test Crash** | 100% Terjaga | Komponen thumbnail gambar dan tombol keranjang tidak akan dirender kondisional 0x0; selalu dialokasikan ukuran pasti sebelum pass layout. |
| 9 | **Zero Unbounded Height / Overflow** | 100% Terjaga | Semua `Column` di dalam list/panel memakai `Expanded`/`Flexible` dan batas flex faktor terukur; tidak ada nested scroll tanpa shrinkwrap/slivers. |

---

## 6. Status Eksekusi
- [x] Tahap 1: Planning & Spesifikasi Dokumen (`REDESIGN_PLAN.md`) selesai.
- [ ] Tahap 2: Menunggu konfirmasi / instruksi "ACC" dari user sebelum penulisan kode dimulai.
