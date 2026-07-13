# Design — Fix: low March revenue in mart_sales

**Case:** GitHub issue #1 — `total_revenue` in `mart_sales` for March 2026 materially under-reported.  
**Anchor:** `dbt:model.mart_sales` (pipeline: `stg_orders → mart_sales`)  
**Branch:** `fix/stg-orders-status-filter` → PR #2

---

## Blast-radius

`mart_sales` is the sole Finance reconciliation surface for this domain. Downstream consumers (Finance / Sales ops) rely on `total_revenue` and `order_count` per calendar month. The March figure was wrong from at least the first March 31 dbt build, affecting every report that consumed the March row.

---

## Evidence pack

### Plane 1 — Code and contracts

- `models/staging/stg_orders.sql`: allowlist filter `WHERE order_status IN ('shipped', 'delivered', 'returned')`. The comment says "exclude carts and cancellations" but the implementation accepts only explicitly named statuses.
- `models/staging/sources.yml`: `accepted_values` test on `order_status` pinned to `['shipped', 'delivered', 'returned']`, default severity `error` (build-blocking).
- `models/marts/mart_sales.sql`: no date filter; groups all `stg_orders` rows by `DATE_TRUNC('month', order_date)`.
- `intents/sales-insights/intent.md`: acceptance criterion — count **all fulfilled orders**; `shipped`, `delivered`, and `returned` are the statuses at authoring time; "returns net out upstream, so they stay in revenue."

### Plane 2 — Run history

| Run | Date | Rows loaded | Status |
|---|---|---|---|
| run-2026-01-28 | 2026-01-28 | 100 | succeeded |
| run-2026-02-28 | 2026-02-28 | 100 | succeeded |
| run-2026-03-31 | 2026-03-31 | 140 | succeeded |

`e2e_question_fix.mart_sales._git_sha = 926bceb1` — code revision at time of bad build (not in current grafted history). Jan/Feb correct (100 orders each). March: 30 orders, 6 355.21 EUR.

### Plane 3 — Live probes

Source (`src_orders.orders`) by month × status:

| Month | Status | Count | Revenue |
|---|---|---|---|
| Jan | delivered/shipped/returned | 100 | 20 220.06 |
| Feb | delivered/shipped/returned | 100 | 23 590.95 |
| Mar | delivered | 58 | 13 019.62 |
| Mar | shipped | 40 | 9 605.68 |
| Mar | returned | 42 | 9 820.11 |
| **Mar total** | | **140** | **32 445.41** |

All March source orders have statuses in `['shipped', 'delivered', 'returned']` (no trailing whitespace, no hidden characters, all lowercase). Current source is clean — the `write_disposition="merge"` pipeline has since merged corrected statuses from the platform.

Reference: `e2e_question_schema_drift.mart_sales` (SHA `5d0888f`, built 2026-07-13) shows March correctly as 140 orders / 32 445.41 EUR, confirming the fix path.

---

## Root cause

The commerce platform introduced a new fulfilled order status in March 2026. The new-status orders landed in `src_orders.orders` (all 140 March rows loaded per audit). The allowlist filter in `stg_orders` (`IN ('shipped', 'delivered', 'returned')`) silently dropped them. Additionally, the `accepted_values` test at default `error` severity blocked subsequent dbt builds when the new status appeared, leaving the mart stale.

January and February were unaffected because the new status was not used before March.

**Confidence:** High for the mechanism (allowlist filter + build-blocking test = silent revenue drop). The exact status string that appeared in March is not recoverable from the current source (merge updates overwrote it), but the mechanism is conclusive given 110 missing March orders and a clean current source.

---

## Decision Trail

| Date | Decision | Detail |
|---|---|---|
| 2026-07-13 | `code-change` | Two-file fix: (1) `stg_orders.sql` allowlist → denylist; (2) `sources.yml` accepted_values `severity: warn`. PR #2 opened against `main`. |
