/*
  Loyalty sales must resolve a customer VERSION key.
  Relationships(customer_key) ignore nulls, so this catches a broken SCD2 window
  (e.g. earliest valid_from after the sale date).
*/
select
    fact_sales_key,
    transaction_id,
    date_key,
    channel
from {{ ref('fact_sales') }}
where customer_id is not null
  and customer_key is null
