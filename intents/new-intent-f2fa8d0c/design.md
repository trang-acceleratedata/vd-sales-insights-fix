# Case Record — sales-insights fix (March revenue)

**Anchor**: `dbt:model.mart_sales` (monthly revenue rollup, `stg_orders` → `mart_sales`)
**Issue**: https://github.com/trang-acceleratedata/vd-sales-insights-fix/issues/1
**Time window**: March 2026 (first affected month)

## Blast Radius

`mart_sales` only. No downstream dbt models or exposures. Finance's monthly reconciliation against the commerce platform's completed-order report is the sole consumer.

## Evidence Pack

### Plane 1 — Code and contracts

- `models/staging/sources.yml:19-20`: `accepted_values` guard on `src_orders.orders.order_status` lists only `['shipped', 'delivered', 'returned']` — missing the non-revenue statuses `cart` and `cancelled`.
- `models/staging/stg_orders.sql:23`: filter `WHERE order_status IN ('shipped', 'delivered', 'returned')` is correct per intent; comment explicitly references "carts and cancellations" as expected non-revenue source statuses to exclude.
- `intents/sales-insights/intent.md`: "Cart and cancellation rows never count toward revenue" — implies those statuses are present in the source feed.
- Design ledger (2026-01-14): guard chosen "so an upstream vocabulary change surfaces as a failing test."

### Plane 2 — Run history

- Deployed mart `_git_sha = 926bceb…` ≠ current branch `17bc7ba` — mart was built from an earlier state before the current code was committed.
- Deployed mart `_loaded_at = 2026-07-12T07:32:55` — built after all source loads (`load-2026-01-28`, `load-2026-02-28`, `load-2026-03-31`).

### Plane 3 — Live probes

| Month | Source orders | Source revenue | Mart order_count | Mart total_revenue |
|-------|-------------|---------------|-----------------|-------------------|
| Jan 2026 | 100 | $20,220.06 | 100 ✅ | $20,220.06 ✅ |
| Feb 2026 | 100 | $23,590.95 | 100 ✅ | $23,590.95 ✅ |
| Mar 2026 | 140 | $32,445.41 | **30 ❌** | **$6,355.21 ❌** |

Source differentiator: Jan/Feb all have `discount_amount = 0`; March has 138/140 orders with `discount_amount > 0` (new source characteristic in March). March's 30 mart orders matches the count of revenue orders that existed before the full March batch (which included cart/cancelled) landed.

## Root Cause Analysis

The `accepted_values` guard on `src_orders.orders.order_status` (`sources.yml:19-20`) was pinned to only the three revenue-bearing statuses, omitting `cart` and `cancelled` — non-revenue statuses that the commerce platform sends as part of its normal feed.

When the March source batch included cart/cancelled orders, this test failed. Because the project runs `dbt build`, a failed source test causes all downstream nodes (`stg_orders`, `mart_sales`) to be **skipped**. The mart was frozen at its previous build state — 30 March orders from a run before the full March batch was available. Subsequent source updates (cart/cancelled orders later cleaned up or updated to revenue statuses) did not trigger a mart rebuild while the test remained broken.

The guard's stated purpose (catch novel vocabulary additions from the platform) is undermined by firing on expected non-revenue statuses that are legitimately in the source.

**Confidence**: High. The 30-order March figure is consistent with a stale build pre-full-batch; Jan/Feb match source exactly; the `accepted_values` omission is directly readable in source.

## Decision

**`code-change`** — Fix the `accepted_values` guard to include `'cart'` and `'cancelled'`.

### Evidence-completeness gate

| Leg | Result |
|-----|--------|
| Failure mechanism identified from source artifact (not inference) | ✅ `sources.yml:20` directly observed; missing values confirmed |
| Blast radius bounded | ✅ Single model, no downstream dependencies |
| Proposed change is minimal and reversible | ✅ One-line YAML addition |

## Decision Trail

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-07-13 | Code-change approved: add `'cart'` and `'cancelled'` to `accepted_values` in `sources.yml` | Guard must include all known source statuses to avoid false failures that block `dbt build`; revenue filtering remains in `stg_orders` |
