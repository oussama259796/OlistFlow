{{
    config(
        materialized = 'view'
    )
}}

WITH sorce AS(
    SELECT * 
    FROM {{source('bronze_layer', 'olist_orders')}}
),

valid AS(
    SELECT
        TRIM(order_id)AS order_id,
        TRIM(customer_id) AS customer_id,
        UPPER(order_status) AS order_status ,
    
        {{clean_timestamp('order_purchase_timestamp')}} AS order_purchase_at,
        {{clean_timestamp('order_approved_at')}} AS order_approved_at,
        {{clean_timestamp('order_delivered_carrier_date')}} AS order_delivered_carrier_at,
        {{clean_timestamp('order_delivered_customer_date')}} AS order_delivered_customer_at,
        {{clean_timestamp('order_estimated_delivery_date')}} AS order_estimated_delivery_at
    FROM sorce
    WHERE order_id IS NOT NULL 
    AND customer_id IS NOT NULL
)
SELECT * FROM valid


