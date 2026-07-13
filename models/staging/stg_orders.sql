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

-- Revenue-bearing orders only: exclude non-fulfilled statuses.
-- Denylist approach ensures new fulfilled statuses from the platform are not silently dropped.
filtered AS (
  SELECT *
  FROM renamed
  WHERE order_status NOT IN ('pending', 'cart', 'cancelled')
)

SELECT * FROM filtered
