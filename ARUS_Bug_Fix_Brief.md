# ARUS --- Bug Fix & Improvement Brief

## Objective

Audit and fix the issues below in the existing ARUS application. Use the
actual codebase, database schema, API contracts, and current
implementation to determine the correct entities, roles, branches, and
business rules. Do not assume access to production data or invent branch
names, records, credentials, or database values.

This document describes expected behavior, not the names of specific
database records. Identify affected records and test cases from the
schema, migrations, ORM models, API contracts, seed data, local
development environment, or available fixtures. If required data is
unavailable, document what cannot be verified and use controlled test
fixtures where appropriate.

## Working rules

1.  Inspect the existing architecture and relevant project instructions
    before making changes.
2.  For complex, cross-module work, use the installed Graphify
    integration to query relevant code relationships when useful, then
    verify findings against source code.
3.  Identify root causes before editing. Prefer repairing existing
    mechanisms over creating parallel systems.
4.  Keep changes scoped to the listed issues. Do not make unrelated
    refactors.
5.  Do not replace real database-backed behavior with hardcoded or mock
    values.
6.  Do not assume production database access. Infer schema and
    relationships from migrations, ORM models, API contracts, and
    available fixtures; request access only if genuinely necessary.
7.  Do not modify database schemas, API contracts, or architecture
    unless required. If a schema change is necessary, explain why and
    add a safe migration.
8.  Never claim success without verifying the relevant behavior. Report
    tests that fail, are blocked, or were not run.
9.  Preserve authorization boundaries between roles and branches.
10. After meaningful source changes, update the Graphify index using the
    installed version's supported mechanism when appropriate.

## 1. Cashier --- branch-scoped inventory and product availability

### Problem

Product availability is estimated from the amount of finished menu items
that can be produced using available ingredients. Some ingredients may
not exist at every branch. The current behavior can show a positive
estimated product quantity even when required ingredients are
unavailable at the cashier's branch.

### Expected behavior

-   Inventory calculations must use ingredient quantities belonging to
    the active branch only.
-   Ingredients from another branch must never contribute to local
    product availability unless an explicit, authorized stock-transfer
    or shared-inventory rule exists in the current business model.
-   If a required ingredient is missing or has zero usable quantity at
    the active branch, the estimated producible quantity of the affected
    menu item must be zero.
-   Cashiers must not be able to complete transactions for products that
    are unavailable under the branch's inventory rules.
-   Enforce availability in authoritative transaction/business logic,
    not only by hiding or disabling UI controls.
-   Keep the inventory display, transaction validation, and
    post-transaction stock updates consistent.
-   Respect existing recipe, ingredient-unit, conversion, reservation,
    and finished-goods rules. Do not assume product stock is identical
    to raw-material stock.

### Verification

Test a branch with all required ingredients available, a branch missing
one required ingredient, zero quantity, insufficient quantity, and
inventory belonging only to another branch. Verify displayed estimates
and transaction rejection/acceptance.

## 2. Owner --- dashboard and transaction history when switching branches

### Problem

The owner dashboard/home screen sometimes displays hardcoded or stale
data after switching branches. The transaction-history view can also
load inconsistently.

### Expected behavior

-   Dashboard and history data must come from the intended live data
    source, subject to the application's offline design.
-   Switching the selected branch must load data for that branch and
    must not retain or mix data from the previous branch.
-   Handle loading, empty, error, refresh, and retry states
    consistently.
-   Prevent stale or slower requests for a previously selected branch
    from overwriting results for the current selection.
-   Do not present hardcoded fallback values as actual business data.
-   Preserve owner authorization and branch scope.

### Verification

Switch branches repeatedly, trigger refreshes, and test delayed, failed,
empty, and successful requests. Confirm every rendered result
corresponds to the current selection.

## 3. Owner --- branch-specific alerts and issues

### Problem

The number and type of inventory warnings can appear identical across
branches despite different inventory conditions.

### Expected behavior

-   Calculate warnings from the selected branch's actual data and
    existing business rules.
-   Zero or missing required ingredients must generate the appropriate
    warning where the rules define them as issues.
-   Do not use a cross-branch aggregate for a branch-specific screen
    unless explicitly intended.
-   Refresh warning counts, categories, and details when the selected
    branch changes.
-   Avoid duplicate warnings and stale results.

### Verification

Use fixtures with deliberately different inventory conditions across
branches. Confirm warning types, counts, and details differ when
underlying conditions differ.

## 4. Login --- biometric registration and authentication

### Problem

Biometric login reports that no biometric account is registered,
including after manual login, enabling biometrics, logging out, and
trying biometric login again.

### Expected behavior

-   Trace the full registration, persistence, logout, and
    biometric-login flow.
-   Ensure activation persists the credential or secure reference
    required by the existing authentication design.
-   Ensure registration can be retrieved after logout and app restart.
-   Handle device capability, permission, cancellation, and
    authentication failure explicitly.
-   Store secrets only in appropriate secure storage; do not store
    authentication secrets in plaintext or an ordinary database field.
-   Local biometric verification must not replace server authentication
    or session validation.
-   Do not report biometric login as successful unless the resulting
    session is valid.

### Verification

Test first-time setup, successful registration, logout/login, app
restart, cancellation, failed biometric verification, unavailable
hardware, and cleared secure storage.

## 5. Owner --- map and location-based service (LBS)

### Problem

The map does not show the user's current position. After selecting the
nearest branch, the map may stop responding to gestures until the page
is reopened.

### Expected behavior

-   Request location permission when the location feature is used and
    explain its purpose where needed.
-   Obtain actual device location through the available location
    provider.
-   Display the user's location on the OpenStreetMap-based map when
    permission and location data are available.
-   Handle denied permission, unavailable location services, timeout,
    and errors without fabricating coordinates.
-   Selecting the nearest branch may move the map camera but must not
    disable panning, zooming, or other map interaction.
-   Review map controller lifecycle, gesture handling, listeners,
    asynchronous state changes, and disposal/recreation behavior.
-   Keep location and branch selection behavior consistent with existing
    authorization rules.

### Verification

Test permission granted and denied, location unavailable, selecting a
nearest branch, repeated selections, and map interaction before and
after selection.

## 6. Cashier --- reliable offline operation

### Problem

Offline mode does not reliably expose summaries or support transactions.
Some transactions can be recorded locally, but inventory, transaction
count, and revenue do not update until the app is online and refreshed.

### Expected behavior

-   Define which data is available offline based on data already cached
    or stored locally.
-   Persist offline transactions locally so they survive app restarts.
-   After a local transaction is accepted, update the local inventory
    projection, transaction count, revenue, and relevant summaries
    immediately according to business rules.
-   Read available transaction history and summaries from local storage
    while offline.
-   Preserve unsynchronized transactions when synchronization fails.
-   Make synchronization idempotent so retries do not create duplicate
    server transactions.
-   Track pending, synchronized, and failed synchronization states where
    appropriate.
-   Handle stock conflicts across devices using existing server-side
    consistency rules. Do not claim local inventory is globally
    authoritative while disconnected.
-   Keep online and offline transactions within one coherent business
    model rather than building unrelated parallel transaction systems.
-   Before-login offline access must not bypass authentication or expose
    sensitive branch/user data. Preserve the existing security model and
    use previously authenticated local access only if supported safely.

### Verification

Test offline startup, authenticated offline session, successful local
transaction, app restart, repeated synchronization, synchronization
failure/retry, duplicate prevention, and reconciliation with server
state.

## 7. Cashier --- transaction history access and item details

### Expected behavior

-   Allow cashiers to view transaction history within their authorized
    scope.
-   Show transaction time, transaction identifier, total, and relevant
    status.
-   Provide line-item details for each transaction, including product,
    quantity, unit price, and subtotal when those values exist in the
    transaction record.
-   Show synchronization status where relevant.
-   Make locally stored history available offline when data has been
    cached or recorded locally.
-   Do not expose transactions belonging to unauthorized branches or
    users.

## 8. Owner --- transaction line-item details

### Problem

Owner history currently emphasizes total item count and transaction
total without sufficient product-level detail.

### Expected behavior

-   Allow the owner to open a transaction and inspect individual
    products, quantities, unit prices, subtotals, transaction total,
    time, and other relevant persisted details.
-   Respect the selected branch and the owner's authorization scope.
-   Use historical transaction prices and quantities when persisted; do
    not reconstruct historical sales using current product prices.
-   Handle older transactions that lack some details gracefully and
    transparently.

## 9. Owner and cashier --- offline history and summaries

Implement this as part of the offline work above rather than as a
separate competing data system.

### Expected behavior

-   Use local data for history, sales totals, inventory projections, and
    summaries while offline, to the extent that data is available
    locally.
-   Update local views immediately after a locally accepted transaction.
-   Synchronize safely when connectivity returns.
-   Avoid counting the same transaction twice when combining local
    pending data with server-confirmed data.
-   Make it clear when displayed data is local, potentially stale,
    pending synchronization, or server-confirmed.
-   Ensure online refresh does not erase unsynchronized local
    transactions.

## 10. Push notifications --- out-of-stock alerts

### Problem

Push notifications are not reliably delivered when inventory becomes
unavailable, although the application is expected to notify the
appropriate users.

### Expected behavior

Audit the entire existing notification flow: - The business event that
detects a relevant transition to out-of-stock. - Recipient selection
based on actual roles, branch scope, and existing business rules. -
Device-token registration, persistence, refresh, and invalid-token
handling if applicable. - Permissions, Android notification
channels/importance/sound, and foreground/background handling. - The
existing push provider or delivery service. - Error logging, retries
where appropriate, and duplicate prevention. - Behavior when the app is
foregrounded, backgrounded, or terminated by the operating system.

Use the existing provider and backend where feasible. Do not switch
providers or introduce a new notification architecture without a
demonstrated need.

Define whether notifications should be sent only when stock transitions
from available to unavailable, or also when the system first detects an
already-empty stock condition. Follow existing business rules or
document the necessary decision.

Do not claim end-to-end delivery based solely on a successful function
call. Distinguish between event detection, send request acceptance,
provider delivery evidence, and device display. Document any external
configuration or real-device testing still required.

## Recommended implementation order

1.  Audit architecture, data model, relevant code paths, and
    dependencies.
2.  Fix branch scoping and inventory correctness, including transaction
    validation.
3.  Fix owner dashboard, history loading, and branch-specific warnings.
4.  Fix consistent offline persistence, local projections, and safe
    synchronization.
5.  Add transaction line-item details for cashier and owner.
6.  Fix biometric registration and login.
7.  Fix map location and interaction lifecycle.
8.  Fix out-of-stock push notifications.
9.  Run regression tests across roles, branches, online/offline states,
    and relevant devices.

## Completion report

For each workstream, report: - Root cause identified. - Files/components
changed. - Behavior implemented. - Tests actually run and their
results. - Any remaining failure, limitation, or external configuration
requirement.

Do not stop after producing an audit or plan. Implement fixes in
manageable groups. Do not conceal test failures or mark unverified
behavior as complete.
