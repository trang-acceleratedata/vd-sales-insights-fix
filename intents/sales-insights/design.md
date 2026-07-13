# Design: sales-insights monthly revenue mart

artifacts:

- dbt:model.stg_orders
- dbt:model.mart_sales
- dlt:pipeline.orders
- dlt:table.orders

## Architecture

Two-layer dbt project over the dlt-landed bronze table:

| Layer | Model | Materialization | Purpose |
| --- | --- | --- | --- |
| staging | `stg_orders` | view | Rename/cast the raw feed; admit only revenue-bearing (fulfilled) statuses |
| marts | `mart_sales` | table | Monthly `total_revenue` + `order_count` rollup |

## Pipeline inventory

| Pipeline | Destination | Tables |
| --- | --- | --- |
| `orders` (dlt) | domain Fabric lakehouse, schema `src_orders` | `orders`, plus dlt audit tables |

## Semantic definitions

- **`total_revenue`** — sum of `amount` over fulfilled orders (`shipped`, `delivered`, `returned`) in the month of `order_date`.
- **`amount`** — carried through `stg_orders` and `mart_sales` with a straight `CAST(... AS DECIMAL(12, 2))`; no multiplication, division, or other rescaling is ever applied. The mart's number is the feed's number.

## Contracts and tests

- Source declaration on `src_orders.orders` with `not_null`/`unique` on `order_id`, an `accepted_values` guard on `order_status`, and `not_null` on `amount`.
- `mart_sales` declares `not_null`/`unique` on `sales_month` and `not_null` on the measures and audit columns.
- No unit-conversion logic exists anywhere in this project for `amount`, by design (see Ledger 2026-01-14): the commerce platform's data contract is the sole authority on what unit `amount` is denominated in.

## Ledger

| Date | Decision | Rationale |
| --- | --- | --- |
| 2026-01-12 | Intent approved: monthly revenue rollup; fulfilled statuses count, pending/cancelled excluded | Matches the platform's fulfilled-order report |
| 2026-01-14 | Design approved: revenue filter in `stg_orders`; `amount` is consumed exactly as received, with no unit conversion in the pipeline or the mart, because the commerce platform's contract already guarantees EUR major units | A conversion the mart owned would risk silently absorbing a future contract break instead of surfacing it as a visible anomaly; `accepted_values` guard pins the status vocabulary the same way |
| 2026-01-15 | Build shipped: two-layer project materialized to the domain Fabric lakehouse; nightly run scheduled | First production run green |
