{% snapshot snapshot_customer %}

{{
  config(
    target_schema='snapshots',
    unique_key='customer_id',
    strategy='check',
    check_cols=[
      'customer_number',
      'first_name',
      'last_name',
      'email',
      'email_raw',
      'phone',
      'address_line_1',
      'address_line_2',
      'suburb',
      'state_text',
      'state_code',
      'postcode_text',
      'country_code'
    ],
    invalidate_hard_deletes=True
  )
}}

/*
  SNAPSHOT: snapshot_customer
  ----------
  Purpose: Warehouse SCD2 history for CRM customers (Type-1 in OLTP).
  Source: cleaned silver_customer (preferred over bronze/raw).
  Strategy: check — new version when any listed attribute changes.
  Unique key: customer_id (durable person id across versions).
  Note: dim_customer / fact_sales still Type-1 in this slice; snapshot only.
*/
select
    customer_id,
    customer_number,
    first_name,
    last_name,
    email_raw,
    email,
    phone,
    address_line_1,
    address_line_2,
    suburb,
    state_text,
    state_code,
    postcode_text,
    country_code,
    created_at,
    updated_at
from {{ ref('silver_customer') }}

{% endsnapshot %}
