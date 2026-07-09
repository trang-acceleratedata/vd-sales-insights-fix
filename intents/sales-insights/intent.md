# Intent: sales-insights monthly revenue mart

artifacts:

- dbt:model.stg_orders
- dbt:model.mart_sales
- dlt:pipeline.orders
- dlt:table.orders

## Business context

Finance needs a monthly revenue rollup from the commerce platform's order feed. The number they reconcile against is the platform's own "completed orders" total, so the mart must count every order that reached a fulfilled state.

## Source

The `orders` dlt pipeline lands the commerce platform's order feed into the domain Fabric lakehouse at `src_orders.orders`, one row per order, refreshed nightly.

## Acceptance criteria

1. `mart_sales` carries one row per calendar month with `total_revenue` and `order_count`.
2. `total_revenue` counts **all fulfilled orders** — at authoring time the platform's fulfilled statuses are `shipped`, `delivered`, and `returned` (returns net out upstream, so they stay in revenue).
3. Cart and cancellation rows never count toward revenue.
4. Monthly totals must reconcile with the commerce platform's completed-order report within rounding.

## Non-goals

- No per-product or per-customer breakdowns in this intent.
- No currency conversion; the feed is single-currency EUR.
