/*
  SCD2 integrity: dim_staff versions for the same staff_id must not overlap
  on half-open [valid_from, valid_to).
*/
select
    a.staff_id,
    a.staff_key as staff_key_a,
    b.staff_key as staff_key_b,
    a.valid_from as valid_from_a,
    a.valid_to as valid_to_a,
    b.valid_from as valid_from_b,
    b.valid_to as valid_to_b
from {{ ref('dim_staff') }} as a
inner join {{ ref('dim_staff') }} as b
    on a.staff_id = b.staff_id
    and a.staff_key < b.staff_key
    and a.valid_from < coalesce(b.valid_to, date '9999-12-31')
    and b.valid_from < coalesce(a.valid_to, date '9999-12-31')
