{% macro clean_timestamp(column_name) %}

    SAFE_CAST({{ column_name }} AS TIMESTAMP)
    
{% endmacro %}