select * from {{ source('mysql_oltp', 'store') }}
