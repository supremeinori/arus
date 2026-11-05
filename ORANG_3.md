# ORANG 3 — The Smart Features, Hardware Sensors & AI Lead
> **PANDUAN OPERASIONAL AI & KOMANDO SISTEM NYATA**  
> **Target Pengguna:** Anggota Tim 3 & Asisten AI (Antigravity / LLM).  
> **Prasyarat Wajib:** Pastikan AI telah membaca [`MASTER_UNDERSTAND.md`](file:///c:/MyProjects/arus/MASTER_UNDERSTAND.md) terlebih dahulu.

---

## 1. AI OPERATIONAL DIRECTIVE & SYSTEM LOCK

Jika Anda adalah asisten AI yang mendampingi **Orang 3**:
1. **Fokus Terkunci (Role-Lock):** Anda adalah Co-Pilot khusus untuk **Integrasi Sensor Mobile (Accelerometer & Gyroscope), Location-Based Services (LBS & Peta Haversine GPS), Dashboard Business Intelligence, Sistem Pendukung Keputusan (Rule-based Insights), ARUS AI Copilot (Google Gemini LLM & Voice TTS/STT), Mini Game Bisnis, dan Form Kesan/Saran PAM**.
2. **Larangan Melebar:** JANGAN membahas secara mendalam konfigurasi JWT/argon2id atau backend blockchain (milik Orang 1), maupun arsitektur internal SQLite antrean offline kasir (milik Orang 2), kecuali sebatas pemanfaatan datanya di analitik dan AI.
3. **Wajib Memeriksa Berkas Kode Nyata:** Sebelum memberikan jawaban atau penjelasan teknis kepada Orang 3, Anda **WAJIB membaca dan merujuk** berkas-berkas berikut di workspace:
   - Sensor Perangkat Keras: [`lib/features/sensors/presentation/sensor_provider.dart`](file:///c:/MyProjects/arus/lib/features/sensors/presentation/sensor_provider.dart), [`sensor_test_screen.dart`](file:///c:/MyProjects/arus/lib/features/sensors/presentation/sensor_test_screen.dart)
   - LBS & Peta Cabang: [`lib/features/outlets/presentation/outlet_list_screen.dart`](file:///c:/MyProjects/arus/lib/features/outlets/presentation/outlet_list_screen.dart), [`widgets/outlet_map_widget.dart`](file:///c:/MyProjects/arus/lib/features/outlets/presentation/widgets/outlet_map_widget.dart)
   - Dashboard & Grafik fl_chart: [`lib/features/dashboard/presentation/dashboard_screen.dart`](file:///c:/MyProjects/arus/lib/features/dashboard/presentation/dashboard_screen.dart), [`lib/features/analytics/presentation/analytics_screen.dart`](file:///c:/MyProjects/arus/lib/features/analytics/presentation/analytics_screen.dart)
   - Decision Support (Aturan): [`api/src/modules/insights/insights.service.ts`](file:///c:/MyProjects/arus/api/src/modules/insights/insights.service.ts)
   - AI Business Copilot (Gemini): [`api/src/modules/ai/ai.service.ts`](file:///c:/MyProjects/arus/api/src/modules/ai/ai.service.ts), [`ai_business_engine.ts`](file:///c:/MyProjects/arus/api/src/modules/ai/ai_business_engine.ts)
   - Voice Engine (TTS/STT): [`api/src/modules/ai/tts.service.ts`](file:///c:/MyProjects/arus/api/src/modules/ai/tts.service.ts), [`arus_voice_spec.md`](file:///c:/MyProjects/arus/arus_voice_spec.md), [`lib/features/ai_assistant/presentation/ai_home_screen.dart`](file:///c:/MyProjects/arus/lib/features/ai_assistant/presentation/ai_home_screen.dart)
   - Mini Game Bisnis: [`lib/features/game/presentation/game_home_screen.dart`](file:///c:/MyProjects/arus/lib/features/game/presentation/game_home_screen.dart), [`minigame_design.md`](file:///c:/MyProjects/arus/minigame_design.md)
   - Kesan & Saran PAM: [`lib/features/feedback/presentation/feedback_screen.dart`](file:///c:/MyProjects/arus/lib/features/feedback/presentation/feedback_screen.dart)

---

## 2. Peta Fitur & Tanggung Jawab Orang 3

Orang 3 memegang kendali atas fitur-fitur tercanggih sistem ARUS (*smart, hardware-integrated & interactive*):

| Kode Fitur | Nama Fitur | Kriteria Dosen PAM | File Kunci di Codebase |
| :---: | :--- | :--- | :--- |
| **Fitur 5** | Form Umpan Balik Kesan & Saran PAM | Bottom Nav: Menu Saran PAM | `lib/features/feedback/presentation/feedback_screen.dart` |
| **Fitur 19** | Dashboard Analitik & Grafik fl_chart | Business Analytics & Charts | `lib/features/dashboard/presentation/dashboard_screen.dart` |
| **Fitur 22** | Sensor 1: Accelerometer (*Shake to Refresh*) | Sensor 1: Accelerometer | `lib/features/sensors/presentation/sensor_provider.dart` |
| **Fitur 23** | Sensor 2: Gyroscope (*Mini Game Tilt Control*) | Sensor 2: Gyroscope | `lib/features/game/presentation/game_home_screen.dart` |
| **Fitur 24** | Peta Cabang OpenStreetMap & GPS Haversine | Fasilitas LBS & Web Service | `lib/features/outlets/presentation/widgets/outlet_map_widget.dart` |
| **Fitur 25** | Rule-Based Decision Support (Insights) | Fitur AI Sesuai Tema | `api/src/modules/insights/insights.service.ts` |
| **Fitur 26** | ARUS AI Copilot (Gemini LLM & Voice) | Fitur AI & LLM Sesuai Tema | `api/src/modules/ai/ai.service.ts` |
| **Fitur 27** | Mini Game Bisnis (*Guess the Menu*) | Mini Game Terkait Konsep | `lib/features/game/presentation/game_home_screen.dart` |

---

## 3. Bedah Teknis Sistem Nyata (Deep Dive Codebase)

### 3.1 Integrasi 2 Sensor Hardware (`sensors_plus`)
* **Lokasi Kode:** [`lib/features/sensors/presentation/sensor_provider.dart`](file:///c:/MyProjects/arus/lib/features/sensors/presentation/sensor_provider.dart)
* **Sensor 1 — Accelerometer (Guncangan / Shake):**
  - Mengukur percepatan linear perangkat pada tiga sumbu ($x, y, z$).
  - Perhitungan magnitudo vektor:
    $$\text{Magnitude} = \sqrt{x^2 + y^2 + z^2}$$
  - **Deteksi Guncangan:** Jika $\text{Magnitude} > 15.0\text{ m/s}^2$ (melebihi gravitasi bumi $9.8\text{ m/s}^2$ secara signifikan), aplikasi memicu event *Shake*.
  - **Efisiensi Daya:** Menggunakan filter debouncing (jeda 500 ms) agar guncangan tidak memicu *re-fetch* API secara beruntun dan mencegah boros baterai. Pada Dashboard, guncangan memicu pembaruan data omzet secara interaktif.
* **Sensor 2 — Gyroscope (Kemiringan / Tilt):**
  - Mengukur kecepatan sudut rotasi perangkat (rad/s) pada sumbu pitch dan roll.
  - **Diintegrasikan ke Mini Game** dengan mekanisme **Instant Tilt Answer**: memiringkan perangkat ke kiri/kanan melewati ambang **22°** → jawab terpilih **seketika** tanpa tahan/tap layar.
  - Implementasi: [`lib/features/game/presentation/game_home_screen.dart`](file:///c:/MyProjects/arus/lib/features/game/presentation/game_home_screen.dart) menggunakan `TiltInstantTrigger` + `detect2WayTilt` (threshold 22°, auto-lock per soal via `_isTriggered` + `_isAnswerChecked`).

### 3.2 Location-Based Services (LBS) & Formula Haversine
* **Lokasi Kode:** [`lib/features/outlets/presentation/widgets/outlet_map_widget.dart`](file:///c:/MyProjects/arus/lib/features/outlets/presentation/widgets/outlet_map_widget.dart) & [`outlets_repository.dart`](file:///c:/MyProjects/arus/lib/features/outlets/data/outlets_repository.dart)
* **Komponen:**
  - Menggunakan package `geolocator` untuk mendapatkan koordinat GPS pengguna secara realtime (`latitude`, `longitude`).
  - Merender peta interaktif OpenStreetMap menggunakan `flutter_map`.
* **Formula Haversine (Kalkulasi Jarak Cabang):**
  Untuk menghitung jarak garis lurus terdekat antara posisi HP $(\phi_1, \lambda_1)$ dan cabang toko $(\phi_2, \lambda_2)$ dengan memperhitungkan kelengkungan bumi berbentuk speroid ($R = 6.371\text{ km}$):
  $$a = \sin^2\left(\frac{\Delta \phi}{2}\right) + \cos(\phi_1)\cos(\phi_2)\sin^2\left(\frac{\Delta \lambda}{2}\right)$$
  $$c = 2 \cdot \arctan2\left(\sqrt{a}, \sqrt{1 - a}\right)$$
  $$d = R \cdot c$$
  Hasil kalkulasi $d$ disajikan di UI dalam format kilometer: *"1.4 km dari lokasi Anda"*, dan cabang diurutkan otomatis dari yang terdekat.

### 3.3 Decision Support System & AI Gemini Copilot dengan Context Grounding
* **Lokasi Kode:** [`api/src/modules/insights/insights.service.ts`](file:///c:/MyProjects/arus/api/src/modules/insights/insights.service.ts) & [`api/src/modules/ai/ai.service.ts`](file:///c:/MyProjects/arus/api/src/modules/ai/ai.service.ts)
* **Rule-Based Insights (Deterministik):**
  - Evaluasi *on-the-fly* terhadap database:
    - `LOW_STOCK`: Bahan baku dengan sisa stok $\leq$ `reorder_level`.
    - `RESTOCK_URGENT`: Bahan baku habis total ($= 0$) yang menahan penjualan menu utama.
    - `SLOW_MOVING`: Produk yang tidak terjual sama sekali dalam 7 hari terakhir.
* **ARUS AI Copilot (Google Gemini LLM):**
  - **Mencegah Halusinasi dengan *Context Grounding*:** Sebelum request prompt dikirim ke Gemini API, backend Express terlebih dahulu menjalankan kueri agregasi SQL ke PostgreSQL untuk mengambil angka riil (total omzet hari ini, produk paling laku, sisa stok bahan kritis).
  - Fakta-fakta angka ini disuntikkan (*injected*) ke dalam system prompt Gemini dengan instruksi bahwa AI dilarang mengarang angka fiktif.
  - Format respon AI diwajibkan mengikuti pola analisis bisnis profesional:
    1. **Data Riil:** Menampilkan fakta angka yang ditemukan di toko.
    2. **Dugaan Analisis:** Menjelaskan kemungkinan penyebab tren tersebut.
    3. **Rekomendasi Langkah:** Tindakan operasional konkret yang disarankan untuk pemilik bisnis.

### 3.4 Voice Assistant Engine (Microsoft Edge TTS & Google STT)
* **Lokasi Kode:** [`api/src/modules/ai/tts.service.ts`](file:///c:/MyProjects/arus/api/src/modules/ai/tts.service.ts) & [`arus_voice_spec.md`](file:///c:/MyProjects/arus/arus_voice_spec.md)
* **Dua Arah Interaksi Suara:**
  - **Mendengar (Speech-to-Text):** User menekan tombol mikrofon di Flutter (`speech_to_text`) untuk mendiktekan pertanyaan bisnis secara lisan.
  - **Menjawab (Text-to-Speech):** Backend Express memproses respons Gemini, mengekstrak ringkasan lisan bebas markdown, lalu memanggil Microsoft Edge TTS dengan suara natural Bahasa Indonesia **`id-ID-GadisNeural`**. File audio dikirim ke Flutter dalam format Base64 string dan diputar menggunakan `just_audio`.

### 3.5 Mini Game Bisnis ("Guess the Menu")
* **Lokasi Kode:** [`lib/features/game/presentation/game_home_screen.dart`](file:///c:/MyProjects/arus/lib/features/game/presentation/game_home_screen.dart) & [`minigame_design.md`](file:///c:/MyProjects/arus/minigame_design.md)
* **Keunggulan Arsitektur:**
  - Tidak menggunakan bank soal statis. Seluruh kuis dihasilkan **dinamis dari tabel `products`**. Jika Owner menambah menu baru di POS, menu tersebut otomatis bisa muncul di dalam game!
  - **2 Mode Permainan:**
    1. `guess_name`: Diberikan foto menu, tebak nama produk yang tepat dari 4 opsi.
    2. `guess_price`: Diberikan nama dan foto menu, tebak harga jual aslinya.
  - Setiap ronde berisi 5 soal dengan batas waktu 10 detik per soal, bonus kecepatan waktu, dan skor akhir dicatat ke tabel `game_sessions`.

### 3.6 AI Sales & Stockout Forecasting (Model Deret Waktu Statistik)
* **Lokasi Kode:** [`analytics.service.ts`](file:///c:/MyProjects/arus/api/src/modules/analytics/analytics.service.ts) (`getSalesForecast`, `getStockoutForecast`) & [`analytics_repository.dart`](file:///c:/MyProjects/arus/lib/features/analytics/data/analytics_repository.dart) (`_computeLocalSalesForecast`)
* **Sales Forecast 7–30 Hari (online dan offline):**
  - **Kalender bisnis mengikuti zona waktu outlet:** hari dimulai pukul 00:00 waktu cabang, bukan UTC, sehingga transaksi malam tidak dianggap hari parsial.
  - **Kalender kontinu:** jendela histori minimal 30 hari; hari tanpa transaksi tetap dihitung sebagai Rp 0, bukan dibuang.
  - **Base level EWMA** dengan $\alpha = 0.35$: hari terbaru berbobot lebih besar, sehingga penurunan omzet langsung terasa.
  - **Shrinkage data minim:** base level ditarik ke rata-rata jendela dengan bobot $activeDays/(activeDays+5)$, agar satu hari spike tidak langsung dianggap tren permanen.
  - **Tren linear 14 hari** pada indeks kalender, dihaluskan dengan peredaman Holt ($\phi = 0.92$) dan dibatasi maksimum $\pm 6\%$ dari base level.
  - **Musiman hari-dalam-minggu** memakai *Bayesian shrinkage*: kredibilitas data $= \frac{count}{count + 5}$, sehingga pola ritel tidak mendominasi saat data masih sedikit.
  - **Faktor kekeringan (drought):** jika $N$ hari terakhir berturut-turut tanpa transaksi, proyeksi dikali $0.7^{\min(N-1, 6)}$. Contoh: 4 hari sepi membuat proyeksi turun sekitar 76%.
  - **Growth %** dibandingkan dengan horizon hari selesai terakhir. Jika periode pembanding Rp 0, growth ditetapkan 0% agar tidak muncul angka palsu.
  - **Guard data minim:** minimal 3 hari aktif; di bawah itu status `insufficient_history`, growth 0%, dan proyeksi ditandai indikatif.
  - **Fallback offline:** algoritma yang sama dihitung dari `backup_transactions` SQLite, dengan status `offline_evaluated` atau `offline_insufficient_history`.
* **Stockout Forecast:**
  - **Kecepatan konsumsi harian** = total pemakaian bahan 14 hari terakhir $\div$ 14.
  - **Hari habis stok** = $\lfloor stok \div velocity \rfloor$; status `critical` jika $\leq 2$ hari, `warning` jika $\leq 6$ hari atau stok $\leq$ `reorder_level`.
  - **Rekomendasi restock** = $\max(velocity \times 7 + reorder\_level - stok,\ velocity \times 5)$, lalu dikalikan `cost_per_unit` untuk estimasi biaya.
* **Kejujuran teknis:** modul ini **bukan** panggilan Google Gemini. Ini model statistik deterministik yang bisa dihitung ulang dan diuji. Gemini hanya dipakai pada AI Copilot percakapan.

---

## 4. Batasan Narasi Presentasi (Scope Boundaries)

### Yang HARUS Dijelaskan oleh Orang 3:
- Visualisasi metrik bisnis pada Dashboard & grafik tren fl_chart.
- Integrasi sensor hardware mobile: Accelerometer (Shake to Refresh) dan Gyroscope (Mini Game Tilt Control).
- Layanan peta LBS, integrasi OpenStreetMap, dan perhitungan matematis rumus Haversine GPS.
- Kecerdasan buatan: Rule-based Decision Support dan AI Gemini Copilot dengan Context Grounding fakta database nyata.
- AI Sales & Stockout Forecasting: EWMA, tren kalender, musiman Bayesian, faktor drought, dan velocity konsumsi 14 hari.
- Fitur Voice Asisten audio TTS suara GadisNeural.
- Gamifikasi kuis operasional bisnis (*Guess the Menu*).
- Penutup resmi presentasi dengan formulir Kesan & Saran Mata Kuliah PAM.

### Yang BUKAN Bagian Orang 3 (Delegasikan ke Rekan):
- "Bagaimana otentikasi login, token rotation, dan transaksi atomik POS di backend?" $\rightarrow$ **Lempar ke Orang 1 (Backend & Security).**
- "Bagaimana kasir bisa tetap jualan saat offline dan auto-sync SQLite?" $\rightarrow$ **Lempar ke Orang 2 (Offline & Client).**

---

## 5. Skenario Live Demo (Runbook Presentasi)

Ikuti urutan langkah demo ini agar presentasi diakhiri dengan tepuk tangan meriah:

```text
[Langkah 1: Demo Sensor Accelerometer (Shake to Refresh)]
1. Di layar Beranda / Dashboard KPI penjualan, perlihatkan angka omzet saat ini.
2. Goyangkan HP secara fisik (atau kirim perintah shake di emulator).
3. Tunjukkan indikator refresh memutar di layar dan data analitik ter-update secara otomatis tanpa menekan tombol apapun.

[Langkah 2: Demo Sensor Gyroscope (Mini Game Instant Tilt Answer)]
1. Masuk ke menu "Lainnya" -> pilih "Mini Game" -> Mode "Tebak Nama Menu".
2. Saat soal muncul, miringkan HP ke **kiri** (opsi A) atau **kanan** (opsi B) **melewati 22°**.
3. Jawaban terpilih **seketika** (tanpa tahan 3 detik), visual highlight real-time di tombol opsi, lalu lanjut soal berikutnya.

[Langkah 3: Demo Peta LBS & Haversine GPS]
1. Buka menu "Peta Cabang" di navigasi.
2. Tunjukkan peta OpenStreetMap dengan pin-pin lokasi cabang toko.
3. Tunjukkan teks informasi di bawah pin: "Cabang Terdekat: ARUS Sudirman (1.2 km dari lokasi Anda)".
4. Jelaskan bahwa jarak dihitung realtime menggunakan Formula Haversine dari sensor GPS HP.

[Langkah 4: Demo AI Copilot Gemini & Voice Audio]
1. Buka tab "AI Assistant".
2. Tekan tombol mikrofon, lalu ucapkan pertanyaan (atau ketik):
   "Bagaimana performa penjualan cabang hari ini dan apa rekomendasi untuk stok saya?"
3. Tunjukkan AI menjawab dengan struktur rapi (Data Riil dari database, Analisis Masalah, dan Rekomendasi).
4. Biarkan suara Microsoft Edge TTS (id-ID-GadisNeural) membacakan ringkasan jawaban melalui speaker HP.

[Langkah 5: Demo AI Sales & Stockout Forecast]
1. Buka tab "Analitik" -> bagian "Prediksi Penjualan".
2. Tunjukkan grafik histori 30 hari dan proyeksi 7 hari ke depan beserta rentang keyakinan.
3. Jelaskan bahwa hari tanpa transaksi tetap dihitung Rp 0, dan proyeksi otomatis turun saat beberapa hari terakhir sepi (drought factor).
4. Buka bagian "Peramalan Stok" -> tunjukkan status critical/warning/safe dan tanggal perkiraan bahan habis.

[Langkah 6: Demo Mini Game "Guess the Menu"]
1. Masuk ke menu "Lainnya" -> pilih "Mini Game".
2. Pilih Mode "Tebak Nama Menu" -> mulai permainan (5 soal).
3. Jawab 1-2 soal kuis tebak foto produk POS -> tunjukkan timer hitung mundur dan pertambahan skor.
4. Selesaikan sesi game hingga skor akhir muncul.

[Langkah 7: Penutup Resmi — Form Kesan & Saran PAM]
1. Kembali ke menu "Lainnya" -> klik "Kesan & Saran PAM".
2. Tunjukkan form testimoni perkuliahan Pemrograman Aplikasi Mobile.
3. Sampaikan ucapan terima kasih kepada dosen pembimbing dan tutup presentasi tim.
```

---

## 6. Cheatsheet Ujian Dosen & Jawaban Mantap

* **Dosen:** *"Apakah AI Gemini kalian tidak mengarang bebas (*halusinasi*) saat ditanya kondisi omzet dan stok toko?"*
  * **Jawaban:** *"Tidak, Bu/Pak. Kami menerapkan teknik arsitektur **Context Grounding**. Sebelum prompt pengguna diteruskan ke Google Gemini API, backend Express kami terlebih dahulu mengeksekusi kueri SQL ke PostgreSQL untuk mengumpulkan fakta angka aktual (omzet hari ini, produk paling laris, dan sisa stok bahan baku). Angka-angka faktual ini kemudian disuntikkan ke dalam system prompt Gemini sebagai satu-satunya rujukan data. Model diinstruksikan secara ketat untuk menyajikan analisis berdasarkan fakta tersebut dengan struktur: Data Riil, Dugaan Analisis, dan Rekomendasi Solusi."*

* **Dosen:** *"Apakah modul AI Forecasting juga memakai Gemini dan bisa berhalusinasi?"*
  * **Jawaban:** *"Tidak, Bu/Pak. Modul Forecasting sengaja kami buat sebagai **model statistik deterministik**, bukan panggilan LLM. Penjualan dihitung dengan EWMA, tren kalender, musiman hari-dalam-minggu, dan faktor drought; stok dihitung dari velocity pemakaian 14 hari terakhir. Karena input dan rumusnya tetap, hasilnya dapat dihitung ulang dan diuji otomatis. Gemini hanya kami pakai di AI Copilot percakapan, itu pun dengan Context Grounding ke database."*

* **Dosen:** *"Kenapa proyeksi penjualan turun saat toko sedang sepi, bukan justru naik terus?"*
  * **Jawaban:** *"Kami tidak membuang hari tanpa transaksi. Hari bernilai Rp 0 tetap masuk kalender dan ikut menurunkan EWMA serta tren. Selain itu ada **drought factor**: bila N hari terakhir berturut-turut tanpa transaksi, proyeksi dikali 0.7^(N-1) dengan batas 6 tingkat. Jadi model bereaksi terhadap performa terbaru, bukan menaikkan angka secara palsu."*

* **Dosen:** *"Bagaimana cara kerja penghitungan jarak di peta cabang LBS dan kenapa pakai rumus Haversine?"*
  * **Jawaban:** *"Kami mengambil koordinat GPS perangkat secara realtime menggunakan package `geolocator`, kemudian membandingkannya dengan koordinat `latitude` dan `longitude` cabang yang ada di tabel `outlets`. Kami menggunakan **Formula Haversine** karena permukaan bumi tidak datar melainkan speroid melengkung. Rumus ini menghitung jarak lingkaran besar (*great-circle distance*) berdasarkan sudut trigonometri lintang dan bujur, sehingga jarak dalam kilometer yang dihasilkan sangat akurat untuk navigasi kasir maupun pelanggan."*

* **Dosen:** *"Apakah pembacaan sensor Accelerometer dan Gyroscope secara terus-menerus tidak membuat baterai smartphone cepat habis?"*
  * **Jawaban:** *"Untuk mengoptimalkan efisiensi baterai, kami menerapkan tiga teknik: Pertama, kami menggunakan **Event Throttling & Debouncing**, di mana event sensor hanya dievaluasi setiap 300–500 ms. Kedua, kami memasang **Threshold Filter** sehingga perubahan kecil akibat getaran tangan biasa diabaikan. Ketiga, pada siklus hidup widget Flutter, stream subscription sensor selalu di-`cancel()` di method `dispose()` ketika pengguna berpindah layar, sehingga tidak terjadi memory leak maupun konsumsi daya di latar belakang."*
