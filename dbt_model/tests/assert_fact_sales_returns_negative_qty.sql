/*
  Business rule: return lines must carry negative qty (signed returns).
*/
select
    fact_sales_key,
    is_return,
    qty,
    transaction_id
from {{ ref('fact_sales') }}
where is_return = true
  and qty >= 0
