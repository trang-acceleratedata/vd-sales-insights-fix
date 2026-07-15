{{ config(materialized='view') }}

WITH

source AS (
  SELECT * FROM {{ source('raw', 'orders') }}
),

renamed AS (
  SELECT
    order_id,
    customer_id,
    CAST(order_date AS DATE)        AS order_date,
    LOWER(order_status)             AS order_status,
    CAST(amount AS DECIMAL(12, 2))  AS amount
  FROM source
),

-- Revenue-bearing orders only: exclude carts and cancellations.
filtered AS (
  SELECT *
  FROM renamed
  WHERE order_status IN ('shipped', 'delivered', 'returned', 'completed')
)

SELECT * FROM filtered
