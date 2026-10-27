# ARUS --- Repair Roadmap for Coding Agents

## Purpose

This document is the single source of truth for investigating and fixing
ARUS data integrity, offline POS, analytics, forecasting, and branch
naming issues.

**Execution rule:** work on one phase at a time. Begin with Phase 0
(audit only). Proceed only after the current phase's findings, tests,
and acceptance criteria have been reviewed.

Use `@graphify` to map code relationships, but verify important findings
in source code, configuration, database schema, and tests.

## Reported symptoms (not yet verified root causes)

1.  Branch names appear unnatural or inconsistent. Desired style
    includes names such as `ARUS Coffee Sudirman`, using the approved
    location for each branch.
2.  Time-series forecasting appears not to use the full relevant
    transaction history.
3.  The green "Tren" bar chart on the home screen appears static or
    disconnected from the current date/selected period.
4.  Offline transactions can be queued, but today's history may be
    unavailable and local stock may not update immediately.
5.  Refresh/reconnection sometimes appears to do nothing, and backend
    connectivity errors can leave confusing UI states.

Do not treat these reports as proof of a particular implementation
defect. Verify behavior and root cause.

## Non-negotiable rules

-   Inspect the existing architecture first. Do not assume framework
    details, file names, endpoints, tables, or schema fields.
-   Use `@graphify` to trace dependencies. If the graph is missing or
    stale, follow the project's Graphify workflow to update it.
-   Do not invent data, branch names, transaction records, or test
    results.
-   Remove fake/mock/hardcoded **business data used as real data** from
    production paths. Keep legitimate constants, test fixtures, seed
    data, and explicit UI placeholders where appropriate; classify
    before changing.
-   Never silently substitute fake data when an API request fails.
-   Do not present cached/local data as current server data. Clearly
    label pending/offline data.
-   Preserve unrelated functionality and prefer small, reviewable
    changes.
-   Do not log credentials, access tokens, or sensitive customer data.
-   A successful build alone does not prove the fix works.
-   Inspect migration and rollback implications before risky schema
    changes. Do not run destructive production operations.
-   Use clear, actionable Indonesian UI messages for user-facing errors.
-   Do not continue to the next phase automatically.

## Phase overview

  -------------------------------------------------------------------------
  Phase                   Name                    Scope
  ----------------------- ----------------------- -------------------------
  0                       Audit and dependency    Trace architecture,
                          map                     reproduce symptoms,
                                                  identify root causes,
                                                  plan tests. **No
                                                  application-code
                                                  changes.**

  1                       Data foundation and     Classify mock data,
                          branch names            verify data contracts,
                                                  normalize approved branch
                                                  display names.

  2                       Offline POS and         Durable local
                          synchronization         transactions, immediate
                                                  local stock mutation,
                                                  queue, idempotent sync,
                                                  conflict handling.

  3                       History, dashboard, and Correct date filters,
                          trend chart             local/server data
                                                  composition, dynamic
                                                  trend aggregation,
                                                  refresh behavior.

  4                       Historical forecasting  Full relevant history,
                                                  preprocessing, baselines,
                                                  time-aware
                                                  evaluation/backtesting.

  5                       End-to-end regression   Cross-phase tests and
                                                  release-readiness review.
  -------------------------------------------------------------------------

------------------------------------------------------------------------

# Phase 0 --- Audit and dependency map (AUDIT ONLY)

## Objectives

1.  Map frontend, backend, persistence, API, authentication, POS, stock,
    history, analytics, and forecasting modules.
2.  Trace a cashier transaction from UI input through local persistence,
    queue, backend API, database transaction, stock mutation, analytics,
    and history.
3.  Trace the "Tren" chart and forecasting pipelines back to their
    actual data sources and date filters.
4.  Find mock, hardcoded, seed, fallback, and cached business data;
    classify each use.
5.  Determine why refresh/reconnection can appear to do nothing.
6.  Identify the smallest safe implementation sequence and tests for
    each phase.

## Investigation checklist

-   Use `@graphify` to locate relevant nodes, callers, dependencies, and
    entry points.
-   Verify graph findings in source code; list exact file paths and
    relevant functions/classes.
-   Inspect database schema, migrations, API contracts, query filters,
    and transaction boundaries.
-   Identify data sources for branch lists, home dashboard, trend chart,
    history, stock, and forecasting.
-   Check loading/error/empty/offline states and whether refresh
    callbacks actually trigger requests.
-   Check local cache behavior and how freshness/sync status is
    represented.
-   Check transaction identity, retry behavior, duplicate prevention,
    and partial-failure handling.
-   Identify timezone/date-boundary behavior and branch scoping.
-   Review existing tests and note missing coverage.
-   Reproduce symptoms where possible. If not reproduced, say so; do not
    assume fixed.

## Phase 0 deliverable

Produce an audit report containing:

1.  Architecture and end-to-end data-flow map.
2.  Findings grouped by the reported symptoms.
3.  Evidence for each finding: file, symbol/function, observed behavior,
    and relevant test/log evidence.
4.  Root-cause confidence: confirmed, probable, or unverified.
5.  Mock/hardcoded/fallback data inventory, classification, and
    recommended action.
6.  Dependency order and risk assessment for Phases 1--5.
7.  Test plan and baseline test/build results.
8.  Product decisions that require confirmation, especially branch names
    and offline stock-conflict policy.

**Acceptance criteria:** distinguish facts from hypotheses, identify
exact code paths, do not fabricate runtime results, and propose a
bounded plan. Stop after reporting. Do not change application code in
Phase 0.

------------------------------------------------------------------------

# Phase 1 --- Data foundation and branch names

## Tasks

1.  Inventory mock data, hardcoded business values, placeholder records,
    default objects, and fallback responses.
2.  Classify each as production fake data, legitimate configuration,
    test fixture, development seed, UI placeholder, or intentional
    offline cache.
3.  Remove/isolate only fake data incorrectly used in production. Keep
    test fixtures and legitimate configuration.
4.  Ensure API errors are surfaced instead of silently replaced with
    fake metrics, branches, transactions, stock, or forecast values.
5.  Inspect authoritative branch records and approved location names
    before changing display names.
6.  Use a consistent pattern such as `ARUS Coffee Sudirman`, but do not
    invent a location. If the correct location is unknown, request
    confirmation.
7.  Ensure branch identity uses stable IDs, not display names.
8.  Document response types, nullability, loading/error/empty states,
    and data ownership where necessary.

## Acceptance criteria

-   No production error path silently presents fabricated business data
    as actual data.
-   Legitimate static configuration and test fixtures remain intact.
-   Branch display names are consistent and grounded in approved data.
-   Branch-specific queries continue to use stable identifiers.
-   Relevant tests, static analysis, and builds pass, or failures are
    documented.

Stop and report before Phase 2.

------------------------------------------------------------------------

# Phase 2 --- Offline POS and reliable synchronization

## Core behavior

When offline, a transaction must be saved locally before the UI reports
it as accepted. Local stock should update immediately according to
existing POS rules. Backend stock and server analytics update after
successful synchronization. The UI must distinguish local/pending state
from server-confirmed state.

## Tasks

1.  Trace local storage, transaction model, queue worker, API
    submission, and stock mutation logic.
2.  Persist each offline transaction and its line items durably; do not
    rely only on in-memory state.
3.  Assign a stable unique transaction/idempotency identifier before
    enqueueing.
4.  Update local history and local stock immediately after the local
    transaction is committed successfully.
5.  Make local transaction persistence and local stock changes atomic
    where supported by the storage layer.
6.  Use clear statuses such as `pending`, `syncing`, `synced`, and
    `failed`, following existing conventions where possible.
7.  Retry transient failures safely; prevent duplicate server
    transactions; preserve queue order where required; retain queue
    items until server success is confirmed or a recovery state is
    recorded.
8.  Inspect backend transaction boundaries. A successful sync should
    apply transaction and stock changes consistently, ideally in a
    database transaction.
9.  Handle stock conflicts explicitly. Do not silently overwrite server
    stock or subtract stock twice. Follow existing product policy;
    otherwise document the decision needed.
10. Reconcile local stock with server-confirmed state without applying
    the same mutation twice.
11. Make connection restoration trigger a reliable sync attempt, but
    also consider safe retries on app resume or explicit retry.
12. Keep UI responsive and avoid infinite loading or repeated request
    loops.

## Required scenarios

-   Create a transaction online.
-   Create a transaction offline.
-   Close/reopen the app while a transaction is pending.
-   Lose connectivity during submission.
-   Restore connectivity and retry.
-   Receive a timeout after the server may already have committed.
-   Submit the same transaction more than once.
-   Encounter insufficient/conflicting stock at sync time.
-   Have one queued item fail while later items remain queued.
-   Switch branches while pending transactions exist.

## Acceptance criteria

-   An accepted offline transaction survives app restart.
-   Local stock and history reflect it immediately.
-   Pending data is clearly marked as not server-confirmed.
-   Retry does not create duplicate transactions or stock deductions.
-   Queue items are retained until confirmed sync or a clear recovery
    state.
-   Server transaction and stock changes are consistent.
-   Conflicts are visible and handled according to documented business
    rules.
-   Tests cover these scenarios as supported by the project's test
    infrastructure.

Stop and report before Phase 3.

------------------------------------------------------------------------

# Phase 3 --- History, dashboard, and "Tren" chart

## Tasks

1.  Trace the source of every history/dashboard metric and record
    whether it comes from server data, local data, or an intentional
    combination.
2.  Define how pending offline transactions contribute to local history
    and summaries.
3.  Avoid double-counting pending transactions after the server returns
    them. Deduplicate by stable transaction ID.
4.  Show freshness/sync indicators when data includes pending
    transactions or comes from a last successful fetch.
5.  When offline, show available local history/summaries rather than a
    generic error. If data is unavailable, show a clear
    unavailable/empty state.
6.  Audit refresh callbacks: confirm they trigger a real fetch; show
    loading feedback; handle success/failure; prevent overlapping
    requests and stale responses; allow retry.
7.  Make "Tren" bars derive from actual transactions grouped by the
    correct date/time interval.
8.  Use the current date or selected range as specified by the UI.
    Verify timezone and day-boundary logic.
9.  Handle empty dates and missing periods consistently; remove static
    demo bars from production display; ensure labels match represented
    data.
10. Confirm branch filters are applied consistently to history,
    dashboard, and chart.
11. Test date boundaries and branch/period switching.

## Acceptance criteria

-   Bars and labels change when transactions/date ranges change.
-   Static demo bars are not presented as real production metrics.
-   Offline local history and summaries remain usable where local data
    exists.
-   Pending transactions are not double-counted after sync.
-   Refresh provides observable loading/success/error feedback and
    recovers after failure.
-   Branch and date filters are consistent.

Stop and report before Phase 4.

------------------------------------------------------------------------

# Phase 4 --- Historical time-series forecasting

## Tasks

1.  Trace the full pipeline from database query through preprocessing,
    aggregation, feature creation, model input, prediction, and UI
    display.
2.  Determine the forecast target and grain (for example daily revenue,
    units sold, or transaction count). Do not mix targets.
3.  Audit query limits, date filters, pagination, truncation,
    aggregation, and accidental use of only recent records.
4.  Use all relevant history available for the intended business scope,
    subject to a justified training window and data quality. More
    history is not automatically better.
5.  Aggregate at a consistent time grain/timezone. Handle dates with no
    transactions explicitly.
6.  Identify missing data, duplicates, returns/cancellations, outliers,
    branch boundaries, and pending transactions. Apply documented rules.
7.  Prevent leakage: features must not use information unavailable at
    forecast time.
8.  Establish a simple baseline, such as naive or seasonal-naive
    forecasting where appropriate.
9.  Evaluate with chronological holdout or rolling-origin backtesting.
    Choose metrics appropriate to the target and explain limitations.
10. Compare the current method with the baseline. Increase model
    complexity only when results justify it.
11. Display forecast horizon, target, and limitations accurately.
12. If history is insufficient, show that limitation instead of
    misleading precision.

## Acceptance criteria

-   Actual historical input coverage is measured and documented.
-   Confirmed query truncation or unintended filtering is fixed.
-   Evaluation uses data not used to fit the evaluated model.
-   Results are compared with a baseline and reported with actual
    metrics.
-   No accuracy improvement is claimed without evidence.
-   UI accurately represents target, horizon, and limitations.

Stop and report before Phase 5.

------------------------------------------------------------------------

# Phase 5 --- End-to-end regression and release readiness

## Cross-system scenarios

1.  Online transaction → server confirmation → stock/history/dashboard
    updates.
2.  Offline transaction → local stock/history update → app restart →
    reconnect → exactly one successful sync.
3.  Retry after an ambiguous timeout without duplicate transaction or
    stock mutation.
4.  Partial sync failure followed by recovery.
5.  Stock conflict during sync.
6.  Branch switch while pending transactions exist.
7.  Refresh while online, offline, and during reconnection.
8.  Dashboard and "Tren" after online/offline transactions.
9.  Forecast refresh after new transactions sync.
10. Empty history, insufficient forecast history, malformed API
    response, authentication failure, and server outage.

## Release-readiness checks

-   Run relevant unit, integration, and widget tests.
-   Run backend/frontend tests, static analysis/lint, and builds
    available in the repository.
-   Inspect logs for duplicate requests, uncaught exceptions, and
    sensitive data leakage.
-   Review migrations and rollback implications.
-   Confirm error messages are actionable and do not expose secrets.
-   Record manual tests requiring a physical device, actual network
    disconnection, or deployment environment.
-   Do not mark the system production-ready while critical scenarios
    remain unverified.

## Final report format

For each phase, report:

1.  Scope completed.
2.  Confirmed root causes and evidence.
3.  Files and migrations changed.
4.  Tests/checks executed with exact results.
5.  Manual tests performed and environment.
6.  Known limitations and remaining risks.
7.  Acceptance criteria marked `PASS`, `FAIL`, or `NOT VERIFIED`.
8.  Recommendation: proceed, revise, or stop.

Never fabricate test results. Distinguish "not run," "failed," and
"passed."

------------------------------------------------------------------------

# Prompt for Phase 0 --- Audit only

Use this prompt first. Do not start implementation until the audit has
been reviewed.

``` text
@graphify

Read ARUS_REPAIR_ROADMAP.md in full. Execute Phase 0 only: audit and dependency mapping.

Use Graphify to map the relevant code and trace the actual data flow for branch names/data, offline POS and stock, synchronization/reconnection, transaction history, the home “Tren” chart, and time-series forecasting. Verify important graph findings against source code, API contracts, database schema/migrations, and existing tests.

Do not modify application code, database schema, migrations, or configuration. You may run safe read-only inspection and existing tests/checks.

Report exact file paths and symbols, observed behavior, confirmed versus suspected root causes, mock/hardcoded/fallback data classification, dependencies between phases, baseline test results, and a prioritized implementation plan. Identify product decisions that cannot safely be inferred, especially branch names and offline stock-conflict policy.

Do not fabricate findings or test results. Stop after the audit report and wait for approval.
```

# Prompt template for later phases

After reviewing the audit, use this template for one phase at a time:

``` text
@graphify

Read ARUS_REPAIR_ROADMAP.md and the reviewed Phase 0 audit report. Implement Phase [NUMBER] only.

First verify that the dependencies and acceptance criteria for this phase are understood. Keep changes within this phase's scope. Follow the roadmap's data integrity, offline behavior, security, and testing rules. Do not silently substitute mock data, skip failing tests, or claim unverified behavior works.

Run relevant tests, static analysis, and build checks. Report root causes addressed, files changed, exact verification results, acceptance criteria marked PASS/FAIL/NOT VERIFIED, and remaining risks. Do not begin the next phase; stop and wait for review.
```
