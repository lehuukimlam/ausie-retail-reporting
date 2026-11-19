/*
  SCD2 integrity: dim_customer versions for the same customer_id must not overlap
  on half-open [valid_from, valid_to).
*/
select
    a.customer_id,
    a.customer_key as customer_key_a,
    b.customer_key as customer_key_b,
    a.valid_from as valid_from_a,
    a.valid_to as valid_to_a,
    b.valid_from as valid_from_b,
    b.valid_to as valid_to_b
from {{ ref('dim_customer') }} as a
inner join {{ ref('dim_customer') }} as b
    on a.customer_id = b.customer_id
    and a.customer_key < b.customer_key
    and a.valid_from < coalesce(b.valid_to, date '9999-12-31')
    and b.valid_from < coalesce(a.valid_to, date '9999-12-31')
