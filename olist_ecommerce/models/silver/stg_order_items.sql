{{
    config(
        materialized = 'view'
    )
}}

WITH source AS (
    SELECT *
    FROM {{source('bronze_layer', 'olist_order_items')}}
),

valide AS (
    SELECT
        order_id,
        order_item_id,
        product_id,
        seller_id,
        {{clean_timestamp('shipping_limit_date')}} AS shipping_limit_at,
        price,
        freight_value
    FROM source
    WHERE price >= 0
    AND freight_value >= 0 
    AND order_id IS NOT NULL
    AND order_item_id IS NOT NULL
)

SELECT * FROM valide