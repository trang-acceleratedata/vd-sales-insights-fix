# Design

## Decision Trail

### INVESTIGATE — mart_sales total_revenue low for March 2026

**Anchor:** `dbt:model.mart_sales` | **Window:** 2026-03-01 – 2026-03-31

#### Blast radius
`mart_sales` March 2026 reports `total_revenue = €6,355.21` against a correct value of ~€29,790.66; €23,435.45 (~78% of March revenue) is missing. Any consumer of this row is reading a severely wrong number.

#### Evidence pack

**Plane 1 (authored)**
- `intent.md` AC #2: all fulfilled orders count — statuses `shipped`, `delivered`, `returned`. (`provenance`)
- `stg_orders.sql:23`: `WHERE order_status IN ('shipped', 'delivered', 'returned')` (`code-inspection`)
- `sources.yml:20`: `accepted_values: ['shipped', 'delivered', 'returned']` (`code-inspection`)
- `design.md` ledger 2026-01-14: guard chosen so a vocabulary change surfaces as a failing test. (`provenance`)

**Plane 2 (runtime)**
- `git log` — single commit `17bc7ba` on all implicated files; message: "deployed product with a shipped defect (low March revenue)". (`runtime-audit`)
- `src_orders.audit_runs`: all pipeline runs succeeded, `git_sha = 17bc7bad…`; data landed cleanly. (`runtime-audit`)
- Gap: no local `run_results.json`; `accepted_values` test failure not confirmed from dbt output, but live data is unambiguous.

**Plane 3 (live)**
- `src_orders.orders` March 2026 by status: `completed` 110 rows €23,435.45; `delivered` 16 rows €2,948.21; `shipped` 14 rows €3,407.00. (`sql-probe`)
- `mart_sales` March: `total_revenue = €6,355.21`, `order_count = 30` — matches only `delivered` + `shipped`; `completed` entirely absent. (`sql-probe`)
- January and February have no `completed` rows; those months correct.

#### RCA
The commerce platform introduced status `completed` in March 2026. `stg_orders.sql` and `sources.yml` were authored against the original vocabulary and not updated. `completed` orders land in the bronze table but are silently dropped by the `stg_orders` filter, causing March `total_revenue` to be understated by ~78%.

**Confidence:** High. Probe arithmetic matches exactly. Gap: no dbt test output confirming `accepted_values` failure.

#### Decision: `code-change`

Evidence-completeness gate:
1. ✓ Concrete claim with pointer: sql-probe on `src_orders.orders` confirms 110 `completed` rows excluded for March.
2. ✓ Class: Failing / missing dbt test — wave-1 whitelist.
3. ✓ Sandbox verification: re-run `stg_orders` + `mart_sales`; verify March `total_revenue` ≈ €29,790.66, `order_count` = 140; `accepted_values` test passes.

**Change applied (approved by requester):**
- `models/staging/stg_orders.sql:23` — added `'completed'` to the `WHERE IN` list.
- `models/staging/sources.yml:20` — added `'completed'` to `accepted_values`.
