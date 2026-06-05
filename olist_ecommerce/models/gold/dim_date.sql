{{
    config(
        materialized = 'table'
    )
}}


{{ dbt_date.get_date_dimension("2016-01-01", "2026-12-31") }}