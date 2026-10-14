# ARUS — Module Plan

**Versi:** 1.0  
**Repo:** `https://github.com/supremeinori/arus` · branch `main`  
**Update dokumen ini** setiap kali menambah file/endpoint baru ke modul terkait.

---

## Daftar Modul

| Kode | Nama | Tier | Status |
|------|------|------|--------|
| [M01](#m01-auth--session) | Auth & Session | Core | ✅ Implemented |
| [M02](#m02-catalog) | Catalog | Core | ✅ Implemented |
| [M03](#m03-inventory) | Inventory | Core | ✅ Implemented |
| [M04](#m04-pos--transactions) | POS & Transactions | Core | ✅ Implemented |
| [M05](#m05-outlets--lbs) | Outlets & LBS | Core + Supporting | ✅ Implemented |
| [M06](#m06-analytics--dashboard) | Analytics & Dashboard | Core | ✅ Implemented |
| [M07](#m07-decision-support) | Decision Support | Core | ✅ Implemented |
| [M08](#m08-ai-assistant) | AI Assistant | Core (fallback) | ✅ Implemented |
| [M09](#m09-reports) | Reports | Core | ✅ Implemented |
| [M10](#m10-notifications) | Notifications | Supporting | ✅ Implemented |
| [M11](#m11-localization) | Currency & Timezone | Supporting | ✅ Implemented |
| [M12](#m12-sensors) | Sensors | Supporting | ✅ Implemented |
| [M13](#m13-integrity--blockchain) | Integrity (Blockchain) | Supporting | ✅ Implemented |
| [M14](#m14-mini-game) | Mini Game | Supporting | ✅ Implemented |
| [M15](#m15-search) | Search | Supporting | ✅ Implemented |
| [M16](#m16-settings--profile--shell) | Settings / Profile / Shell | Supporting | ✅ Implemented |

---

## M01 — Auth & Session

**Purpose:** Login, JWT session, RBAC, biometric unlock, user management  
**Actors:** All roles  
**Flag:** `biometric` (client-only, optional)

### Flutter Files

| File | Link |
|------|------|
| Feature root | [lib/features/auth/](https://github.com/supremeinori/arus/tree/main/app/lib/features/auth) |
| Splash screen | [splash/](https://github.com/supremeinori/arus/tree/main/app/lib/features/splash) |
| Profile screen | [profile/](https://github.com/supremeinori/arus/tree/main/app/lib/features/profile) |
| Users admin | [users/](https://github.com/supremeinori/arus/tree/main/app/lib/features/users) |
| Biometric service | [lib/core/auth/biometric_service.dart](https://github.com/supremeinori/arus/blob/main/app/lib/core/auth/biometric_service.dart) |
| Secure store | [lib/core/storage/secure_store.dart](https://github.com/supremeinori/arus/blob/main/app/lib/core/storage/secure_store.dart) |
| App router | [lib/core/routing/app_router.dart](https://github.com/supremeinori/arus/blob/main/app/lib/core/routing/app_router.dart) |

### Backend Files

| File | Link |
|------|------|
| Module root | [api/src/modules/auth/](https://github.com/supremeinori/arus/tree/main/api/src/modules/auth) |
| Users module | [api/src/modules/users/](https://github.com/supremeinori/arus/tree/main/api/src/modules/users) |
| Auth middleware | [api/src/middleware/auth.ts](https://github.com/supremeinori/arus/blob/main/api/src/middleware/auth.ts) |

### Endpoints

| Method | Path | Role | Description |
|--------|------|------|-------------|
| POST | `/auth/login` | all | Login, return JWT pair |
| POST | `/auth/refresh` | all | Rotate refresh token |
| POST | `/auth/logout` | all | Revoke refresh token |
| GET | `/auth/me` | all | Current user + features |
| PUT | `/auth/change-password` | all | Change own password |
| GET | `/users` | O | List all users |
| POST | `/users` | O | Create user |
| PUT | `/users/:id` | O | Update user |
| DELETE | `/users/:id` | O | Disable user |

### Database Tables

`users` · `user_outlets` · `refresh_tokens` · `user_settings` (biometric_enabled)

### Business Rules

BR-AUTH-01 sampai BR-AUTH-07 (lihat SRS v2 Section 3)

### SQLite Local

`local_session_settings` — menyimpan user info, biometric_enabled, currency, timezone, sensor preferences

---

## M02 — Catalog

**Purpose:** Manajemen produk dan kategori  
**Actors:** O, M (write) · all (read)  
**Flag:** —

### Flutter Files

| File | Link |
|------|------|
| Feature root | [lib/features/catalog/](https://github.com/supremeinori/arus/tree/main/app/lib/features/catalog) |

### Backend Files

| File | Link |
|------|------|
| Module root | [api/src/modules/catalog/](https://github.com/supremeinori/arus/tree/main/api/src/modules/catalog) |

### Endpoints

| Method | Path | Role | Description |
|--------|------|------|-------------|
| GET | `/catalog/categories` | all | List categories |
| POST | `/catalog/categories` | O,M | Create category |
| PUT | `/catalog/categories/:id` | O,M | Update category |
| GET | `/catalog/products` | all | List products (Staff: no cost) |
| POST | `/catalog/products` | O,M | Create product |
| PUT | `/catalog/products/:id` | O,M | Update product |
| DELETE | `/catalog/products/:id` | O,M | Deactivate product |

### Database Tables

`product_categories` · `products`

### Business Rules

- BR-CAT-01: SKU unik global → 409 `CATALOG_SKU_DUPLICATE`
- BR-CAT-02: `price_idr` dan `cost_idr` integer
- BR-CAT-03: Edit harga tidak mengubah transaction_items historis
- BR-CAT-04: Staff tidak melihat `cost_idr`
- BR-CAT-05: Produk non-aktif tidak bisa di-POS

### SQLite Local

`backup_products` — cache offline (sync otomatis saat online)

---

## M03 — Inventory

**Purpose:** Tracking stok per outlet, adjustment, movement ledger, low-stock detection  
**Actors:** O, M (write) · all (read)  
**Flag:** —

### Flutter Files

| File | Link |
|------|------|
| Feature root | [lib/features/inventory/](https://github.com/supremeinori/arus/tree/main/app/lib/features/inventory) |

### Backend Files

| File | Link |
|------|------|
| Module root | [api/src/modules/inventory/](https://github.com/supremeinori/arus/tree/main/api/src/modules/inventory) |

### Endpoints

| Method | Path | Role | Description |
|--------|------|------|-------------|
| GET | `/inventory` | all | List inventory (outlet-scoped) |
| GET | `/inventory/:productId` | all | Item detail + movements |
| POST | `/inventory/adjustments` | O,M | Manual adjustment (restock/waste/correction) |
| GET | `/inventory/movements` | O,M | Movement log |
| GET | `/inventory/low-stock` | O,M | Items below reorder_level |

### Database Tables

`inventory` · `inventory_movements`

### Business Rules

- BR-INV-01: Setiap stok change wajib tulis `inventory_movements` atomik
- BR-INV-02: `quantity >= 0` DB constraint
- BR-INV-03: Concurrent sale → hanya satu berhasil
- BR-INV-04: Status: `ok` / `low` / `out`
- BR-INV-05: Tidak ada hard-delete movements

### Movement Types

`sale` · `void_return` · `restock` · `correction` · `waste`

---

## M04 — POS & Transactions

**Purpose:** Kasir — buat transaksi, receipt, void, history  
**Actors:** All (create) · O,M (void)  
**Flag:** `FEATURE_INTEGRITY` (blockchain; opsional)

### Flutter Files

| File | Link |
|------|------|
| POS feature | [lib/features/pos/](https://github.com/supremeinori/arus/tree/main/app/lib/features/pos) |
| Operations | [lib/features/operations/](https://github.com/supremeinori/arus/tree/main/app/lib/features/operations) |

### Backend Files

| File | Link |
|------|------|
| Transactions module | [api/src/modules/transactions/](https://github.com/supremeinori/arus/tree/main/api/src/modules/transactions) |
| transactions.service.ts | [api/src/modules/transactions/transactions.service.ts](https://github.com/supremeinori/arus/blob/main/api/src/modules/transactions/transactions.service.ts) |

### Endpoints

| Method | Path | Role | Description |
|--------|------|------|-------------|
| POST | `/transactions` | all | Create transaction (idempoten via `client_request_id`) |
| GET | `/transactions` | all (scoped) | List (Staff: own + today only) |
| GET | `/transactions/:id` | all (scoped) | Detail + receipt |
| POST | `/transactions/:id/void` | O,M | Void (within 24h) |

### Flow Transaksi

```
Flutter cart → POST /transactions {client_request_id, items[], payment}
  → Server: validate → lock inventory → recompute prices → deduct stock
  → write transaction + items + movements (atomic)
  → if FEATURE_INTEGRITY: append blockchain block
  → if low stock: create notification
  → return receipt
```

### Database Tables

`transactions` · `transaction_items` · `inventory_movements` (auto) · `blockchain_records` (jika flag on)

### Business Rules

BR-POS-01 sampai BR-POS-07 (lihat SRS v2)

### SQLite Local

`backup_transactions` — 50 struk terakhir + hash (view-only offline)

---

## M05 — Outlets & LBS

**Purpose:** Data cabang, peta OpenStreetMap, jarak GPS Haversine, performance colors  
**Actors:** O (write) · all (read) · LBS client-side optional  
**Flag:** `lbs` (client-only)

### Flutter Files

| File | Link |
|------|------|
| Outlets feature | [lib/features/outlets/](https://github.com/supremeinori/arus/tree/main/app/lib/features/outlets) |

### Backend Files

| File | Link |
|------|------|
| Outlets module | [api/src/modules/outlets/](https://github.com/supremeinori/arus/tree/main/api/src/modules/outlets) |
| outlets.service.ts | [api/src/modules/outlets/outlets.service.ts](https://github.com/supremeinori/arus/blob/main/api/src/modules/outlets/outlets.service.ts) |

### Endpoints

| Method | Path | Role | Description |
|--------|------|------|-------------|
| GET | `/outlets` | all (scoped) | List outlets |
| POST | `/outlets` | O | Create outlet |
| PUT | `/outlets/:id` | O | Update outlet |
| GET | `/outlets/nearest` | all | Nearest outlet (Haversine) |
| GET | `/outlets/performance` | O,M | Revenue + performance index per outlet |

### Key Functions

- `calculateHaversineDistanceKm(lat1, lon1, lat2, lon2)` — di `outlets.service.ts`
- Outlet performance index: `(revenue_share × 0.4) + (growth × 0.3) + (txn_count_share × 0.3)`

### Database Tables

`outlets` (`latitude`, `longitude`, `timezone`) · `user_outlets`

### Business Rules

- BR-LBS-01: Haversine formula (bukan Euclidean)
- BR-LBS-02: Permission denied → map tetap tampil, distance "—" + banner
- BR-LBS-03: Nearest dari outlet aktif yang accessible

### External

- `flutter_map` + OpenStreetMap tiles (tile-server publik)
- `geolocator` untuk GPS user

---

## M06 — Analytics & Dashboard

**Purpose:** KPI revenue, ATV, growth, slow-moving, peak hours, outlet comparison  
**Actors:** O, M · Staff hanya lihat shift sendiri  
**Flag:** —

### Flutter Files

| File | Link |
|------|------|
| Dashboard | [lib/features/dashboard/](https://github.com/supremeinori/arus/tree/main/app/lib/features/dashboard) |
| Analytics | [lib/features/analytics/](https://github.com/supremeinori/arus/tree/main/app/lib/features/analytics) |

### Backend Files

| File | Link |
|------|------|
| Analytics module | [api/src/modules/analytics/](https://github.com/supremeinori/arus/tree/main/api/src/modules/analytics) |

### Endpoints

| Method | Path | Role | Description |
|--------|------|------|-------------|
| GET | `/analytics/overview` | O,M | KPI: revenue, txn count, ATV, growth |
| GET | `/analytics/sales` | O,M | Sales by period (daily/weekly/monthly) |
| GET | `/analytics/products` | O,M | Top/slow products |
| GET | `/analytics/inventory` | O,M | Stock status distribution |
| GET | `/analytics/outlets` | O | Outlet comparison |
| GET | `/analytics/peak-hours` | O,M | Busiest hours heatmap |
| GET | `/analytics/compare` | O,M | Period-over-period comparison |
| GET | `/analytics/profit` | O | Profit margin (requires cost_idr) |

### KPIs

| KPI | Rumus |
|-----|-------|
| Revenue | `SUM(total_idr)` — exclude voided |
| ATV | `revenue / transaction_count` |
| Growth | `(current - prev) / prev × 100` — null jika prev=0 |
| Slow-moving | Product: qty>0, zero sales dalam periode |
| Days of cover | `quantity / avg_daily_sales` |

### Database Tables

`transactions` · `transaction_items` · `inventory` · `products`

### Business Rules

- BR-ANA-01: KPI menggunakan `created_at` di timezone outlet
- BR-ANA-02: Growth null jika prev=0
- BR-ANA-03: Max range 366 hari
- BR-ANA-04: Timezone-aware date bucketing
- BR-ANA-06: Outlet index formula (Section 5)

---

## M07 — Decision Support

**Purpose:** Automated insights berbasis aturan (R1–R8), evidence-backed  
**Actors:** O, M  
**Flag:** —

### Flutter Files

| File | Link |
|------|------|
| Insights feature | [lib/features/insights/](https://github.com/supremeinori/arus/tree/main/app/lib/features/insights) |

### Backend Files

| File | Link |
|------|------|
| Insights module | [api/src/modules/insights/](https://github.com/supremeinori/arus/tree/main/api/src/modules/insights) |

### Endpoints

| Method | Path | Role | Description |
|--------|------|------|-------------|
| GET | `/insights` | O,M | List active insights (scoped) |
| GET | `/insights/:id` | O,M | Insight detail + evidence |
| POST | `/insights/:id/dismiss` | O,M | Dismiss insight |

### Rules Engine (R1–R8)

| Rule | Trigger |
|------|---------|
| R1 | Stok item di bawah `reorder_level` |
| R2 | Produk slow-moving (>14 hari tanpa penjualan) |
| R3 | Revenue turun >20% dari periode sebelumnya (min 14 hari) |
| R4 | Peak hour teridentifikasi berubah |
| R5 | Outlet underperform dibanding rata-rata (min 14 hari) |
| R6 | Margin produk rendah (<15%) |
| R7 | Pola musiman terdeteksi |
| R8 | Inventory turnover terlalu lambat |

### Database Tables

`business_insights` (`rule_code`, `severity`, `evidence` JSON, `insight_date`)

### Business Rules

- BR-DS-01: Satu insight per rule per outlet per hari (dedup)
- BR-DS-02: Min 14 hari riwayat untuk R3/R5/R7
- BR-DS-03: Setiap insight wajib ada `evidence` traceable

---

## M08 — AI Assistant

**Purpose:** LLM business Q&A dalam bahasa Indonesia, grounded pada data nyata  
**Actors:** O, M  
**Flag:** `FEATURE_AI` (fallback deterministic jika off)

### Flutter Files

| File | Link |
|------|------|
| AI Assistant feature | [lib/features/ai_assistant/](https://github.com/supremeinori/arus/tree/main/app/lib/features/ai_assistant) |

### Backend Files

| File | Link |
|------|------|
| AI module | [api/src/modules/ai/](https://github.com/supremeinori/arus/tree/main/api/src/modules/ai) |

### Endpoints

| Method | Path | Role | Description |
|--------|------|------|-------------|
| POST | `/ai/ask` | O,M | Send question; return structured answer |
| GET | `/ai/conversations` | O,M | List conversation history |
| GET | `/ai/conversations/:id` | O,M | Conversation detail |
| DELETE | `/ai/conversations/:id` | O,M | Delete conversation |
| GET | `/ai/intents` | O,M | List supported intents |

### AI Pipeline

```
User question
  → Intent classifier (deterministic regex/rule)
  → Fact builder (calls analytics/insights/inventory services)
  → Prompt constructor (facts + question)
  → LlmClient.generate()
  → Validator (schema check + number grounding + scope check)
  → Retry jika gagal (max 2x)
  → Fallback deterministic jika LLM timeout/fail
  → Return: { data, dugaan, saran }
```

### Supported Intents (8)

`restock_check` · `revenue_analysis` · `product_recommendation` · `sales_decline` · `inventory_status` · `outlet_performance` · `peak_hours` · `general_business`

### Response Format

```json
{
  "data": "Penjualan bulan ini Rp 45.200.000 (-12% dari bulan lalu)",
  "dugaan": "Penurunan terjadi karena stok produk A habis 3 hari",
  "saran": "Restock produk A minimal 50 unit untuk menghindari lost sales"
}
```

### Database Tables

`ai_chat_logs` (dalam SRS: `ai_conversations` + `ai_messages`)

### Business Rules

BR-AI-01 sampai BR-AI-08 (lihat SRS v2)

---

## M09 — Reports

**Purpose:** Generate dan simpan laporan penjualan, inventory, profit  
**Actors:** O, M  
**Flag:** —

### Flutter Files

| File | Link |
|------|------|
| Reports feature | [lib/features/reports/](https://github.com/supremeinori/arus/tree/main/app/lib/features/reports) |

### Backend Files

| File | Link |
|------|------|
| Reports module | [api/src/modules/reports/](https://github.com/supremeinori/arus/tree/main/api/src/modules/reports) |

### Endpoints

| Method | Path | Role | Description |
|--------|------|------|-------------|
| GET | `/reports` | O,M | List generated reports |
| POST | `/reports` | O,M | Generate new report |
| GET | `/reports/:id` | O,M | Report detail (frozen payload) |
| DELETE | `/reports/:id` | O | Delete report |

### Report Types

| Type | Isi |
|------|-----|
| `sales_summary` | Revenue, txn count, ATV, top 10 products per periode |
| `inventory_snapshot` | Stok saat ini, movement summary, low-stock items |
| `profit_analysis` | Revenue vs cost per product (Owner only) |

### Business Rules

- Report payload di-freeze saat generate; sales baru tidak mengubah report yang sudah ada
- Regenerate → baris baru; baris lama tetap ada
- Empty period → `has_data: false`, tetap labeled

### Database Tables

`reports`

---

## M10 — Notifications

**Purpose:** Low-stock alerts, system messages, inbox  
**Actors:** All  
**Flag:** `FEATURE_NOTIFICATIONS`

### Flutter Files

| File | Link |
|------|------|
| Notifications feature | [lib/features/notifications/](https://github.com/supremeinori/arus/tree/main/app/lib/features/notifications) |

### Backend Files

| File | Link |
|------|------|
| Notifications module | [api/src/modules/notifications/](https://github.com/supremeinori/arus/tree/main/api/src/modules/notifications) |

### Endpoints

| Method | Path | Role | Description |
|--------|------|------|-------------|
| GET | `/notifications` | all | List notifications (own) |
| POST | `/notifications/:id/read` | all | Mark as read |
| POST | `/notifications/read-all` | all | Mark all as read |
| GET | `/notifications/count` | all | Unread count (badge) |
| PUT | `/settings/notifications` | all | Update preferences |

### Notification Types

| Type | Trigger | Recipients |
|------|---------|-----------|
| `low_stock` | Sale membuat qty ≤ reorder_level | Owner + outlet managers + outlet staff |
| `sales_decline` | Rule R3 fired | Owner + outlet managers |
| `weekly_summary` | Cron weekly | Owner + managers |
| `system` | Admin event | All |

### Business Rules

- BR-NOT-01: Dedup low-stock → satu per product per outlet per hari
- BR-NOT-02: Recipients sesuai type
- BR-NOT-03: User bisa nonaktifkan per type
- MVP: polling + local notifications; FCM adalah stretch goal

### Database Tables

`notifications` · `user_settings` (notification preferences)

---

## M11 — Localization

**Purpose:** Currency conversion (IDR/USD/EUR) dan timezone (WIB/WITA/WIT/London)  
**Actors:** All  
**Flag:** `FEATURE_FX` (currency; timezone selalu aktif)

### Flutter Files

| File | Link |
|------|------|
| Settings feature | [lib/features/settings/](https://github.com/supremeinori/arus/tree/main/app/lib/features/settings) |
| Money formatter | [lib/core/utils/money_formatter.dart](https://github.com/supremeinori/arus/blob/main/app/lib/core/utils/money_formatter.dart) |
| Timezone converter | [lib/core/utils/timezone_converter.dart](https://github.com/supremeinori/arus/blob/main/app/lib/core/utils/timezone_converter.dart) |

### Backend Files

| File | Link |
|------|------|
| FX module | [api/src/modules/fx/](https://github.com/supremeinori/arus/tree/main/api/src/modules/fx) |
| Settings module | [api/src/modules/settings/](https://github.com/supremeinori/arus/tree/main/api/src/modules/settings) |

### Endpoints

| Method | Path | Role | Description |
|--------|------|------|-------------|
| GET | `/fx/rates` | all | Latest rates (IDR base) |
| GET | `/settings` | all | User settings |
| PUT | `/settings` | all | Update settings |

### Currency Rules

- Semua data disimpan integer IDR di DB
- Konversi hanya terjadi di display layer (`MoneyFormatter`)
- Rate dari Frankfurter API; di-cache harian
- Jika source down: gunakan rate terakhir yang tersimpan + tampilkan "as of {date}"

### Timezone Rules

- Semua timestamp disimpan UTC di DB
- Konversi hanya di display (`TzConverter`)
- Outlet memiliki `timezone` field (IANA tz string)
- Analytics date-bucketing menggunakan timezone outlet (bukan user's display timezone)

### Supported Timezones

`Asia/Jakarta` (WIB) · `Asia/Makassar` (WITA) · `Asia/Jayapura` (WIT) · `Europe/London`

### Database Tables

`exchange_rates` · `user_settings` (`display_currency`, `display_timezone`)

---

## M12 — Sensors

**Purpose:** Accelerometer shake-to-refresh, Gyroscope flick-to-change-granularity  
**Actors:** All  
**Flag:** `sensors` (client-only)

### Flutter Files

| File | Link |
|------|------|
| Sensors feature | [lib/features/sensors/](https://github.com/supremeinori/arus/tree/main/app/lib/features/sensors) |
| Settings (sensor toggle) | [lib/features/settings/](https://github.com/supremeinori/arus/tree/main/app/lib/features/settings) |

### Package

`sensors_plus` (Flutter plugin)

### Sensor Behaviors

| Sensor | Gesture | Action | Threshold |
|--------|---------|--------|-----------|
| Accelerometer | Shake (2 spikes >18 m/s² in 700 ms) | Refresh dashboard data | Cooldown 2 detik |
| Gyroscope | Wrist flick (\|ωy\| > 4 rad/s) | Advance chart granularity (daily→weekly→monthly→daily) | Sign menentukan arah |

### Business Rules

- T-SEN-01: Synthetic stream 2 spikes → shake event emitted
- T-SEN-02: 3rd spike dalam 2s → ignored (cooldown)
- T-SEN-03: Gyro |ωy| 4 rad/s → granularity advances once
- T-SEN-04: Stream error → toggle disabled, manual controls tetap berfungsi
- Dispose sensor subscriptions on lifecycle pause/dispose

### Database Tables

`user_settings` (`shake_refresh_enabled`, `tilt_enabled`)

---

## M13 — Integrity (Blockchain)

**Purpose:** Tamper-evident hash chain per outlet menggunakan SHA-256  
**Actors:** O, M (view) · System (write saat transaksi)  
**Flag:** `FEATURE_INTEGRITY`

### Flutter Files

| File | Link |
|------|------|
| Integrity feature | [lib/features/integrity/](https://github.com/supremeinori/arus/tree/main/app/lib/features/integrity) |

### Backend Files

| File | Link |
|------|------|
| Integrity module | [api/src/modules/integrity/](https://github.com/supremeinori/arus/tree/main/api/src/modules/integrity) |
| integrity.service.ts | [api/src/modules/integrity/integrity.service.ts](https://github.com/supremeinori/arus/blob/main/api/src/modules/integrity/integrity.service.ts) |

### Endpoints

| Method | Path | Role | Description |
|--------|------|------|-------------|
| GET | `/integrity/verify/:transactionId` | O,M | Verify single transaction |
| GET | `/integrity/chain/:outletId` | O,M | Verify full chain |
| POST | `/integrity/verify-batch` | O,M | Batch verify |

### Hash Formula

```
canonical_json = JSON.stringify(txn_data, sorted_keys, no_whitespace)
data_hash      = SHA-256(canonical_json)
block_hash     = SHA-256(outlet_id + block_index + data_hash + prev_hash)
```

### Statuses

| Status | Artinya |
|--------|---------|
| `VALID` | data_hash cocok + prev_hash link intact |
| `TAMPERED` | data_hash tidak cocok (data diubah) |
| `BROKEN_CHAIN` | prev_hash link putus (blok dihapus/diubah) |

### Database Tables

`blockchain_records` (`outlet_id`, `block_index`, `transaction_id`, `data_hash`, `prev_hash`, `block_hash`)

### Business Rules

BR-INT-01 sampai BR-INT-06 (lihat SRS v2)

---

## M14 — Mini Game

**Purpose:** Business Decision Challenge — simulasi keputusan bisnis (kuis studi kasus)  
**Actors:** All  
**Flag:** `FEATURE_GAME`

### Flutter Files

| File | Link |
|------|------|
| Game feature | [lib/features/game/](https://github.com/supremeinori/arus/tree/main/app/lib/features/game) |

### Backend Files

| File | Link |
|------|------|
| Game module | [api/src/modules/game/](https://github.com/supremeinori/arus/tree/main/api/src/modules/game) |

### Endpoints

| Method | Path | Role | Description |
|--------|------|------|-------------|
| GET | `/game/scenarios` | all | List available scenarios |
| GET | `/game/scenarios/next` | all | Next unplayed scenario |
| POST | `/game/sessions` | all | Submit choice + get score |
| GET | `/game/sessions` | all | Own session history |
| GET | `/game/leaderboard` | all | Top scores |

### Game Mechanics

- Setiap scenario: `title`, `situation_json`, `choices_json` (4 pilihan)
- Submit → server return: `score` (0–100), `breakdown`, `explanation`, `best_choice`
- Response payload scenario tidak include scoring/outcome (cegah cheating)
- Session `best_score` per user per scenario diperbarui

### Database Tables

`game_scenarios` · `game_sessions`

---

## M15 — Search

**Purpose:** Global search lintas entities dengan outlet scope  
**Actors:** All (scoped)  
**Flag:** —

### Flutter Files

| File | Link |
|------|------|
| Search feature | [lib/features/search/](https://github.com/supremeinori/arus/tree/main/app/lib/features/search) |

### Backend Files

| File | Link |
|------|------|
| Search module | [api/src/modules/search/](https://github.com/supremeinori/arus/tree/main/api/src/modules/search) |

### Endpoints

| Method | Path | Role | Description |
|--------|------|------|-------------|
| GET | `/search?q=<query>` | all | Grouped search results |

### Response Format

```json
{
  "data": {
    "products": [...],        // max 5
    "transactions": [...],    // max 5
    "outlets": [...],         // max 5 (scoped)
    "reports": [...]          // max 5
  }
}
```

### Business Rules

- BR-SRCH-01: Min 2 karakter
- BR-SRCH-02: Max 5 per group
- BR-SRCH-03: Hasil mengikuti outlet scope caller

### Database

Trigram indexes di `products.name`, `products.sku`, `transactions.receipt_no`

---

## M16 — Settings / Profile / Shell

**Purpose:** App shell (navigation), user settings, profile, about, feedback form  
**Actors:** All  
**Flag:** —

### Flutter Files

| File | Link |
|------|------|
| Shell / Nav | [lib/features/shell/](https://github.com/supremeinori/arus/tree/main/app/lib/features/shell) |
| Settings | [lib/features/settings/](https://github.com/supremeinori/arus/tree/main/app/lib/features/settings) |
| Profile | [lib/features/profile/](https://github.com/supremeinori/arus/tree/main/app/lib/features/profile) |
| About | [lib/features/about/](https://github.com/supremeinori/arus/tree/main/app/lib/features/about) |
| Feedback | [lib/features/feedback/](https://github.com/supremeinori/arus/tree/main/app/lib/features/feedback) |

### Backend Files

| File | Link |
|------|------|
| Settings module | [api/src/modules/settings/](https://github.com/supremeinori/arus/tree/main/api/src/modules/settings) |
| Feedback module | [api/src/modules/feedback/](https://github.com/supremeinori/arus/tree/main/api/src/modules/feedback) |

### Endpoints

| Method | Path | Role | Description |
|--------|------|------|-------------|
| GET | `/settings` | all | Get user settings |
| PUT | `/settings` | all | Update settings (currency, tz, sensor, biometric, notifications) |
| GET | `/auth/me` | all | Profile info |
| PUT | `/users/me` | all | Update own profile (name, avatar_url) |
| POST | `/feedback` | all | Submit kesan & saran PAM |
| GET | `/health` | — | Server health |

### Navigation Structure

**Owner/Manager (5 tabs):**
```
Beranda (Dashboard) | Operasi (POS/Inventory) | AI | Analitik | Lainnya
```

**Staff (4 tabs):**
```
Beranda (Shift KPI) | Kasir (POS) | Stok | Lainnya
```

### Settings Options

| Setting | Options |
|---------|---------|
| Display Currency | IDR · USD · EUR |
| Display Timezone | WIB · WITA · WIT · London |
| Shake Refresh | on/off |
| Tilt Chart | on/off |
| Biometric Unlock | on/off |
| Notification Types | per-type toggle |

### Database Tables

`user_settings` · `feedback`

---

## Requirement Traceability

| Req | Modul | Test IDs |
|-----|-------|----------|
| RQ-AUTH-1..5 | M01 | T-AUTH-01..08, T-RBAC-01..06 |
| RQ-DB-1..3 | All | T-DB-01..02 |
| RQ-API-1 | All | T-API-01..02 |
| RQ-POS-1 | M04 | T-POS-01..07 |
| RQ-INV-1 | M03 | T-INV-01..05 |
| RQ-ANA-1 | M06 | T-ANA-01..07 |
| RQ-DS-1 | M07 | T-DS-01..03 |
| RQ-AI-1 | M08 | T-AI-01..09 |
| RQ-RPT-1 | M09 | T-REP-01..03 |
| RQ-LBS-1 | M05 | T-LBS-01..04 |
| RQ-NOT-1 | M10 | T-NOT-01..05 |
| RQ-CUR-1 | M11 | T-CUR-01..02 |
| RQ-TZ-1 | M11 | T-TZ-01..02 |
| RQ-SEN-1..2 | M12 | T-SEN-01..05 |
| RQ-BC-1 | M13 | T-INT-01..06 |
| RQ-GAME-1 | M14 | T-GAME-01..03 |
| RQ-SRCH-1 | M15 | T-SRCH-01..03 |
| RQ-PRF-1 | M01, M16 | T-AUTH-04 |
| RQ-CORE-1 | All | T-CORE-01 |

---

*End of ARUS Module Plan v1.0*
