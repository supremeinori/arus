# 🎮 ARUS Mini-Game Design — "Guess the Menu"

**Nama Fitur:** Guess the Menu (Fitur #27 — MOD-5)  
**Terkait Dokumen Utama:** `arus_srs_v2.md`  
**Aktor yang Dapat Mengakses:** Semua Role (Owner, Manager, Staff/Kasir)  
**Sumber Data Utama:** Tabel `products` (PostgreSQL POS Database) & Tabel `game_sessions`

---

## 1. Konsep & Tujuan Bisnis

**"Guess the Menu"** adalah mini-game kuis interaktif berdurasi singkat yang terintegrasi langsung dengan database katalog *Point of Sale* (POS) ARUS. 

* **Keterkaitan dengan Tema Bisnis:** Dalam operasional F&B/Ritel multi-outlet, kasir (*Staff*) dan manajer harus hafal visual produk serta harga jualnya agar pelayanan di kasir berjalan cepat dan akurat. Game ini berfungsi sebagai sarana *Product Knowledge & Price Familiarization* yang menyenangkan.
* **Keunggulan Arsitektur:** Tidak memerlukan tabel bank soal statis (`game_scenarios` dihapus). Seluruh pertanyaan, gambar, dan pengecoh jawaban (*distractors*) dihasilkan secara otomatis dan *real-time* dari produk aktif yang ada di tabel `products`. Jika Owner menambah menu baru atau mengubah harga di POS, soal di dalam game otomatis ikut berubah!

---

## 2. Mode Permainan (Game Modes)

Pemain dapat memilih salah satu dari **2 Mode Permainan** di layar utama Mini-Game:

### Mode 1: Tebak Nama Menu (`guess_name`)
* **Tampilan Soal:** Layar menampilkan **Foto Menu** (`products.image_url`) berukuran besar beserta petunjuk kategori produknya (misal: *Kategori: Minuman Kopi*). Nama dan harga produk disembunyikan.
* **Tugas Pemain:** Memilih **1 nama menu yang benar** dari 4 tombol pilihan ganda (`A`, `B`, `C`, `D`) yang ditampilkan di bawah gambar.
* **Cara Server Membuat Pengecoh (*Distractors*):** Backend memilih 1 produk target secara acak sebagai jawaban benar, lalu mengambil 3 nama produk aktif lainnya (diutamakan dari kategori yang sama) sebagai pilihan pengecoh.

### Mode 2: Tebak Harga Jual (`guess_price`)
* **Tampilan Soal:** Layar menampilkan **Foto Menu** (`products.image_url`) beserta **Nama Menu** (`products.name`) dan satuannya (`products.unit`).
* **Tugas Pemain:** Menebak **Harga Jual (`price_idr`)** yang tepat untuk menu tersebut dari 4 pilihan nominal harga yang tersedia.
* **Cara Server Membuat Pengecoh (*Distractors*):** 
  * Backend mengambil `price_idr` asli dari produk tersebut sebagai jawaban benar (contoh: `Rp 22.000`).
  * Backend membangkitkan 3 angka harga pengecoh yang masuk akal (dibulatkan ke ribuan terdekat, misalnya `±10%`, `±20%`, atau mengambil harga dari produk lain di database seperti `Rp 18.000`, `Rp 25.000`, `Rp 28.000`) agar pemain tetap tertantang.
  * *Catatan Mata Uang:* Harga di dalam game selalu ditampilkan dalam mata uang dasar **IDR (Rupiah)** sesuai harga kasir POS (`BR-CAT-02`).

---

## 3. Aturan Main, Batas Waktu & Sistem Poin

Setiap sesi permainan (*1 Game Session*) dirancang cepat dan ringan (selesai dalam waktu $\pm$ 30–60 detik):

1. **Jumlah Soal per Sesi:** **5 Soal** per ronde permainan.
2. **Batas Waktu (*Timer*):** Setiap soal memiliki waktu hitung mundur **10 detik** (ditampilkan dengan *progress bar* waktu di bagian atas layar).
   * Jika waktu habis sebelum pemain menekan jawaban, soal dianggap **Salah (0 Poin)** dan otomatis lanjut ke soal berikutnya.
3. ** Perhitungan Poin Sederhana:**
   * **Jawaban Benar:** Mendapatkan **+100 Poin Dasar**.
   * **Bonus Kecepatan (*Time Bonus*):** Setiap sisa detik pada timer memberikan tambahan **+10 Poin** (contoh: menjawab benar saat waktu tersisa 6 detik = $100 + (6 \times 10) = 160\text{ Poin}$).
   * **Jawaban Salah / Waktu Habis:** **0 Poin**.
   * **Skor Maksimal Ideal:** $\pm 1.000\text{ Poin}$ dalam 1 sesi (5 soal).
4. **Umpan Balik Instan (*Micro-Interaction*):**
   * Saat tombol pilihan ditekan, tombol berubah menjadi **Hijau** jika benar (disertai getaran *haptic* ringan) atau **Merah** jika salah (sambil menyorot jawaban yang benar selama 1 detik sebelum berpindah ke soal berikutnya).

---

## 4. Alur Layar UI Flutter (`lib/features/game/`)

```text
[ SC28: Game Home Screen ]
   ├── Kartu Skor Tertinggi (Personal Best) & Riwayat 5 Permainan Terakhir
   ├── Tombol Pilih Mode 1: "Tebak Nama Menu" (Ikon Gambar)
   └── Tombol Pilih Mode 2: "Tebak Harga Menu" (Ikon Rupiah)
          │
          ▼ (Fetch GET /api/game/questions?mode=...)
[ SC29: Game Play Screen (Soal 1 s/d 5) ]
   ├── Header: Nomor Soal (1/5), Skor Saat Ini, & Progress Bar Timer (10 dtk)
   ├── Area Tengah: Card Gambar Produk (Image.network dari products.image_url)
   │     └── (Jika Mode Tebak Harga: Tampilkan juga Teks Nama Produk di bawah foto)
   └── Area Bawah: 4 Tombol Pilihan Ganda (48dp touch target)
          │
          ▼ (Selesai 5 Soal -> POST /api/game/sessions)
[ SC30: Game Result / Summary Screen ]
   ├── Total Skor Akhir & Predikat (Pemula / Kasir Andal / Master Menu)
   ├── Statistik Ringkas: Jawaban Benar (misal 4/5) & Total Waktu (misal 22 detik)
   └── Tombol Aksi: "Main Lagi" atau "Kembali ke Menu"
```

---

## 5. Spesifikasi Database & Endpoint API

### 5.1 Kebutuhan Tabel & Kolom Database
1. **Tabel `products` (Sumber Soal):**
   * Wajib memiliki kolom `image_url` (Text/String).
   * Syarat pengambilan soal: Hanya produk dengan `is_active = true` dan `image_url IS NOT NULL` yang diambil menjadi soal. (Minimal terdapat $\ge 10$ produk bergambar di dalam `seed.ts`).
2. **Tabel `game_sessions` (Penyimpan Skor):**
   * `id` (UUID, PK)
   * `user_id` (UUID, FK $\rightarrow$ `users.id`)
   * `mode` (Enum: `guess_name` | `guess_price`)
   * `score` (Int — total poin sesi)
   * `correct_count` (Int — jumlah jawaban benar dari 5 soal)
   * `total_questions` (Int — default 5)
   * `duration_sec` (Int — total durasi bermain dalam detik)
   * `played_at` (Timestamptz)

### 5.2 Kontrak Endpoint REST API (`/api/game/*`)

#### 1. `GET /api/game/questions?mode=guess_name|guess_price&limit=5`
Mengambil daftar 5 soal acak yang dibangun langsung dari tabel `products`.
* **Contoh Response (`200 OK`):**
```json
{
  "data": {
    "mode": "guess_price",
    "time_limit_per_question_sec": 10,
    "questions": [
      {
        "question_no": 1,
        "product_id": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
        "image_url": "[https://images.unsplash.com/photo-1541167760496-1628856ab772?w=600](https://images.unsplash.com/photo-1541167760496-1628856ab772?w=600)",
        "category_name": "Minuman Kopi",
        "prompt_title": "Es Kopi Susu Gula Aren",
        "options": [
          { "key": "opt_1", "label": "Rp 18.000", "value": "18000" },
          { "key": "opt_2", "label": "Rp 22.000", "value": "22000" },
          { "key": "opt_3", "label": "Rp 25.000", "value": "25000" },
          { "key": "opt_4", "label": "Rp 28.000", "value": "28000" }
        ],
        "correct_option_key": "opt_2"
      }
    ]
  }
}
```
*(Catatan: Pada mode `guess_name`, field `prompt_title` bernilai `"Apakah nama menu pada gambar di atas?"` dan `options[].label` berisi 4 pilihan nama produk).*

#### 2. `POST /api/game/sessions`
Menyimpan hasil akhir permainan setelah 5 soal selesai dijawab.
* **Request Body:**
```json
{
  "mode": "guess_price",
  "score": 680,
  "correct_count": 4,
  "total_questions": 5,
  "duration_sec": 24
}
```
* **Response (`201 Created`):** Mengembalikan data sesi yang tersimpan beserta status apakah skor tersebut memecahkan rekor tertinggi pribadi (`is_new_high_score: true/false`).

#### 3. `GET /api/game/sessions/me`
Mengambil skor tertinggi (*high score*) per mode dan 10 riwayat permainan terakhir milik user yang sedang login untuk ditampilkan di layar `SC28: Game Home`.

---

## 6. Skenario Pengujian (Test Cases Update)

Menggantikan kode uji `T-GAME-01` s/d `T-GAME-03` pada dokumen SRS utama:

| Kode Uji | Skenario yang Diuji | Hasil yang Diharapkan |
|---|---|---|
| **T-GAME-01** | Request `GET /api/game/questions?mode=guess_name` | Mengembalikan 5 soal acak dari tabel `products` yang aktif dan memiliki `image_url`, masing-masing dengan 4 opsi nama unik. |
| **T-GAME-02** | Request `GET /api/game/questions?mode=guess_price` | Mengembalikan 5 soal acak dengan nama & gambar produk, serta 4 opsi harga IDR (1 harga asli `price_idr` + 3 harga pengecoh). |
| **T-GAME-03** | Submit hasil akhir ke `POST /api/game/sessions` | Data skor, mode, jumlah benar, dan durasi tersimpan di tabel `game_sessions` dan memperbarui *Personal Best* di UI. |