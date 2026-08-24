select * from {{ source('mysql_oltp', 'staff') }}
