{{
    config(
        materialized = 'table'
    )
}}

with orders as (
    select * from {{ ref('stg_orders') }}
),

order_items as (
    select * from {{ ref('stg_order_items') }}
),

customers as (
    select customer_id, customer_unique_id from {{ ref('stg_customers') }}
),

payments_aggregated as (
    select
        order_id,
        count(payment_sequential) as payment_methods_count,
        sum(payment_value) as total_order_payment_value
    from {{ ref('stg_order_payments') }}
    group by 1
)

select
    -- 1. المفاتيح الأساسية والخارجية (Surrogate Keys الموحدة)
    {{ dbt_utils.generate_surrogate_key(['oi.order_id', 'oi.order_item_id']) }} as order_item_pk,
    {{ dbt_utils.generate_surrogate_key(['c.customer_unique_id']) }} as customer_pk, -- تم التصحيح هنا ليتوافق مع dim_customers
    {{ dbt_utils.generate_surrogate_key(['oi.product_id']) }} as product_pk,
    
    -- 2. عمود التقسيم (Partition Key)
    cast(o.order_purchase_at as date) as order_purchase_date,

    -- 3. الأبعاد والمتغيرات التشغيلية
    o.order_id,
    oi.order_item_id,
    o.order_status,
    oi.seller_id,

    -- 4. التواريخ
    o.order_purchase_at,
    o.order_approved_at,
    o.order_delivered_carrier_at,
    o.order_delivered_customer_at,
    o.order_estimated_delivery_at,
    oi.shipping_limit_at,

    -- 5. المقاييس المالية
    oi.price as item_price,
    oi.freight_value as item_freight_value,
    (oi.price + oi.freight_value) as total_item_cost,

    -- 6. مقاييس الدفع المجمعة
    coalesce(p.total_order_payment_value, 0) as total_order_payment_value,
    coalesce(p.payment_methods_count, 0) as payment_methods_count,

    -- 7. مؤشرات أداء الشحن (SLA Metrics)
    datetime_diff(o.order_delivered_customer_at, o.order_purchase_at, day) as actual_delivery_days,
    datetime_diff(o.order_estimated_delivery_at, o.order_purchase_at, day) as estimated_delivery_days,
    
    case 
        when o.order_delivered_customer_at > o.order_estimated_delivery_at then 1
        else 0
    end as is_delivery_delayed

from order_items oi
inner join orders o 
    on oi.order_id = o.order_id
inner join customers c
    on o.customer_id = c.customer_id 
left join payments_aggregated p 
    on o.order_id = p.order_id