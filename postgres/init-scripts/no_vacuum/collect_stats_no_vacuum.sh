#!/bin/bash

PGHOST="no-vacuum-db"
PGPORT=5432
PGDATABASE="playground_database"
PGUSER="postgres"
PGPASSWORD="abcd1234"
OUTPUT_FILE="no_vacuum_db_stats.txt"

export PGPASSWORD=$PGPASSWORD

echo "Collecting stats from $PGHOST into $OUTPUT_FILE"

echo "Dead Tuple Statistics for $PGHOST:" > $OUTPUT_FILE
psql -h $PGHOST -p $PGPORT -U $PGUSER -d $PGDATABASE -c "
SELECT
    schemaname,
    relname,
    n_dead_tup,
    n_live_tup,
    ROUND(n_dead_tup::numeric / NULLIF(n_live_tup + n_dead_tup, 0) * 100, 2) as dead_tuple_pct,
    last_vacuum,
    last_autovacuum,
    autovacuum_count
FROM pg_stat_user_tables
WHERE n_dead_tup > 0
ORDER BY n_dead_tup DESC;
" >> $OUTPUT_FILE

echo -e "\nTable Sizes for $PGHOST:" >> $OUTPUT_FILE
psql -h $PGHOST -p $PGPORT -U $PGUSER -d $PGDATABASE -c "
SELECT
    schemaname,
    relname,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||relname)) as total_size,
    pg_size_pretty(pg_relation_size(schemaname||'.'||relname)) as table_size
FROM pg_stat_user_tables
ORDER BY pg_total_relation_size(schemaname||'.'||relname) DESC;
" >> $OUTPUT_FILE

echo -e "\nDatabase Statistics for $PGHOST:" >> $OUTPUT_FILE
psql -h $PGHOST -p $PGPORT -U $PGUSER -d $PGDATABASE -c "
SELECT
    datname,
    numbackends,
    xact_commit,
    xact_rollback,
    blks_read,
    blks_hit,
    temp_files,
    temp_bytes,
    deadlocks
FROM pg_stat_database
WHERE datname = '$PGDATABASE';
" >> $OUTPUT_FILE

echo "Stats for $PGHOST saved in $OUTPUT_FILE"

#Calculate aggregated dead tuple stats 
AGG_QUERY="
SELECT
    SUM(n_dead_tup) AS total_dead,
    SUM(n_live_tup) AS total_live,
    ROUND(SUM(n_dead_tup)::numeric / NULLIF(SUM(n_dead_tup) + SUM(n_live_tup), 0) * 100, 2) AS avg_dead_pct
FROM pg_stat_user_tables
WHERE n_dead_tup > 0;
"

AGG_RESULT=$(psql -h $PGHOST -p $PGPORT -U $PGUSER -d $PGDATABASE -tA -c "$AGG_QUERY")
IFS="|" read -r total_dead total_live avg_dead_pct <<< "$AGG_RESULT"

LOGFILE="no_vacuum_test_results.csv"
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

echo "$TIMESTAMP,DEAD_TUPLES_TOTAL,$total_dead" >> $LOGFILE
echo "$TIMESTAMP,DEAD_TUPLES_AVG_PCT,$avg_dead_pct" >> $LOGFILE

echo "Appended summary to $LOGFILE"
