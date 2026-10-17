# ARUS Development & Architectural Playbook
*Generated and distilled from live session experience and proven workflows.*

---

## 1. Blockchain Single-Layer Persistent Ledger
- **Architecture**: Single-layer append-only ledger table (`BlockchainRecord`) replacing complex dual-chain overhead.
- **Atomicity**: All financial/inventory events (sale, void, return) MUST use `prisma.$transaction` to ensure database writes and ledger seals are atomic.
- **Hash Chaining**: Each record computes a SHA-256 hash using `prev_hash`, `outlet_id`, `event_type`, `payload`, and `timestamp`. The previous record's hash becomes `prev_hash` (fallback to 64 zeros for genesis).
- **Backup Integrity**: Store redundant snapshot columns (`backup_total`, etc.) to facilitate self-healing and rapid verification without parsing heavy JSON payloads.

---

## 2. Dynamic Recipe & Live HPP Calculation
- **Live HPP Rule**: Never store static HPP (`cost_idr`) in the `Product` table. Always calculate live via SQL/ORM aggregation: `SUM(amount_needed * cost_per_unit)` across active recipe ingredients (`ProductRecipe` + `Ingredient`).
- **Catalog Normalization**: SKU normalization (`trim().toUpperCase()`), duplicate prevention (409 conflict checks), and strict category validation.
- **Pricing & AI Recommendations**: Step-by-step menu creation wizard with real-time margin suggestions (30%, 50%, 100% markup) and direct integration into AI prompts.

---

## 3. Flutter Desktop Hit-Test & Layout Stability
- **Hit-Test Crash Prevention**: In Flutter desktop, removing bottom navigation or action bars conditionally (`if (condition) Widget()`) causes `RenderConstrainedBox` / `OutlinedButton` NEEDS-LAYOUT crashes during mouse tracking.
- **Rule**: Always keep bottom bars and action buttons in the widget tree (use disabled/greyed out states instead of conditional removal).
- **Button Constraints**: Ensure `OutlinedButton.icon` or custom buttons specify consistent constraints (`height: 38`, `minimumSize: Size(0, 38)`) matching the app theme.
- **Image Assets**: For custom mascot/logos packaged as SVG/PNG, ensure proper registration in `pubspec.yaml` assets and render using `Image.asset` with robust `errorBuilder` returning fixed-size widgets (never `SizedBox.shrink()`).

---

## 4. Global AI Companion Overlay & Screen-Aware Context
- **Overlay Architecture**: Global Floating Action Button (FAB) + `showModalBottomSheet` (`isScrollControlled: true`) so that underlying screen state (e.g. multi-step form data) is completely preserved while consulting AI.
- **Screen-Aware Context**: Frontend captures active screen state / form inputs and transmits `screen_context` to the backend.
- **Persistent Context Memory**: Backend injects `screen_context` into the Gemini system prompt, augmented by retrieving the last 5 chat logs from `ai_chat_logs` for session continuity.
