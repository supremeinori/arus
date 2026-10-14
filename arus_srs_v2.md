# ARUS SRS v2 — Software Requirements Specification

**Versi:** 2.0  
**Proyek:** ARUS — Multi-Outlet Business Intelligence & POS System  
**Stack:** Flutter (Android) · Node.js/Express/TypeScript · PostgreSQL (Supabase) · SQLite (sqflite)  
**Dokumen ini menggantikan:** `ARUS_SRS.md` dan `ARUS_DESAIN_ADDER.md`

---

## Daftar Isi

1. [Identitas Produk](#1-identitas-produk)
2. [Modul & Aktor](#2-modul--aktor)
3. [Business Rules & Constraint](#3-business-rules--constraint)
4. [Arsitektur Teknis](#4-arsitektur-teknis)
5. [Database — Skema & Aturan](#5-database--skema--aturan)
6. [API — Kontrak & Konvensi](#6-api--kontrak--konvensi)
7. [Keamanan](#7-keamanan)
8. [Pre-Production Requirements](#8-pre-production-requirements)
9. [Production Rules](#9-production-rules)
10. [Post-Production / Maintenance](#10-post-production--maintenance)
11. [UI/UX Rules](#11-uiux-rules)
12. [Feature Flags](#12-feature-flags)
13. [Coding Conventions](#13-coding-conventions)
14. [Testing & Definition of Done](#14-testing--definition-of-done)
15. [Open Decisions & Risks](#15-open-decisions--risks)

---

## 1. Identitas Produk

### 1.1 Ringkasan

ARUS adalah aplikasi mobile Android (Flutter) untuk manajemen bisnis multi-outlet: POS, inventory, analytics, AI assistant, dan blockchain tamper-evidence. Seluruh data melewati REST API pribadi (Express.js/TypeScript) ke PostgreSQL; SQLite dipakai sebagai backup read-only lokal.

### 1.2 Tujuan Utama

| # | Tujuan |
|---|--------|
| G1 | Memproses transaksi POS secara atomik, idempoten, dan tercatat blockchain |
| G2 | Menampilkan analytics KPI yang akurat dengan dukungan multi-currency & multi-timezone |
| G3 | Memberikan insight berbasis aturan + penjelasan AI yang grounded pada data nyata |
| G4 | Mendukung pengelolaan multi-outlet dengan pembatasan akses berbasis role |
| G5 | Memenuhi seluruh syarat wajib Tugas Akhir PAM (14 kriteria dosen) |

### 1.3 Role Pengguna

| Role | Singkatan | Deskripsi |
|------|-----------|-----------|
| `owner` | O | Akses penuh semua outlet & fitur |
| `manager` | M | Akses outlet yang ditugaskan; tidak bisa kelola users |
| `staff` | S | Kasir; hanya outlet sendiri & hari ini; tidak lihat cost/analytics lintas outlet |

### 1.4 Scope

**Dalam scope:** Login · POS · Inventory · Catalog · Analytics · Dashboard · Decision Support · AI Assistant · Reports · Outlets & LBS · Notifications · Currency/Timezone · Sensors · Biometric · Blockchain · Mini Game · Search · Settings · Profile · Feedback  
**Luar scope:** Offline POS write · FCM push · PDF export · Testnet anchoring · Self-service password reset · Microservices

---

## 2. Modul & Aktor

### 2.1 Daftar Modul

| Kode | Nama | Tier | Role |
|------|------|------|------|
| M01 | Auth & Session | Core | all |
| M02 | Catalog | Core | O,M (write) · all (read) |
| M03 | Inventory | Core | O,M (write) · all (read) |
| M04 | POS & Transactions | Core | all |
| M05 | Outlets & LBS | Core + Supporting | O (write) · all (read) |
| M06 | Analytics & Dashboard | Core | O,M (S: shift only) |
| M07 | Decision Support | Core | O,M |
| M08 | AI Assistant | Core (fallback) | O,M |
| M09 | Reports | Core | O,M |
| M10 | Notifications | Supporting | all |
| M11 | Localization (Currency & Timezone) | Supporting | all |
| M12 | Sensors | Supporting | all |
| M13 | Integrity (Blockchain) | Supporting | O,M |
| M14 | Mini Game | Supporting | all |
| M15 | Search | Supporting | scope-limited |
| M16 | Settings / Profile / About | Supporting | all |

### 2.2 Permission Matrix

| Endpoint group | Owner | Manager | Staff |
|----------------|-------|---------|-------|
| `/auth/*` | ✓ | ✓ | ✓ |
| `/users` (CRUD) | ✓ | — | — |
| `/outlets` (write) | ✓ | — | — |
| `/catalog` (write) | ✓ | ✓ | — |
| `/inventory` (adjustment) | ✓ | ✓ | — |
| `/transactions` (create) | ✓ | ✓ | ✓ (own outlet) |
| `/transactions` (void) | ✓ | ✓ | — |
| `/analytics/*` | ✓ | ✓ (assigned outlets) | — |
| `/insights` | ✓ | ✓ | — |
| `/ai/*` | ✓ | ✓ | — |
| `/reports` | ✓ | ✓ | — |
| `/integrity/*` | ✓ | ✓ | — |
| `/game/*` | ✓ | ✓ | ✓ |
| `/search` | ✓ | ✓ (scope) | ✓ (scope) |
| `/notifications` | ✓ | ✓ | ✓ (own) |
| `/settings` | ✓ | ✓ | ✓ |

> **Rule:** Manager dan Staff mendapat 404 (bukan 403) untuk resource di luar outlet yang ditugaskan.

---

## 3. Business Rules & Constraint

### BR-AUTH — Autentikasi

| ID | Rule |
|----|------|
| BR-AUTH-01 | Password di-hash dengan **argon2id**; tidak pernah disimpan plaintext |
| BR-AUTH-02 | 5 login gagal berturut-turut → akun terkunci sampai lockout expires (T-AUTH-03) |
| BR-AUTH-03 | JWT access token: TTL 900 s; refresh token: TTL 7 hari, rotating |
| BR-AUTH-04 | Reuse rotated refresh token → seluruh family dicabut |
| BR-AUTH-05 | Disabled user: akses ditolak pada request berikutnya (DB check per request) |
| BR-AUTH-06 | Biometric hanya membuka kunci sesi yang sudah ada (token tersimpan di `flutter_secure_storage`); tidak membuat token baru |
| BR-AUTH-07 | Biometric gagal 3x → fallback ke password login |

### BR-CAT — Katalog

| ID | Rule |
|----|------|
| BR-CAT-01 | SKU unik secara global; duplikat → 409 `CATALOG_SKU_DUPLICATE` |
| BR-CAT-02 | `price_idr` dan `cost_idr` disimpan sebagai integer IDR; tidak ada desimal di DB |
| BR-CAT-03 | Edit harga produk tidak mengubah `unit_price_idr` di `transaction_items` yang sudah ada |
| BR-CAT-04 | Staff tidak melihat `cost_idr` di response API |
| BR-CAT-05 | Produk non-aktif tidak bisa dimasukkan ke keranjang POS |

### BR-INV — Inventory

| ID | Rule |
|----|------|
| BR-INV-01 | Setiap perubahan stok **wajib** menulis row ke `inventory_movements` di dalam transaksi DB yang sama |
| BR-INV-02 | `quantity >= 0` di-enforce oleh DB constraint; tidak bisa minus |
| BR-INV-03 | Dua sale bersamaan pada item terakhir: hanya satu berhasil, satu mendapat 409 `INVENTORY_INSUFFICIENT` |
| BR-INV-04 | Status stok: `ok` (qty > reorder_level) · `low` (qty ≤ reorder_level, > 0) · `out` (qty = 0) |
| BR-INV-05 | Tidak ada hard-delete movements |

### BR-POS — Transaksi

| ID | Rule |
|----|------|
| BR-POS-01 | Harga dan total **selalu dihitung ulang di server**; nilai dari client diabaikan |
| BR-POS-02 | `POST /transactions` idempoten via `client_request_id` (UUID unik per keranjang) |
| BR-POS-03 | Transaksi bersifat atomik: jika salah satu item gagal, tidak ada perubahan yang tersimpan |
| BR-POS-04 | `paid_idr < total_idr` → 422 `TXN_PAYMENT_INSUFFICIENT` |
| BR-POS-05 | Void hanya dalam 24 jam; stok dikembalikan; chain void block ditambahkan |
| BR-POS-06 | Voided transactions **tidak dihitung** dalam semua KPI analytics |
| BR-POS-07 | Receipt number: `TXN-{outlet_code}-{YYYYMMDD}-{seq:04d}` |

### BR-ANA — Analytics

| ID | Rule |
|----|------|
| BR-ANA-01 | Semua KPI menggunakan `created_at` di timezone outlet; bukan UTC |
| BR-ANA-02 | Growth rate: jika periode sebelumnya = 0, return `null` dan UI tampilkan "baru" |
| BR-ANA-03 | Range analytics: `from` harus ≤ `to`; max 366 hari; else 400 `ANALYTICS_RANGE_INVALID` |
| BR-ANA-04 | Slow-moving: produk tanpa sale dalam periode tapi quantity > 0 |
| BR-ANA-05 | Outlet performance index = `(revenue_share * 0.4) + (growth * 0.3) + (transaction_count_share * 0.3)` |

### BR-DS — Decision Support

| ID | Rule |
|----|------|
| BR-DS-01 | Rules R1–R8 dijalankan via scheduler harian; satu insight per rule per outlet per hari (no duplicate) |
| BR-DS-02 | Minimum 14 hari riwayat transaksi untuk rules R3, R5, R7 |
| BR-DS-03 | Setiap insight wajib menyertakan `evidence` JSON yang bisa ditelusuri ke data nyata |

### BR-AI — AI Assistant

| ID | Rule |
|----|------|
| BR-AI-01 | AI **tidak boleh menyebut angka** yang tidak ada di `facts` yang dikirim ke LLM |
| BR-AI-02 | Semua jawaban AI dalam format: **Data / Dugaan / Saran** |
| BR-AI-03 | Pertanyaan di luar bisnis (lelucon, politik, dll.) ditolak tanpa memanggil LLM |
| BR-AI-04 | Pertanyaan tentang outlet di luar scope manager → facts tidak menyertakannya |
| BR-AI-05 | Cache: pertanyaan sama dalam 5 menit → serve dari cache |
| BR-AI-06 | LLM timeout 2x → fallback deterministic dari facts |
| BR-AI-07 | Rate limit: 10 req/menit, 100 req/hari per user |
| BR-AI-08 | Prompt injection (e.g. "abaikan aturan") → schema dan scope tidak berubah |

### BR-LBS — Location

| ID | Rule |
|----|------|
| BR-LBS-01 | Jarak dihitung dengan **Haversine formula** (bukan straight-line Euclidean) |
| BR-LBS-02 | Jika location permission ditolak: map dan list tetap tampil, distance ditampilkan "—" dengan banner |
| BR-LBS-03 | Nearest outlet: outlet aktif yang accessible oleh role caller |

### BR-INT — Integrity (Blockchain)

| ID | Rule |
|----|------|
| BR-INT-01 | Hash chain per outlet: setiap transaksi dihubungkan via `prev_hash` ke blok sebelumnya |
| BR-INT-02 | `data_hash = SHA-256(canonical_json(transaction))` — format canonical JSON deterministik (key sort, no whitespace) |
| BR-INT-03 | Void menambah void-block; `data_hash` blok asli tetap valid |
| BR-INT-04 | `block_index` per outlet contiguous (tidak ada gap); 20 concurrent sale → no duplicate index (advisory lock) |
| BR-INT-05 | Update langsung di DB (`UPDATE transactions SET total_idr`) → status TAMPERED |
| BR-INT-06 | Canonical JSON format TIDAK BOLEH diubah tanpa migration plan; perubahan invalidasi seluruh rantai yang ada |

### BR-NOT — Notifications

| ID | Rule |
|----|------|
| BR-NOT-01 | Low-stock trigger: hanya satu notifikasi per product per outlet per hari (dedup) |
| BR-NOT-02 | Recipients: Owner + Outlet Manager + Outlet Staff (hanya untuk low-stock) |
| BR-NOT-03 | User bisa nonaktifkan notifikasi per type di preferences |

### BR-SRCH — Search

| ID | Rule |
|----|------|
| BR-SRCH-01 | Min 2 karakter untuk trigger pencarian |
| BR-SRCH-02 | Hasil grouped: Products, Transactions, Outlets, Reports (max 5 per group) |
| BR-SRCH-03 | Hasil pencarian mengikuti outlet scope user |

---

## 4. Arsitektur Teknis

### 4.1 Diagram Arsitektur

```text
[ Flutter App (Android) ]
  ├── UI Layer: POS, Dashboard, LBS Map, AI Chat, Mini Game, Profile
  ├── Local DB: SQLite (sqflite) → 3 tabel backup read-only
  │
  ├──► (HTTPS REST JSON) ──► [ Express.js API (/api/*) ]
  │                           └── Prisma ORM ──► [ PostgreSQL (Supabase) ]
  │
  └──► (Public APIs)
        ├── Frankfurter API (FX Rates: IDR, USD, EUR)
        ├── OpenStreetMap / flutter_map (Peta & LBS)
        └── LLM Provider (Gemini/Anthropic via backend)
```

### 4.2 Tech Stack

| Layer | Teknologi |
|-------|-----------|
| Mobile | Flutter (stable) · Dart · Riverpod · go_router · dio · fl_chart · flutter_map · geolocator · local_auth · sensors_plus · flutter_secure_storage · shared_preferences · flutter_local_notifications · intl · timezone · json_serializable |
| Backend | Node.js 20 · Express · TypeScript (strict) · zod · Prisma · argon2 · jsonwebtoken · helmet · express-rate-limit · node-cron · pino |
| Database (Online) | PostgreSQL 15+ — Supabase sebagai plain Postgres (bukan Supabase SDK) |
| Database (Local) | SQLite via `sqflite` — 3 tabel backup read-only |
| AI | `LlmClient` interface; Gemini (default dev) atau Anthropic adapter |
| Testing | vitest · supertest · flutter_test · mocktail · integration_test |
| Hosting | Render/Railway + managed Postgres |
| Tooling | GitHub · GitHub Actions · OpenAPI |

### 4.3 Data Flow (Backend)

```
Route → Controller → Service → Data access (Prisma)
```

- **Controller**: parse, validate (zod), respond only — no business logic
- **Service**: business rules, DB transactions — no Express types
- **Analytics SQL**: di `modules/analytics/queries/*.sql.ts`, parameterized

### 4.4 Data Flow (Flutter)

```
UI Screen → Provider/Notifier → Repository → ApiClient → REST API
```

- Repository adalah satu-satunya yang boleh memanggil `ApiClient`
- Screen tidak boleh membuat HTTP call langsung

### 4.5 Keputusan Arsitektur yang TIDAK BOLEH diubah tanpa diskusi tertulis

| # | Keputusan |
|---|-----------|
| A1 | Flutter-only ke REST API; tidak ada Supabase client dari app |
| A2 | Tidak ada offline POS write; SQLite hanya read-only backup |
| A3 | Semua uang disimpan sebagai `integer IDR`; konversi hanya di formatter |
| A4 | Semua timestamp disimpan UTC (`timestamptz`); konversi hanya di display |
| A5 | 3 role fix di enum; tidak ada roles/permissions table |
| A6 | Analytics SQL di file `.sql.ts` terpisah; tidak ada raw SQL di AI module |
| A7 | AI hanya memanggil existing analytics/insight/inventory services; tidak ada LLM-generated queries |

---

## 5. Database — Skema & Aturan

### 5.1 Tabel PostgreSQL (14 tabel inti)

| # | Tabel | Fungsi |
|---|-------|--------|
| 1 | `users` | Akun pengguna |
| 2 | `user_outlets` | Assignment Manager/Staff ke outlet |
| 3 | `outlets` | Data cabang + koordinat LBS + timezone |
| 4 | `feedback` | Kesan & saran matkul PAM |
| 5 | `product_categories` | Kategori produk |
| 6 | `products` | Katalog; `price_idr` & `cost_idr` integer |
| 7 | `inventory` | Stok saat ini per outlet per produk |
| 8 | `inventory_movements` | Ledger keluar-masuk stok (append-only) |
| 9 | `transactions` | Header struk POS |
| 10 | `transaction_items` | Detail item struk (snapshot harga) |
| 11 | `blockchain_records` | Rantai hash SHA-256 per outlet |
| 12 | `notifications` | Inbox notifikasi user |
| 13 | `business_insights` | Hasil rules engine (R1–R8) |
| 14 | `ai_chat_logs` | Riwayat Q&A AI |
| 15+16 | `game_scenarios` & `game_sessions` | Mini game soal & skor |

> Schema Prisma lengkap ada di `api/prisma/schema.prisma`.

### 5.2 SQLite Lokal Flutter (3 tabel backup)

| Tabel | Isi |
|-------|-----|
| `local_session_settings` | Sesi user, pengaturan (currency, timezone, sensor, biometric) |
| `backup_products` | Backup katalog + stok (sync saat online) |
| `backup_transactions` | 50 struk terakhir + blockchain hash |

### 5.3 Aturan Database

| Rule | Detail |
|------|--------|
| DB-01 | Schema changes hanya via Prisma migrations; migration yang sudah applied TIDAK BOLEH diedit |
| DB-02 | Setiap FK wajib memiliki index; setiap query path baru perlu review index |
| DB-03 | Perubahan stok hanya dalam DB transaction dengan row lock + write `inventory_movements` |
| DB-04 | Tidak ada hard-delete: `transactions`, `inventory_movements`, `reports`, `blockchain_records` |
| DB-05 | Seed scripts harus idempotent |
| DB-06 | Kolom uang: `integer`; kolom timestamp: `timestamptz` |
| DB-07 | Constraint `quantity >= 0` di-enforce di DB level |

### 5.4 Indexes Wajib

```sql
-- transactions(outlet_id, created_at)  -- KPI queries
-- products(name) USING GIN trigram     -- search
-- products(sku)                        -- unique lookup
-- blockchain_records(outlet_id, block_index) UNIQUE
```

---

## 6. API — Kontrak & Konvensi

### 6.1 Response Envelope

**Success:**
```json
{ "data": <payload>, "meta": { "page": 1, "total": 42 } }
```

**Error:**
```json
{ "error": { "code": "INVENTORY_INSUFFICIENT", "message": "...", "details": {} } }
```

### 6.2 Status Codes

| Code | Semantik |
|------|----------|
| 200 | OK |
| 201 | Created |
| 400 | Validation error |
| 401 | Unauthenticated |
| 403 | Forbidden (wrong role) |
| 404 | Not found / out of scope |
| 409 | Conflict (duplicate, insufficient stock) |
| 422 | Business rule violation |
| 423 | Account locked |
| 429 | Rate limited |
| 503 | Service unavailable (integrity check failure) |

### 6.3 Global API Rules

| Rule | Detail |
|------|--------|
| API-01 | Setiap route: zod validation · auth middleware · role check · outlet scope |
| API-02 | Tidak pernah return `password_hash`, token hash, atau `cost_idr` ke Staff |
| API-03 | `POST /transactions` idempoten via `client_request_id` |
| API-04 | List endpoints paginate dengan `?page=&limit=` |
| API-05 | Rate limit: auth 5/15 min; AI 10/min & 100/day; general 100/15 min |
| API-06 | Contract = `openapi.yaml`; jika berubah, update keduanya bersama |
| API-07 | Response selalu menggunakan envelope di atas; tidak ada ad-hoc shapes |

### 6.4 Error Codes (Daftar)

| Code | HTTP | Module |
|------|------|--------|
| `AUTH_INVALID_CREDENTIALS` | 401 | M01 |
| `AUTH_ACCOUNT_LOCKED` | 423 | M01 |
| `AUTH_TOKEN_EXPIRED` | 401 | M01 |
| `AUTH_REFRESH_TOKEN_REUSE` | 401 | M01 |
| `CATALOG_SKU_DUPLICATE` | 409 | M02 |
| `INVENTORY_INSUFFICIENT` | 409 | M03 |
| `TXN_PAYMENT_INSUFFICIENT` | 422 | M04 |
| `TXN_PRODUCT_INACTIVE` | 409 | M04 |
| `ANALYTICS_RANGE_INVALID` | 400 | M06 |
| `AI_RATE_LIMIT` | 429 | M08 |
| `AI_SCOPE_VIOLATION` | 403 | M08 |
| `INTEGRITY_VERIFY_FAILED` | 503 | M13 |

---

## 7. Keamanan

### 7.1 Authentication & Authorization

- JWT di Authorization header (`Bearer <token>`)
- Refresh token hanya di body; tidak di URL
- Tokens disimpan di `flutter_secure_storage`; TIDAK di `shared_preferences`, logs, atau URL
- Rate limit per IP dan per user; lockout aktif di semua environment kecuali automated test

### 7.2 Data Security

- Password: argon2id dengan salt unik
- Semua query: parameterized (Prisma / raw SQL parameterized)
- Tidak ada secret di code atau di app bundle
- `.env` di-gitignore
- Tidak pernah log password, token, atau LLM prompt dengan data bisnis (log intent, token count, status saja)

### 7.3 Biometric

- Biometric hanya gate ke stored refresh token; tidak generate token baru
- Tersimpan di `flutter_secure_storage`
- Gagal 3x → fallback password

### 7.4 RBAC Enforcement

- Server menerapkan outlet scope di setiap query
- Manager mendapat 404 (bukan 403) untuk resource di luar outlet yang ditugaskan
- Staff tidak melihat `cost_idr`, tidak bisa void, tidak bisa akses analytics lintas outlet

---

## 8. Pre-Production Requirements

### 8.1 Environment Setup

**Backend (`api/.env`):**

| Variable | Contoh | Keterangan |
|----------|--------|------------|
| `NODE_ENV` | `development` | |
| `PORT` | `3000` | |
| `DATABASE_URL` | `postgresql://...` | Supabase connection string |
| `JWT_ACCESS_SECRET` | 32+ random bytes | |
| `JWT_ACCESS_TTL_SEC` | `900` | |
| `REFRESH_TTL_DAYS` | `7` | |
| `LLM_PROVIDER` | `gemini` / `anthropic` | |
| `LLM_API_KEY` | — | server-only |
| `LLM_MODEL` | provider-specific | |
| `AI_RATE_PER_MIN` | `10` | |
| `AI_RATE_PER_DAY` | `100` | |
| `FX_API_URL` | `https://api.frankfurter.dev/...` | |
| `FEATURE_INTEGRITY` | `true` | |
| `FEATURE_NOTIFICATIONS` | `true` | |
| `FEATURE_FX` | `true` | |
| `FEATURE_GAME` | `true` | |
| `FEATURE_AI` | `true` | |
| `LOG_LEVEL` | `info` | |

**Flutter:**
```bash
flutter run --dart-define=API_BASE_URL=https://... --dart-define=APP_ENV=dev
```
Tidak ada secret di Flutter app.

### 8.2 Database Migration & Seed

- Jalankan `npx prisma migrate deploy` pada DB kosong
- Seed script: `npx prisma db seed`
- Seed data minimal:
  - ≥ 3 users (owner, manager, staff)
  - ≥ 3 outlets (termasuk 1 London timezone untuk demo)
  - ≥ 40 produk dengan kategori
  - 90 hari generated transactions
  - Game scenarios
  - Exchange rates initial (IDR, USD, EUR)

### 8.3 Health Check

- `GET /health` harus return 200 sebelum Flutter app bisa digunakan
- App memanggil `/health` saat startup; jika gagal tampil maintenance screen

### 8.4 Pre-flight Checklist (sebelum mulai development)

- [ ] Decisions D1–D5, D8 sudah diclosing (lihat Section 15)
- [ ] CI pipeline: lint + unit tests berjalan di GitHub Actions
- [ ] DB provisioned dan migration berjalan bersih
- [ ] `.env.example` ada di repo; `.env` ada di `.gitignore`
- [ ] `openapi.yaml` sync dengan kode awal

---

## 9. Production Rules

### 9.1 Yang WAJIB dilakukan

- Setiap endpoint baru: tambahkan di `openapi.yaml` bersamaan
- Schema change: buat Prisma migration; update Section 5 di SRS
- Setiap PR: linked milestone + test IDs + CI green + 1 reviewer
- Setelah merge: tag versi di gate `v0.5-core` (Gate G1) dan `v1.0-demo`
- Jalankan full test suite sebelum dan sesudah setiap perubahan

### 9.2 Yang TIDAK BOLEH dilakukan (Hard Forbids)

| # | Larangan |
|---|----------|
| F1 | Memanggil database langsung dari Flutter (tidak via REST API) |
| F2 | Menyimpan business logic di UI widget |
| F3 | Menggunakan `any` / `dynamic` tanpa komentar penjelasan |
| F4 | Cross-feature imports antar Flutter features (hanya via `core/` dan `shared/`) |
| F5 | Mengubah canonical JSON format atau hash formula tanpa migration plan |
| F6 | Mengubah Prisma migration yang sudah di-apply |
| F7 | Menyimpan secret di code, app bundle, atau URL |
| F8 | Menyimpan token di `shared_preferences`, logs, atau URL |
| F9 | Menampilkan raw exception atau stack trace ke user |
| F10 | Memanggil device API (location, sensors, biometrics) dari dalam `build()` |
| F11 | Membuat floating-point arithmetic untuk uang |
| F12 | Menambah package baru tanpa justifikasi tertulis |
| F13 | Mengubah arsitektur secara diam-diam; harus dipropose tertulis dan update SRS |
| F14 | Raw SQL dari AI module; LLM-generated queries |
| F15 | Hard-delete transactions, movements, reports, atau blockchain records |

### 9.3 Do-Not-Break List

Ini adalah invariant sistem yang tidak boleh rusak dalam kondisi apapun:

1. `POST /transactions` atomicity (BR-POS-03) dan idempotency (BR-POS-02)
2. Server-side price recomputation (BR-POS-01)
3. Inventory movement ledger invariant (BR-INV-01)
4. Outlet scoping pada setiap query
5. AI validation pipeline (schema + number grounding + scope)
6. Canonical JSON format dan hash formula (BR-INT-06)
7. Error envelope dan error codes
8. Voided transactions excluded dari analytics (BR-POS-06)
9. Money sebagai integer IDR (A3)
10. Optional features tidak boleh di-require oleh core code paths

---

## 10. Post-Production / Maintenance

### 10.1 Scheduled Jobs (Cron)

| Job | Jadwal | Fungsi |
|-----|--------|--------|
| Insights generator | Daily 02:00 outlet-local | Jalankan rules R1–R8; tulis ke `business_insights` |
| FX rates updater | Daily 06:00 UTC | Ambil dari Frankfurter API; simpan ke `exchange_rates` |
| Notification cleanup | Daily 03:00 | Hapus notifikasi > 30 hari yang sudah dibaca |
| Insights cleanup | Weekly | Hapus insights > 90 hari yang sudah dismissed |

### 10.2 Blockchain Chain Maintenance

- Chain verify bisa dipanggil via `GET /integrity/chain/{outlet_id}`
- Jika ada gap atau hash mismatch → laporan TAMPERED dengan block index
- Tidak ada auto-repair; hanya reporting

### 10.3 Demo Data Reset

- Command: `npm run demo:reset` (jalankan seed ulang idempotent)
- Demo tamper: `npm run demo:tamper <transaction_id>` untuk simulasi tampering

### 10.4 Monitoring Checklist (setelah deploy)

- [ ] `/health` return 200
- [ ] Login flow berhasil (T-AUTH-01)
- [ ] POS create transaction berhasil (T-POS-01)
- [ ] Dashboard load < 3 detik
- [ ] AI assistant return response (atau fallback jika flag off)
- [ ] Blockchain verify untuk transaksi terbaru return VALID

---

## 11. UI/UX Rules

### 11.1 Navigasi

**Owner/Manager:** Beranda · Operasi · AI · Analitik · Lainnya (5 tab)  
**Staff:** Beranda · Kasir · Stok · Lainnya (4 tab)

### 11.2 State Management Rules (Riverpod)

- `AsyncNotifier` untuk remote data; `Notifier` untuk local UI state (cart, filters)
- `autoDispose` by default; keep-alive hanya untuk: session, settings, FX rates
- Tidak ada global mutable singleton; tidak ada `setState` untuk shared state
- Providers tidak import widgets; widgets tidak import repositories langsung
- Setelah transaksi/adjustment berhasil: `ref.invalidate(dashboardProvider)` dan `ref.invalidate(inventoryProvider)`

### 11.3 Screen Rules

- Setiap screen dengan remote data WAJIB menggunakan `AsyncStateView` (loading · empty · error states)
- Semua string dari `strings_id.dart` (bahasa Indonesia)
- Semua uang via `MoneyText` / `MoneyFormatter`
- Semua waktu via `TzConverter`
- Device APIs (location, sensors, biometrics, notifications) dibungkus dalam service di `core/` atau feature's `data/`

### 11.4 UX Constraints

- Touch targets ≥ 48 dp; text ≥ 14 sp; test pada 360×640
- Destructive actions (void, logout, dismiss insight) wajib konfirmasi
- Charts wajib memiliki summary text di atas chart
- Tema dari Material 3 tokens di `core/theme`; tidak ada per-screen colors
- Dispose subscriptions (sensors, timers) on lifecycle pause/dispose
- Tidak pernah tampilkan raw exception atau stack trace ke user

### 11.5 SQLite Local Sync

- Saat online: data produk dan struk terakhir di-sync ke SQLite
- Saat offline: halaman katalog dan riwayat struk tampil dari SQLite
- Tidak ada offline POS write

---

## 12. Feature Flags

Flags di-return oleh `GET /auth/me` → `features`. App membacanya sekali per session.

| Flag (env) | Controls | Jika OFF |
|------------|----------|----------|
| `FEATURE_INTEGRITY` | Hash chain insert + verify endpoints | Blok tidak ditulis; sale tetap jalan; UI verify tersembunyi |
| `FEATURE_NOTIFICATIONS` | Notification creation + endpoints | Triggers jadi no-op; bell tersembunyi |
| `FEATURE_FX` | FX job + `/fx/rates` | Display currency terkunci ke IDR |
| `FEATURE_GAME` | `/game/*` | Menu entry tersembunyi |
| `FEATURE_AI` | LLM calls | AI jawab via deterministic fallback |

**Client-only flags** (`core/config/feature_flags.dart`):

| Flag | Controls |
|------|----------|
| `lbs` | Map, geolocator, nearest outlet |
| `sensors` | Accelerometer shake, gyroscope tilt |
| `biometric` | Biometric unlock |

**T-CORE-01 harus pass dengan semua optional flags OFF.**

---

## 13. Coding Conventions

### 13.1 Naming

| Entitas | Convention | Contoh |
|---------|-----------|--------|
| Dart files/dirs | `snake_case` | `transaction_repository.dart` |
| Dart classes/enums | `PascalCase` | `TransactionRepository` |
| Riverpod providers | `<thing>Provider` | `cartProvider` |
| DTOs | `<Thing>Dto` | `TransactionDto` |
| TS files/dirs | `kebab-case` | `transaction.service.ts` |
| TS types/classes | `PascalCase` | `CreateTransactionDto` |
| TS vars/functions | `camelCase` | `createTransaction` |
| DB tables | `snake_case` plural | `transaction_items` |
| DB columns | `snake_case` | `unit_price_idr` |
| Money columns | suffix `_idr` | `total_idr` |
| JSON fields | `snake_case` | `client_request_id` |
| Routes | plural nouns, kebab | `/ai/conversations` |
| Env vars | `UPPER_SNAKE` | `JWT_ACCESS_SECRET` |
| Error codes | `UPPER_SNAKE` + prefix | `INVENTORY_INSUFFICIENT` |
| Git branches | `feat/m6-pos-create-transaction` | |

### 13.2 Code Quality

- TypeScript: `strict: true`; Dart: `flutter_lints` treated as errors di CI
- Functions ≤ ~40 baris; satu responsibility
- Tidak ada dead code, commented-out blocks, atau TODO tanpa issue reference
- Tidak ada `any`/`dynamic` tanpa komentar penjelasan

### 13.3 Folder Structure

```text
app/
  lib/
    core/
      config/       # env, feature flags
      network/      # api_client.dart, interceptors, app_exception.dart
      storage/      # secure_store.dart, prefs_store.dart
      l10n/         # strings_id.dart
      theme/
      routing/      # router.dart, guards
      utils/        # money_formatter, tz_converter, haversine, debouncer
    shared/
      widgets/      # async_state_view, money_text, kpi_card, empty_state
    features/
      auth/ catalog/ pos/ transactions/ inventory/
      analytics/ insights/ ai_assistant/ reports/
      outlets/ notifications/ settings/ integrity/ game/ search/ profile/
  test/

api/
  src/
    config/         # env.ts (zod-validated), logger.ts
    middleware/     # auth, rbac, scope, validate, rateLimit, error
    modules/
      auth/ users/ outlets/ catalog/ inventory/ transactions/
      analytics/ insights/ ai/ reports/ integrity/
      notifications/ fx/ game/ search/ settings/ feedback/
    jobs/           # node-cron registrations
    shared/         # errors.ts, pagination.ts, canonicalJson.ts, hash.ts
  prisma/           # schema.prisma, migrations/, seed/
  scripts/          # demo-tamper.ts, generate-demo-data.ts
  tests/            # unit/, integration/
  openapi.yaml
```

### 13.4 Git Workflow

- `main` protected; selalu deployable
- Branch: `feat|fix|chore/<milestone>-<slug>`
- Conventional Commits: `feat(pos): …`, `fix(inventory): …`
- PR: linked milestone + test IDs + CI green + 1 reviewer dari member lain
- Gate tags: `v0.5-core` (Gate G1), `v1.0-demo`

---

## 14. Testing & Definition of Done

### 14.1 Test Matrix

| Type | Tooling | Target |
|------|---------|--------|
| Unit (backend) | vitest | ≥ 70% service code |
| API integration | supertest + test DB | ≥ 1 happy + 1 failure per endpoint |
| Unit (Flutter) | flutter_test + mocktail | Key utils 100% |
| Widget | flutter_test | AsyncStateView, cart, KPI card, role nav |
| Integration (Flutter) | integration_test | Login → POS → Dashboard path |
| AI | vitest + fake LlmClient | T-AI-01 sampai T-AI-09 |
| Security | Table-driven authz matrix | Setiap endpoint × role |
| Manual UAT | Demo script | T-DEMO-01 |

### 14.2 Key Test IDs

**Authentication:** T-AUTH-01..08 · T-RBAC-01..06  
**Catalog/Inventory/POS:** T-CAT-01..03 · T-INV-01..05 · T-POS-01..07  
**Analytics/DS:** T-ANA-01..07 · T-DS-01..03  
**AI:** T-AI-01..09  
**Reports/LBS/Notifications:** T-REP-01..03 · T-LBS-01..04 · T-NOT-01..05  
**Sensors/Integrity/Currency/TZ/Game/Search:** T-SEN-01..05 · T-INT-01..06 · T-CUR-01..02 · T-TZ-01..02 · T-GAME-01..03 · T-SRCH-01..03  
**Platform:** T-API-01..02 · T-DB-01..02 · T-UI-01..03 · T-CORE-01 · T-DEMO-01

### 14.3 Definition of Done (per task)

- [ ] Sesuai kontrak SRS (endpoint, permission, validation, error codes)
- [ ] Unit/integration/widget tests ditulis dan passing, termasuk milestone T-* IDs
- [ ] Lint/format bersih; tidak ada warning baru
- [ ] Loading, empty, error states diimplementasikan (UI tasks)
- [ ] Role/outlet authorization diverifikasi untuk setiap role
- [ ] Tidak ada regresi di core demo path (steps 1–8 demo script)
- [ ] `openapi.yaml`, schema DB, dan migrations di-update jika ada perubahan
- [ ] Tidak ada secret atau debug output yang di-commit
- [ ] PR di-review dan merge ke `main`

### 14.4 Definition of Done (project/final)

1. T-DEMO-01 pass pada release APK di physical Android device, terhadap cloud deployment
2. Semua T-* tests green; tidak ada open P1/P2 bugs
3. T-CORE-01 pass dengan semua optional flags off
4. Setiap requirement traceability row terverifikasi
5. SRS, `openapi.yaml`, dan migrations sinkron dengan code
6. Demo data bisa di-reset dengan satu command; tidak ada secret di repo

### 14.5 Demo Script (Acceptance)

1. Warm server; login sebagai Owner; tampilkan KPI dashboard dari seeded history
2. Ganti display currency ke USD dan timezone ke London; amati nilai/timestamp berubah
3. Login sebagai Staff di device kedua; proses sale; stok berkurang; notifikasi low-stock muncul untuk Manager/Owner
4. Sebagai Owner: dashboard update (shake to refresh); buka Insights; lihat evidence restock insight
5. Tanya AI "Produk apa yang perlu direstock?" dan "Kenapa penjualan turun?"; tunjukkan Data/Dugaan/Saran; angka sesuai dashboard
6. Tampilkan Analytics tabs; flick gyroscope ganti granularity; buka Outlet Map, nearest outlet, performance colors
7. Generate laporan Sales Summary; verifikasi (VALID)
8. Jalankan `demo:tamper` pada receipt; verifikasi transaksi (TAMPERED)
9. Mainkan satu Mini Game challenge
10. Tes biometric: kunci app, buka via fingerprint

---

## 15. Open Decisions & Risks

### 15.1 Open Decisions

| ID | Keputusan | Recommended Default | Deadline |
|----|-----------|--------------------|-|
| D1 | Dart models: hand-written vs `freezed` | `json_serializable` only | Milestone 1 |
| D2 | OpenAPI: generated vs hand-maintained | Hand-maintained + contract tests | Milestone 1 |
| D3 | Postgres host | Supabase sebagai plain Postgres | Milestone 1 |
| D4 | Backend host | Render atau Railway | Milestone 1 |
| D5 | LLM provider | Gemini free tier (dev) + Anthropic adapter tersedia | Milestone 9 |
| D6 | Testnet anchoring chain head | Excluded dari MVP | Post-MVP |
| D7 | Self-service password reset | Excluded; Owner yang reset | Post-MVP |
| D8 | Sync vs outbox hashing | Synchronous behind flag | Milestone 6 |

### 15.2 Risks

| Risk | Mitigasi |
|------|----------|
| Scope (39 screens, 65 endpoints) untuk tim 3 orang | Tiering, Gate G1, cut list, shared components, seeded data |
| Cold start free-tier hosting saat demo | `SERVER_WARMING_UP` handling; pre-warm sebelum presentasi |
| LLM quota / latency | Deterministic fallback; caching; provider adapter |
| Hash-chain contention (concurrent sales) | Per-outlet chains + advisory locks (T-INT-06) |
| Analytics correctness across timezones | Fixture tests T-ANA-04, T-TZ-* |
| Variabilitas device (sensors, biometrics) | Wrapped services, manual alternatives, Sensor Test screen |

### 15.3 Cut List (jika waktu kurang)

Potong dalam urutan ini:
1. M14 Mini Game
2. UI polish M13 (keep hashing, cut chain screen)
3. M11 EUR (keep USD)
4. M12 Gyroscope
5. M10 Periodic summary notifications
6. M05 Performance coloring di map

**Core (M01–M09) tidak pernah dipotong.**

---

*End of ARUS SRS v2.0*
