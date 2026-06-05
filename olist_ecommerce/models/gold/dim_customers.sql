{{
    config(
        materialized = 'table'
    )
}}

WITH source_customers AS (
    SELECT * FROM {{ ref('stg_customers') }}
),

customers_deduped AS (
    SELECT
        customer_unique_id,
        customer_city,
        customer_state,
        ROW_NUMBER() OVER (PARTITION BY customer_unique_id ORDER BY customer_id) AS rn
    FROM source_customers
),

unique_customers AS (
    SELECT 
        customer_unique_id,
        customer_city,
        customer_state
    FROM customers_deduped
    WHERE rn = 1
),
 
orders_agg AS (
    SELECT
        c.customer_unique_id,
        COUNT(o.order_id) AS total_orders
    FROM {{ ref('stg_orders') }} o
    JOIN source_customers c 
    ON o.customer_id = c.customer_id
    GROUP BY c.customer_unique_id
),

final_cte_name AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['c.customer_unique_id']) }} AS customer_pk,
        c.customer_unique_id,
        c.customer_city,
        c.customer_state,
        COALESCE(o.total_orders, 0) AS total_orders,

        CASE
            WHEN COALESCE(o.total_orders, 0) > 10 THEN 'VIP'
            WHEN COALESCE(o.total_orders, 0) BETWEEN 6 AND 10 THEN 'Loyal'
            WHEN COALESCE(o.total_orders, 0) BETWEEN 3 AND 5  THEN 'Regular'
            WHEN COALESCE(o.total_orders, 0) BETWEEN 1 AND 2  THEN 'Casual'
            ELSE 'New'
        END AS customer_segment,   

        CASE 
            WHEN c.customer_state IN ('PR', 'RS', 'SC') THEN 'South'
            WHEN c.customer_state IN ('SP', 'RJ', 'MG', 'ES') THEN 'Southeast'
            WHEN c.customer_state IN ('DF', 'GO', 'MT', 'MS') THEN 'Central-West'
            WHEN c.customer_state IN ('AL', 'BA', 'CE', 'MA', 'PB', 'PE', 'PI', 'RN', 'SE') THEN 'Northeast'
            WHEN c.customer_state IN ('AC', 'AM', 'AP', 'PA', 'RO', 'RR', 'TO') THEN 'North'
            ELSE 'Unknown'
        END AS customer_region

    FROM unique_customers c 
    LEFT JOIN orders_agg o
        ON c.customer_unique_id = o.customer_unique_id
)

select
    -- 1. Keys
    customer_pk,
    customer_unique_id,

    -- 2. Attributes
    customer_city,
    customer_state,
    customer_region,
    customer_segment,

    total_orders

from final_cte_name