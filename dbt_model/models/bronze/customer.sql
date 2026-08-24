select * from {{ source('mysql_oltp', 'customer') }}
