/*
  SCD2 integrity: dim_product versions for the same product_id must not overlap
  on half-open [valid_from, valid_to).
*/
select
    a.product_id,
    a.product_key as product_key_a,
    b.product_key as product_key_b,
    a.valid_from as valid_from_a,
    a.valid_to as valid_to_a,
    b.valid_from as valid_from_b,
    b.valid_to as valid_to_b
from {{ ref('dim_product') }} as a
inner join {{ ref('dim_product') }} as b
    on a.product_id = b.product_id
    and a.product_key < b.product_key
    and a.valid_from < coalesce(b.valid_to, date '9999-12-31')
    and b.valid_from < coalesce(a.valid_to, date '9999-12-31')
