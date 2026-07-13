-- Singular test: flags any calendar month whose average fulfilled-order
-- amount jumps sharply against the trailing months. mart_sales carries one
-- row per calendar month, so this recomputes directly from the mart's own
-- output — a plane-1 check, not a live probe of an external system.
--
-- A non-empty result fails the test (dbt convention for singular tests).
WITH monthly AS (
  SELECT
    sales_month,
    total_revenue / NULLIF(order_count, 0) AS avg_order_amount
  FROM {{ ref('mart_sales') }}
),

with_trailing AS (
  SELECT
    sales_month,
    avg_order_amount,
    AVG(avg_order_amount) OVER (
      ORDER BY sales_month
      ROWS BETWEEN 2 PRECEDING AND 1 PRECEDING
    ) AS trailing_avg_order_amount
  FROM monthly
)

SELECT
  sales_month,
  avg_order_amount,
  trailing_avg_order_amount
FROM with_trailing
WHERE trailing_avg_order_amount IS NOT NULL
  AND avg_order_amount > trailing_avg_order_amount * 10
