# Design: fix — low March 2026 revenue in mart_sales

## Decision Trail

### Anchor

`dbt:model.mart_sales` (via `dbt:model.stg_orders`) — `intents/sales-insights`
Time window: March 2026

### Plane 1 — Code & contracts

`models/staging/stg_orders.sql:22-23` filters to `order_status IN ('shipped', 'delivered', 'returned')`.
`models/staging/sources.yml:19-21` guards the same three values via `accepted_values`.
`intents/sales-insights/intent.md:22` names `shipped`, `delivered`, `returned` as fulfilled statuses — matching code at authoring time.

### Plane 2 — Run / change history

`git log --oneline` shows a single initial commit `17bc7ba` with message "deployed product with a shipped defect (low March revenue)" — defect present since first deployment.
No prior dbt prod manifest exists in OneLake (greenfield); sandbox build ran without `--defer --state`.

### Plane 3 — Live data probes

**All statuses in `src_orders.orders`:**

| order_status | orders | revenue (EUR) |
|---|---|---|
| delivered | 112 | 25451.56 |
| completed | 110 | 23435.45 |
| shipped | 66 | 14149.32 |
| returned | 52 | 10565.34 |

**March 2026 raw source:**

| order_status | orders | revenue (EUR) |
|---|---|---|
| completed | 110 | 23435.45 |
| delivered | 16 | 2948.21 |
| shipped | 14 | 3407.00 |

**Domain mart_sales before fix:**

| sales_month | total_revenue | order_count |
|---|---|---|
| 2026-01 | 20220.06 | 100 |
| 2026-02 | 23590.95 | 100 |
| 2026-03 | 6355.21 | 30 |

True March total: EUR 29790.66 / 140 orders. Gap: EUR 23435.45 / 110 `completed` orders silently excluded.

### RCA

**Blast radius:** `mart_sales` is the sole consumer of `stg_orders`. Finance reconciles `total_revenue` against the commerce platform's completed-order report. The discrepancy is EUR 23,435.45 for March 2026 alone.

**Root cause [DIRECT-PROBE]:** The commerce platform introduced `completed` as a fulfilled status in March 2026. `stg_orders.sql` was authored when only `shipped`, `delivered`, `returned` existed. The `WHERE order_status IN ('shipped', 'delivered', 'returned')` predicate silently drops all 110 `completed` March orders before aggregation. No other months are affected because `completed` orders appear only in March.

**Confidence:** High. Raw source has 110 `completed` March rows; mart shows 30 March orders; difference is 110. The filter is the only exclusion point. Gap: no historical run log — but the filter logic is deterministic.

### Decision: `code-change`

**Evidence-completeness gate:**
- Leg 1 — symptom confirmed: March mart shows 30 orders vs 140 in raw source ✅
- Leg 2 — causal code identified: `stg_orders.sql:23` excludes `completed`; no other path ✅
- Leg 3 — sandbox verification: `dbt build --select stg_orders mart_sales --target dev` (Fabric ephemeral, Livy) ✅

**Fix:** Add `'completed'` to the `IN` filter in `stg_orders.sql:23` and to `accepted_values` in `sources.yml:20`.

**Requester approval:** Recorded — user confirmed "Yes, apply the fix".

## Gate Ledger

| Step | Evidence | Result |
|---|---|---|
| Requester approval | User confirmed "Yes, apply the fix" | APPROVED |
| Shortcut provisioning | `fabric_source_shortcuts` — `src_orders.orders` created in ephemeral | PASS |
| Sandbox build | `dbt build --select stg_orders mart_sales --target dev` — exit code 0, PASS=13 WARN=0 ERROR=0 SKIP=0 | GREEN |
| code-reviewer | verdict: approved — "fix correctly adds 'completed' to both the stg_orders filter and accepted_values; lists in sync, LOWER() applied before filter, no downstream change required"; findings: [] | APPROVED |
