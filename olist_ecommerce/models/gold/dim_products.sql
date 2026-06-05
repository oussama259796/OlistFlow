{{
    config(
        materialized = 'table',
        cluster_by = ['product_category_name_en'] 
    )
}}

with products as (
    select * from {{ ref('stg_products') }}
),

translations as (
    select * from {{ ref('stg_product_category') }}
)

select
    {{dbt_utils.generate_surrogate_key(['product_id'])}} AS product_pk,
    p.product_id,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm,
    
    coalesce(p.product_category_name, 'unknown') as product_category_name_pt,
    
    coalesce(
        t.product_category_name_english, 
        p.product_category_name, 
        'unknown'
    ) as product_category_name_en

from products p
left join translations t 
    on p.product_category_name = t.product_category_name