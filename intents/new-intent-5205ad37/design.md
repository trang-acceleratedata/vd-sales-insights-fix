# Design — INVESTIGATE: mart_sales low March 2026 revenue

**Anchor:** `dbt:model.mart_sales` (product: sales-insights)  
**Time window:** March 2026 (`sales_month = 2026-03-01`)  
**Case branch:** `intent/new-intent-5205ad37`

---

## Decision Trail

### INVESTIGATE — 2026-07-15

#### Blast-radius statement

`mart_sales` is the sole downstream consumer of `stg_orders`; Finance's monthly reconciliation reads `total_revenue` directly from `mart_sales`. March 2026 `total_revenue` is understated by **$23,435.45** (correct: ~$29,790.66; reported: $6,355.21) and `order_count` is short by **110 orders**. January and February are unaffected — zero `completed`-status orders exist in those months.

#### Plane 1 — repo as authored

| Claim | Tag | Pointer |
| --- | --- | --- |
| `intent.md` acceptance criterion: fulfilled statuses at authoring time are `shipped`, `delivered`, `returned`; cart and cancellation rows excluded | `provenance` | `intents/sales-insights/intent.md` §Acceptance criteria |
| `stg_orders.sql:23` filter: `WHERE order_status IN ('shipped', 'delivered', 'returned')` — explicit whitelist, no other statuses pass | `code-inspection` | `models/staging/stg_orders.sql:23` |
| `sources.yml:19-21` `accepted_values` guard on `order_status` pinned to the same three values | `manifest` | `models/staging/sources.yml:19-21` |
| `design.md` Ledger 2026-01-14: "accepted_values guard pins the status vocabulary so an upstream vocabulary change surfaces as a failing test" — the guard was deliberately designed to catch this class of failure | `provenance` | `intents/sales-insights/design.md` Ledger row 2026-01-14 |

"Correct" for this case: `total_revenue` must sum every order with `order_status` in the platform's fulfilled vocabulary, currently `shipped`, `delivered`, `returned`, and any later-added fulfilled status.

#### Plane 2 — runtime evidence

- **Elementary tables:** absent from domain lakehouse — Elementary not installed. Gap recorded; no DQ test output available. [`schema: no elementary tables found`]
- **dbt target artifacts:** not available at domain OneLake prod path (404). Gap recorded; no `run_results.json` to confirm test failure.
- **`dbt_project.yml`:** no Elementary vars; no `disable_run_results` flag — Elementary simply not installed. The `accepted_values` test would have fired as a standard dbt test, but output is unavailable.
- **`git log`:** single commit `17bc7ba` — "sales-insights: deployed product with a shipped defect (low March revenue)". Confirms the defect shipped in the initial deployment.

*Gap:* No failing test output can be cited. Plane 3 concrete evidence is sufficient.

#### Plane 3 — live warehouse state

| Probe | Result | Tag | Pointer |
| --- | --- | --- | --- |
| `src_orders.orders` grouped by `order_status` for March 2026 | `completed`: 110 rows, $23,435.45; `delivered`: 16 rows, $2,948.21; `shipped`: 14 rows, $3,407.00 — total 140 rows, $29,790.66 | `sql-probe` | `kuruma_prod_lake.src_orders.orders WHERE order_date >= '2026-03-01' AND order_date < '2026-04-01' GROUP BY order_status` |
| `mart_sales` March 2026 row | `total_revenue = $6,355.21`, `order_count = 30` | `sql-probe` | `kuruma_prod_lake.e2e_question_fix.mart_sales` |
| `src_orders.orders` all-time status distribution | `delivered` 112, `completed` 110, `shipped` 66, `returned` 52 — all 110 `completed` orders are in March 2026 | `sql-probe` | `kuruma_prod_lake.src_orders.orders GROUP BY order_status` |

The shortfall ($29,790.66 − $6,355.21 = $23,435.45) and the missing order count (140 − 30 = 110) match the `completed`-status orders exactly.

#### Root-cause narrative

The commerce platform introduced a new fulfilled status **`completed`** in March 2026. `stg_orders.sql:23` admits only `('shipped', 'delivered', 'returned')`; `completed` is absent, so all 110 March `completed` orders ($23,435.45) are silently dropped by the WHERE filter. `mart_sales` inherits the exclusion, producing the observed undercount.

The `accepted_values` guard on `sources.yml:19-21` was explicitly designed (design.md Ledger 2026-01-14) to surface exactly this scenario as a failing dbt test — the guard would fail the moment `completed` rows appear in the source — but a failing test does not prevent the incorrect aggregation from being materialized. The revenue loss is caused by the IN filter in the staging model, not by the test.

#### Confidence statement

High. The `sql-probe` claims directly quantify the missing revenue and identify the missing status; the alignment is exact ($23,435.45 = the `completed`-row total for March). The only gap is Plane 2 run/test history — no test output or run artifacts are available to confirm the `accepted_values` test fired — but the Plane 3 evidence is self-sufficient for the `code-change` decision.

#### Evidence-completeness gate (for `code-change`)

| Leg | Result |
| --- | --- |
| ≥1 concrete-tagged claim resolving to anchor + window | ✅ `sql-probe` on `src_orders.orders` March 2026 and `mart_sales` March 2026 — exact shortfall quantified |
| Incident class on wave-1 whitelist | ✅ "Failing / missing dbt test" (`accepted_values` guard pins this; the revenue filter is the in-anchor fix) |
| Sandbox verification method named | ✅ Re-run `stg_orders` + `mart_sales` in the sandbox; verify March `order_count = 140` and `total_revenue ≈ 29790.66` |

#### Proposed fix

1. **`models/staging/stg_orders.sql:23`** — add `'completed'` to the IN filter:
   ```sql
   WHERE order_status IN ('shipped', 'delivered', 'returned', 'completed')
   ```
2. **`models/staging/sources.yml:19-21`** — add `'completed'` to `accepted_values`:
   ```yaml
   values: ['shipped', 'delivered', 'returned', 'completed']
   ```

#### Decision

`code-change`
