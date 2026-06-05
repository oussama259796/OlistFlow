-- tests/generic/test_positive_value.sql
{% test not_negative(model, column_name) %}
    SELECT *
    FROM {{ model }}
    WHERE {{ column_name }} < 0
{% endtest %}