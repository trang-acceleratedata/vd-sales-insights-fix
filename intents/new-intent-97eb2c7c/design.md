# Design: mart_sales low-March-revenue fix

Anchor: `dbt:model.mart_sales` (product: sales-insights monthly revenue mart)
Case branch: `intent/new-intent-97eb2c7c`

## Decision Trail

### Ask

`mart_sales.total_revenue` for March 2026 is well below January and February. The sales team reports March as a record month. Finance cannot reconcile against the commerce platform's completed-order report.

### Evidence pack

**Plane 1 — Code, contracts, definitions**

- `models/staging/stg_orders.sql:22-24` — revenue filter: `WHERE order_status IN ('shipped', 'delivered', 'returned')`. Only three statuses are admitted to the staging layer.
- `models/staging/sources.yml:19-21` — `accepted_values` guard on `src_orders.orders.order_status` pinned to `['shipped', 'delivered', 'returned']`. Designed to surface vocabulary drift as a failing test (design ledger 2026-01-14).
- `intents/sales-insights/intent.md` acceptance criterion 2 — "all fulfilled orders … `shipped`, `delivered`, and `returned` (returns net out upstream, so they stay in revenue)". Vocabulary set at authoring time (Jan 2026).
- `intents/sales-insights/design.md` ledger — design approved 2026-01-14; `accepted_values` guard explicitly chosen so "an upstream vocabulary change surfaces as a failing test".

**Plane 2 — Run/change history**

- `git log --oneline`: two commits only. Baseline commit message: "sales-insights: deployed product with a shipped defect (low March revenue)". No subsequent change to either model file.
- No second revision of `stg_orders.sql` or `sources.yml` between the deploy commit and HEAD — the defect shipped in the original build.

**Plane 3 — Live probes (read-only)**

Domain lakehouse probe — `mart_sales`:
| sales_month | total_revenue | order_count |
|---|---|---|
| 2026-01-01 | 20,220.06 | 100 |
| 2026-02-01 | 23,590.95 | 100 |
| 2026-03-01 | 6,355.21 | **30** |

Domain lakehouse probe — `src_orders.orders` for March 2026, by status:
| order_status | order_count | total_revenue |
|---|---|---|
| completed | **110** | **23,435.45** |
| delivered | 16 | 2,948.21 |
| shipped | 14 | 3,407.00 |

Domain lakehouse probe — `src_orders.orders` for Jan+Feb 2026, by status:
| order_status | order_count | total_revenue |
|---|---|---|
| delivered | 96 | 22,503.35 |
| returned | 52 | 10,565.34 |
| shipped | 52 | 10,742.32 |

Cross-check arithmetic: mart March = 14 (shipped) + 16 (delivered) = 30 orders; $3,407.00 + $2,948.21 = $6,355.21. Exact match — confirms `completed` rows are silently dropped. True March total = 140 orders, $29,790.66.

### Root-cause analysis

**Blast radius:** `mart_sales.total_revenue` and `mart_sales.order_count` for March 2026 are understated by 110 orders / $23,435.45 (mart shows $6,355.21; correct value is $29,790.66). Finance's completed-order reconciliation fails for March. January and February are unaffected — `completed` does not appear in the source for those months.

**Root cause:** The commerce platform introduced `completed` as a new fulfilled-order status beginning in March 2026. The `stg_orders.sql` revenue filter `IN ('shipped', 'delivered', 'returned')` does not include `completed`, so all 110 `completed` orders in March are silently dropped before aggregation in `mart_sales`. [SOURCE: Plane-3 probe; corroborated by Plane-1 filter at `stg_orders.sql:23`]

The `accepted_values` guard in `sources.yml` was designed to catch exactly this drift, but the guard failure either was not run or did not block the nightly dbt refresh in March. [SOURCE: Plane-1 design ledger; Plane-2 — no evidence of a blocking test run]

**Confidence:** High. The symptom maps one-to-one to the dropped status. The arithmetic is exact with no residual. No competing hypotheses remain.

### Evidence-completeness gate (code-change)

- Leg 1 — Symptom reproduced: Live probe confirms 110 `completed` rows in March source; mart total matches only `shipped`+`delivered`. ✓
- Leg 2 — Mechanism identified: `stg_orders.sql:23` IN-list excludes `completed`; unambiguous. ✓
- Leg 3 — Fix is minimal and safe: adding `completed` to the IN-list and its companion `accepted_values` guard is the narrowest change; no joins, grain, or schema change; no models upstream of `stg_orders`. ✓

### Decision

`code-change`

**Proposed change (two files):**

1. `models/staging/stg_orders.sql` line 23 — add `'completed'` to the revenue-status filter:
   ```sql
   -- before
   WHERE order_status IN ('shipped', 'delivered', 'returned')
   -- after
   WHERE order_status IN ('completed', 'shipped', 'delivered', 'returned')
   ```

2. `models/staging/sources.yml` line 20 — add `'completed'` to the `accepted_values` guard so the test re-aligns with the filter and detects future vocabulary additions:
   ```yaml
   # before
   values: ['shipped', 'delivered', 'returned']
   # after
   values: ['completed', 'shipped', 'delivered', 'returned']
   ```

## Gate Ledger

*(Populated by running-remediate-phase after approval)*
