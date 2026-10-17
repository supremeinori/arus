# PROMPT: Perbaikan UI Flutter ARUS (Anti Error Rendering)

> Salin semua isi di bawah garis ini ke AI coding agent (Cursor / Claude Code / dll.).

---

## PERAN

Kamu adalah Flutter engineer senior. Tugasmu **hanya merapikan lapisan UI** proyek ARUS (aplikasi Android, Flutter + Riverpod) agar bebas error rendering: `hitTest() called on RenderBox`, `RenderBox was not laid out`, `unbounded height/width`, `RenderFlex overflowed`, `Incorrect use of ParentDataWidget`.

## BATAS KERJA (WAJIB DIPATUHI)

**Yang BOLEH diubah:** file di `presentation/` (screen, widget), `shared/widgets/`, `core/theme/`.

**Yang DILARANG diubah:**
- Isi file `service`, `repository`, `data/`, AI Service (prompt/personifikasi/konfigurasi), Blockchain/integrity service, dan semua logika API. Jangan dipotong, disederhanakan, atau dirapikan, berapa pun panjangnya.
- Kontrak API, nama endpoint, model data, dan business logic.
- Tidak ada batas jumlah baris per file. Jangan memecah file hanya demi memendekkan.

Kalau perbaikan UI **membutuhkan** perubahan di file terlarang, **berhenti dan tanyakan dulu**. Jangan mengubah diam-diam.

## LANGKAH KERJA (URUT, JANGAN LONCAT)

1. **Cari akar masalah.** Jalankan app, ambil **error PERTAMA** di console. Error `hitTest` dan `not laid out` hampir selalu **akibat** dari error layout sebelumnya (unbounded / overflow). Jangan memperbaiki dari error terakhir.
2. **Audit.** Telusuri semua screen. Buat tabel temuan sebelum mengubah apa pun:

   | File | Baris | Aturan yang dilanggar | Perbaikan |
   |---|---|---|---|

3. **Perbaiki per screen**, satu screen per commit. Jangan refactor semua sekaligus.
4. **Verifikasi tiap screen** (lihat bagian VERIFIKASI), baru lanjut ke screen berikutnya.
5. Jalankan `flutter analyze` sampai **0 issue**, lalu `flutter test`.

## ATURAN ANTI-CRASH LAYOUT

### A. Scroll dan list (penyebab utama unbounded height)

1. **Dilarang** `ListView` / `GridView` / `PageView` / `TabBarView` langsung di dalam `Column` tanpa `Expanded` (atau `Flexible` / `SizedBox` dengan tinggi pasti).
2. **Dilarang** list scrollable di dalam list scrollable lain (`ListView` di dalam `SingleChildScrollView`, `ListView` di dalam `ListView`).
3. Untuk halaman dengan campuran konten (kartu KPI + grafik + daftar), pakai **satu `CustomScrollView`** dengan slivers (`SliverToBoxAdapter`, `SliverList`, `SliverGrid`). Ini cara resmi menggabungkan konten campuran, tanpa `shrinkWrap`.
4. Untuk halaman **form**: satu `ListView` (atau `SingleChildScrollView` + `Column`) sebagai body. Baris dinamis di dalamnya dirender dengan `...items.map((e) => ...)`, bukan `ListView.builder` bersarang.
5. `shrinkWrap: true` + `NeverScrollableScrollPhysics()` hanya boleh untuk list **kecil dan tetap** (di bawah 20 item). Wajib diberi komentar alasannya.
6. `Expanded` / `Flexible` hanya sebagai **anak langsung** dari `Row`, `Column`, atau `Flex`. Jangan di dalam `Padding`, `Container`, atau `Stack` (memicu `ParentDataWidget`).

### B. Lebar (unbounded width)

7. `TextField`, `TextFormField`, `DropdownButtonFormField`, dan `Text` dinamis di dalam `Row` **wajib** dibungkus `Expanded` / `Flexible`.
8. Semua `Text` dinamis (nama produk, nama outlet, pesan error) diberi `maxLines` + `overflow: TextOverflow.ellipsis`, kecuali memang harus tampil penuh.
9. `ListTile` tidak boleh punya `trailing` / `leading` yang lebarnya tak terbatas. Beri `SizedBox(width: ...)`.
10. `DataTable` atau tabel lebar dibungkus `SingleChildScrollView(scrollDirection: Axis.horizontal)`.

### C. Komponen khusus ARUS yang sering crash

11. **Grafik (`fl_chart`)** wajib diberi tinggi pasti: `SizedBox(height: 220, child: LineChart(...))` atau `AspectRatio`. Jangan taruh langsung di `Column` / `ListView`.
12. **Peta (`flutter_map`)** wajib dalam `Expanded` atau `SizedBox(height: ...)`.
13. **`TabBarView`** wajib dalam `Expanded`. Isi tiap tab yang bisa scroll punya scroll sendiri, bukan scroll induk.
14. **Bottom sheet dengan input** (Penyesuaian Stok, dll.): `isScrollControlled: true` + padding `MediaQuery.of(context).viewInsets.bottom`.
15. **Dialog**: konten dibatasi `ConstrainedBox(maxWidth: ...)`. Jangan `Column` tanpa `mainAxisSize: MainAxisSize.min`.
16. **Stack**: anak yang harus memenuhi area pakai `Positioned.fill`.
17. Shell bottom-nav (`go_router` `ShellRoute`): tiap tab punya `Scaffold` sendiri atau `Scaffold` induk saja, **jangan keduanya** yang punya `bottomNavigationBar`.

### D. Layar POS Kasir (aplikasi ini untuk HP)

18. Target utama adalah **HP portrait (360 dp)**. Layar POS di HP: katalog (grid produk) memakai `Expanded`, keranjang lewat tombol FAB atau bottom sheet / layar Keranjang terpisah (SC08).
19. Split view `Row` dengan kiri `Expanded(flex: 7)` dan kanan `SizedBox(width: 380)` **hanya** boleh dipakai jika lebar layar cukup. Bungkus dengan `LayoutBuilder`:
    - `constraints.maxWidth >= 840` → split view (tablet / landscape).
    - di bawah itu → tata letak HP (aturan 18).
    Tanpa pengecekan ini, panel 380 dp akan overflow di layar 360 dp.
20. Setiap panel di dalam split view harus punya batas ukuran jelas sebelum menerima sentuhan (hitTest): panel kiri `Expanded`, panel kanan lebar pasti, dan isi tiap panel adalah satu scrollable dalam `Expanded`.

### E. Struktur kode UI

21. `build()` hanya **menyusun tampilan**. Dilarang: perhitungan berat, parsing, pemanggilan API, `DateTime.now()` yang menentukan struktur, membuat controller / stream di dalam `build()`.
22. Pindahkan state dan logika ke Riverpod provider/notifier. Widget hanya `ref.watch` lalu render.
23. Pecah widget besar menjadi widget kecil **berbentuk class** (bukan fungsi `_buildX()` yang panjang). Beri `const` bila bisa.
24. Semua data dari server dirender lewat satu komponen `AsyncStateView` (loading / empty / error / data). Jangan ada `if (loading)` yang tersebar.
25. Setelah `await`, cek `if (!context.mounted) return;` sebelum memakai `context`. Subscription sensor/timer di-`cancel` saat dispose.
26. Jangan memanggil `setState` / `ref.read(...).state = ...` di dalam `build()`.

### F. Tema dan komponen reusable

27. Satu `ThemeData` Material 3 di `core/theme/`: `inputDecorationTheme`, `elevatedButtonTheme`, `cardTheme`, `appBarTheme`, `textTheme`. Hapus styling berulang per screen.
28. Buat komponen bersama di `shared/widgets/`: `AppTextField`, `AppDropdown`, `PrimaryButton`, `KpiCard`, `MoneyText`, `EmptyState`, `AsyncStateView`. Komponen input sudah menangani lebar sendiri (aman di dalam `Row`).
29. Jangan memakai warna / ukuran font langsung di screen. Ambil dari tema.

## PENGECEKAN OTOMATIS UNTUK AGEN

Cari dan tandai pola berisiko (pakai grep, lalu cek satu per satu):
- `Column(` yang punya anak `ListView` / `GridView` / `TabBarView` / `PageView`
- `ListView` / `GridView` di dalam `SingleChildScrollView`
- `Row(` yang punya anak `TextField` / `TextFormField` / `DropdownButtonFormField` tanpa `Expanded` / `Flexible`
- `Expanded(` / `Flexible(` yang induknya bukan `Row` / `Column` / `Flex`
- `LineChart(` / `BarChart(` / `FlutterMap(` tanpa tinggi pasti
- `showModalBottomSheet(` berisi input tanpa `isScrollControlled`
- `SizedBox(width: 3` / `width: 4` (lebar tetap besar) di layar HP
- `_build...()` method panjang di dalam `build()`

## VERIFIKASI (SETIAP SCREEN)

- Jalankan di emulator **360×640** dan **412×915**. Tidak boleh ada garis kuning-hitam overflow.
- Uji **text scale 1.3** (Settings → font size). Layout tidak boleh pecah.
- Uji **keyboard terbuka** di semua screen yang punya input. Tombol dan field tidak tertutup.
- Uji **rotasi** (screen yang tidak dikunci portrait).
- Uji state: loading, kosong, error, dan data panjang (nama produk 60 karakter).
- Tambahkan **widget test** minimal untuk screen yang diperbaiki: `pumpWidget` di ukuran 360×640, pastikan `tester.takeException()` bernilai `null`.
- `flutter analyze` = 0 issue. `flutter test` hijau.

## FORMAT LAPORAN AKHIR

1. Tabel temuan (sebelum) dan perbaikan (sesudah), per file.
2. Daftar file yang diubah. **Konfirmasi tertulis bahwa tidak ada file service / repository / AI / blockchain / API yang diubah.**
3. Hasil `flutter analyze` dan `flutter test`.
4. Daftar hal yang belum bisa diperbaiki beserta alasannya (misalnya butuh perubahan di file terlarang).
