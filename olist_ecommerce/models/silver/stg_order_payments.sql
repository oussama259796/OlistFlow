{{
    config(
        materialized = 'view'
    )
}}

WITH sorce AS (
    SELECT * 
    FROM {{source('bronze_layer', 'olist_order_payments')}}
),

valid AS (
    SELECT
        order_id,
        payment_sequential,
        payment_type,
        payment_installments,
        payment_value
    FROM sorce
    where order_id IS NOT NULL
    AND payment_value  >= 0
    AND payment_installments >= 1
)

SELECT * FROM valid