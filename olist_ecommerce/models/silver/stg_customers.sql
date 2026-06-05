{{
    config(
        materialized = 'view'
    )
}}


WITH sorce AS (
    SELECT *
    FROM {{source('bronze_layer', 'olist_customers')}}
),
valid AS (
    SELECT 
        customer_id,
        customer_unique_id,
        customer_zip_code_prefix,
        customer_city,
        customer_state,
    FROM sorce
    where customer_id IS NOT NULL
    AND customer_unique_id IS NOT NULL
    )

SELECT * FROM valid
