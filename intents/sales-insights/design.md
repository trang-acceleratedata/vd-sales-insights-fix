# Design: sales-insights monthly revenue mart

artifacts:

- dbt:model.stg_orders
- dbt:model.mart_sales
- dlt:pipeline.orders
- dlt:table.orders

## Architecture

Two-layer dbt project over the dlt-landed bronze table, materialized on Microsoft Fabric (dbt-fabricspark, Livy):

| Layer | Model | Materialization | Purpose |
| --- | --- | --- | --- |
| staging | `stg_orders` | view | Rename/cast the raw feed; admit only revenue-bearing statuses |
| marts | `mart_sales` | table | Monthly `total_revenue` + `order_count` rollup with audit columns |

## Pipeline inventory

| Pipeline | Destination | Tables |
| --- | --- | --- |
| `orders` (dlt) | domain Fabric lakehouse, schema `src_orders` | `orders`, plus dlt audit tables |

## Contracts and tests

- Source declaration on `src_orders.orders` with `not_null`/`unique` on `order_id` and an `accepted_values` guard on `order_status` pinned to the platform's fulfilled-status vocabulary.
- `mart_sales` declares `not_null`/`unique` on `sales_month` and `not_null` on measures and the three audit columns (`_loaded_at`, `_dbt_invocation_id`, `_git_sha`).

## Ledger

| Date | Decision | Rationale |
| --- | --- | --- |
| 2026-01-12 | Intent approved: monthly revenue rollup, statuses `shipped`/`delivered`/`returned` count as fulfilled | Matches the commerce platform's completed-order report at authoring time |
| 2026-01-14 | Design approved: two-layer project, revenue filter lives in `stg_orders`, `accepted_values` guard pins the status vocabulary so an upstream vocabulary change surfaces as a failing test | Guard chosen over silent pass-through |
| 2026-01-15 | Build shipped: `stg_orders` + `mart_sales` materialized to the domain Fabric lakehouse; nightly run scheduled | First production run green |
