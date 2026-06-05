{{
    config(
        materialized = 'view'
    )
}}

WITH source AS (
    SELECT *
    FROM {{source('bronze_layer', 'product_category_name')}}
),
valid AS (
    SELECT
        TRIM(string_field_0) AS product_category_name,
        TRIM(string_field_1) AS product_category_name_english
	FROM source
    WHERE string_field_0 IS NOT NULL 
    AND string_field_1 IS NOT NULL
)
SELECT * FROM valid