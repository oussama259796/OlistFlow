{{
    config(
        materialized = 'view'
    )
}}

WITH source AS (
    SELECT *
    FROM {{ source('bronze_layer', 'olist_sellers') }}
),

valid AS (
    SELECT
        TRIM(seller_id) AS seller_id,
        
        seller_zip_code_prefix,
        
        LOWER(TRIM(seller_city)) AS seller_city,
        UPPER(TRIM(seller_state)) AS seller_state
    FROM source
    WHERE seller_id IS NOT NULL
)

SELECT * FROM valid