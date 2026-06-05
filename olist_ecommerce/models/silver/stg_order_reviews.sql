{{
    config(
        materialized = 'view'
    )
}}

WITH source AS (
    SELECT * 
    FROM {{source('bronze_layer', 'olist_order_reviews')}}
),

valid AS (
    SELECT
        review_id,
        order_id,
        review_score,

        COALESCE(review_comment_title, 'No_comment_title') AS review_comment_title,

        COALESCE(review_comment_message, 'No_comment_message') AS review_comment_message,

        {{clean_timestamp('review_creation_date')}} AS review_creation_at,

        {{clean_timestamp('review_answer_timestamp')}} AS review_answer_at

    FROM source 
    WHERE review_id IS NOT NULL
    AND order_id IS NOT NULL
)

SELECT * FROM valid