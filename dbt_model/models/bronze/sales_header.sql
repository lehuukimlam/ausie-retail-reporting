select * from {{ source('mysql_oltp', 'sales_header') }}
