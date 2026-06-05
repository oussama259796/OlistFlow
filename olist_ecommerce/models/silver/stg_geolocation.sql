{{
    config(
        materialized = 'view'
    )
}}

WITH source AS (
    SELECT *
    FROM {{source('bronze_layer', 'olist_geolocation')}}
),

valide AS (
    SELECT 
        geolocation_zip_code_prefix,

        SAFE_CAST(geolocation_lat AS NUMERIC) AS geolocation_lat,
        SAFE_CAST(geolocation_lng AS NUMERIC) AS geolocation_lng,
        geolocation_city,
        geolocation_state
    FROM source
    WHERE geolocation_zip_code_prefix IS NOT NULL
)

SELECT * FROM valide