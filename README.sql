Get all table sizes:

(Followed by query to get _schema_s sizes)

SELECT
  schema_name,
  relname,
  pg_size_pretty(table_size) AS size,
  table_size

FROM (
       SELECT
         pg_catalog.pg_namespace.nspname           AS schema_name,
         relname,
         pg_relation_size(pg_catalog.pg_class.oid) AS table_size

       FROM pg_catalog.pg_class
         JOIN pg_catalog.pg_namespace ON relnamespace = pg_catalog.pg_namespace.oid
     ) t
WHERE schema_name NOT LIKE 'pg_%'
ORDER BY table_size DESC
;
<code>
  
Get schema s sizes

FROM (
       SELECT
         pg_catalog.pg_namespace.nspname                AS schema_name,
         sum(pg_relation_size(pg_catalog.pg_class.oid)) AS schema_size
       FROM pg_catalog.pg_class
         JOIN pg_catalog.pg_namespace ON relnamespace = pg_catalog.pg_namespace.oid
       group by 1
     ) t
WHERE schema_name NOT LIKE 'pg_%'
ORDER BY schema_size DESC;



-- show running queries (pre 9.2)
SELECT procpid, age(clock_timestamp(), query_start), usename, current_query 
FROM pg_stat_activity 
WHERE current_query != '<IDLE>' AND current_query NOT ILIKE '%pg_stat_activity%' 
ORDER BY query_start desc;

-- show running queries (9.2)
SELECT pid, age(clock_timestamp(), query_start), usename, query 
FROM pg_stat_activity 
WHERE query != '<IDLE>' AND query NOT ILIKE '%pg_stat_activity%' 
ORDER BY query_start desc;

-- kill running query
SELECT pg_cancel_backend(procpid);

-- kill idle query
SELECT pg_terminate_backend(procpid);

-- vacuum command
VACUUM (VERBOSE, ANALYZE);

-- all database users
select * from pg_stat_activity where current_query not like '<%';

-- all databases and their sizes
select * from pg_user;

-- all tables and their size, with/without indexes
select datname, pg_size_pretty(pg_database_size(datname))
from pg_database
order by pg_database_size(datname) desc;

-- cache hit rates (should not be less than 0.99)
SELECT sum(heap_blks_read) as heap_read, sum(heap_blks_hit)  as heap_hit, (sum(heap_blks_hit) - sum(heap_blks_read)) / sum(heap_blks_hit) as ratio
FROM pg_statio_user_tables;

-- table index usage rates (should not be less than 0.99)
SELECT relname, 100 * idx_scan / (seq_scan + idx_scan) percent_of_times_index_used, n_live_tup rows_in_table
FROM pg_stat_user_tables 
ORDER BY n_live_tup DESC;

-- how many indexes are in cache
SELECT sum(idx_blks_read) as idx_read, sum(idx_blks_hit)  as idx_hit, (sum(idx_blks_hit) - sum(idx_blks_read)) / sum(idx_blks_hit) as ratio
FROM pg_statio_user_indexes;

-- Dump database on remote host to file
$ pg_dump -U username -h hostname databasename > dump.sql

-- Import dump into existing database
$ psql -d newdb -f dump.sql


Tables and views used by a given view:

with recursive view_tree(parent_schema, parent_obj, child_schema, child_obj, ind, ord) as 
(
  select vtu_parent.view_schema, vtu_parent.view_name, 
    vtu_parent.table_schema, vtu_parent.table_name, 
    '', array[row_number() over (order by view_schema, view_name)]
  from information_schema.view_table_usage vtu_parent
  where vtu_parent.view_schema = '<SCHEMA NAME>' and vtu_parent.view_name = '<VIEW NAME>'
  union all
  select vtu_child.view_schema, vtu_child.view_name, 
    vtu_child.table_schema, vtu_child.table_name, 
    vtu_parent.ind || '  ', 
    vtu_parent.ord || (row_number() over (order by view_schema, view_name))
  from view_tree vtu_parent, information_schema.view_table_usage vtu_child
  where vtu_child.view_schema = vtu_parent.child_schema 
  and vtu_child.view_name = vtu_parent.child_obj
) 
select tree.ind || tree.parent_schema || '.' || tree.parent_obj 
  || ' depends on ' || tree.child_schema || '.' || tree.child_obj txt, tree.ord
from view_tree tree
order by ord;


Possible division by zero when scanning index usage rates, fix:

-- table index usage rates (should not be less than 0.99)
SELECT relname, 
  CASE WHEN (seq_scan + idx_scan) != 0
    THEN 100.0 * idx_scan / (seq_scan + idx_scan) 
    ELSE 0
  END AS percent_of_times_index_used,
  n_live_tup AS rows_in_table
FROM pg_stat_user_tables 
ORDER BY n_live_tup DESC;


Check the size (as in disk space) of all databases:

SELECT d.datname AS Name, pg_catalog.pg_get_userbyid(d.datdba) AS Owner,
  CASE WHEN pg_catalog.has_database_privilege(d.datname, 'CONNECT')
    THEN pg_catalog.pg_size_pretty(pg_catalog.pg_database_size(d.datname)) 
    ELSE 'No Access' 
  END AS SIZE
FROM pg_catalog.pg_database d 
ORDER BY 
  CASE WHEN pg_catalog.has_database_privilege(d.datname, 'CONNECT') 
    THEN pg_catalog.pg_database_size(d.datname)
    ELSE NULL 
  END;

Check the size (as in disk space) of each table:

SELECT nspname || '.' || relname AS "relation",
   pg_size_pretty(pg_total_relation_size(C.oid)) AS "total_size"
 FROM pg_class C
 LEFT JOIN pg_namespace N ON (N.oid = C.relnamespace)
 WHERE nspname NOT IN ('pg_catalog', 'information_schema')
   AND C.relkind <> 'i'
   AND nspname !~ '^pg_toast'
 ORDER BY pg_total_relation_size(C.oid) DESC;
 
 
 
