# Intent: sales-insights monthly revenue mart

artifacts:

- dbt:model.stg_orders
- dbt:model.mart_sales
- dlt:pipeline.orders
- dlt:table.orders

## Business context

Finance needs a monthly revenue rollup from the commerce platform's order feed, reconciled against the platform's own fulfilled-order report.

## Source

The `orders` dlt pipeline lands the commerce platform's order feed into the domain Fabric lakehouse at `src_orders.orders`, one row per order, refreshed nightly. The lifecycle carries five statuses: `pending`, `shipped`, `delivered`, `returned`, `cancelled`. Per the platform's data contract for this feed, `amount` is the order's value in EUR **major units** — e.g. `42.50` means forty-two euros fifty cents — never sub-unit (cents).

## Acceptance criteria

1. `mart_sales` carries one row per calendar month with `total_revenue` and `order_count`.
2. `total_revenue` counts **fulfilled orders only** — statuses `shipped`, `delivered`, and `returned`. **Pending and cancelled orders are excluded from revenue.**
3. `amount` is consumed exactly as received from the feed: the platform's contract guarantees EUR major units, so the pipeline and the mart perform no scaling or unit conversion of their own.
4. Monthly totals must reconcile with the commerce platform's fulfilled-order report within rounding.

## Non-goals

- No per-customer or per-product breakdown in this intent.
- No currency conversion: the feed is single-currency EUR, and the mart trusts the platform's declared unit contract for `amount` rather than re-deriving or normalizing it.
