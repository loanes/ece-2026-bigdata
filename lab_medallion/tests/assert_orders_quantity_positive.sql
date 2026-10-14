-- An order must have a strictly positive quantity: the test fails if this query returns rows
select
    order_id,
    quantity
from {{ ref('stg_orders') }}
where quantity <= 0 or quantity is null
