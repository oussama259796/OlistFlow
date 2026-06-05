{{
    config(
        materialized = 'view'
    )
}}

WITH source AS (
    SELECT *
    FROM {{source('bronze_layer', 'olist_products')}}
),

valid AS(
    SELECT
        TRIM(product_id) AS product_id,
        TRIM(product_category_name) AS product_category_name,
        product_name_lenght	,
        product_description_lenght,	
        product_photos_qty,
        product_weight_g,
        product_length_cm,
        product_height_cm,	
        product_width_cm,
    FROM source 
    WHERE product_id IS NOT NULL
)
SELECT * FROM valid