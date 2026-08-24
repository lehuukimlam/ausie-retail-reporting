select * from {{ source('mysql_oltp', 'product') }}
