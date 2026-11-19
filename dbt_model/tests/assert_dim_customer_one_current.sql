/*
  SCD2 integrity: each customer_id has exactly one is_current version.
*/
select
    customer_id,
    sum(case when is_current then 1 else 0 end) as n_current,
    count(*) as n_versions
from {{ ref('dim_customer') }}
group by customer_id
having sum(case when is_current then 1 else 0 end) <> 1
