# Design — case: mart_sales low March 2026 revenue

## Decision Trail

### INVESTIGATE — 2026-07-09

**Anchor:** `dbt:model.mart_sales` (sales-insights product)
**Time window:** March 2026 (`sales_month = 2026-03-01`)

#### Blast radius
`mart_sales.total_revenue` and `order_count` for March 2026 are understated by €23,435.45 and 110 orders (~79% of actual March revenue). Any downstream consumer of `mart_sales` receives incorrect figures for March.

#### Evidence pack

**Plane 1 — repo as authored**
- `intent.md` AC2 (`provenance`): fulfilled statuses at authoring = `shipped`, `delivered`, `returned`.
- `models/staging/stg_orders.sql:23` (`code-inspection`): `WHERE order_status IN ('shipped', 'delivered', 'returned')` — status whitelist hardcoded.
- `models/staging/sources.yml:19-21` (`code-inspection`): `accepted_values` guard pins the same three statuses.
- `intents/sales-insights/design.md` Ledger 2026-01-14 (`provenance`): "Guard chosen over silent pass-through — upstream vocabulary change surfaces as a failing test."

**Plane 2 — runtime evidence**
- `git log` (`runtime-audit`): single commit `17bc7ba` — "deployed product with a shipped defect (low March revenue)." No `run_results.json` available — gap recorded.

**Plane 3 — live warehouse state**
- `sql-probe` on `src_orders.orders`: status `completed` present with 110 rows / €23,435.45 total (all in March 2026); not in the original whitelist.
- `sql-probe` on `e2e_question_fix.mart_sales`: March 2026 shows `total_revenue = €6,355.21`, `order_count = 30` — matches only `delivered` (16) + `shipped` (14); `completed` orders are absent.

#### Root cause
The commerce platform introduced a new fulfilled status `completed` after the product shipped (2026-01-15). The `WHERE` clause in `stg_orders.sql:23` hardcodes the original three statuses and silently excludes all `completed` orders. The `accepted_values` guard in `sources.yml:20` would surface this as a failing test but does not prevent the mart from rebuilding with the incomplete filter.

**Confidence:** High — source data and mart output are unambiguous. Gap: no `run_results.json` to confirm whether the `accepted_values` test fired.

#### Decision: `code-change` (approved by requester)

**Fix applied:**
1. `models/staging/stg_orders.sql:23` — added `'completed'` to the `WHERE order_status IN (...)` filter.
2. `models/staging/sources.yml:20` — added `'completed'` to the `accepted_values` list.

**Evidence-completeness gate:**
- Leg 1 ✅ Concrete claim with pointer: `sql-probe` on `src_orders.orders` and `e2e_question_fix.mart_sales`.
- Leg 2 ✅ Class: schema drift (upstream vocabulary change) — on whitelist.
- Leg 3 ✅ Sandbox verification: compile + run `stg_orders` + `mart_sales`; confirm March `total_revenue` ≈ €29,790 and `order_count` = 140.
