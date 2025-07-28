#!/usr/bin/env bash
set -e

psql -v ON_ERROR_STOP=1 --host "127.0.0.1" --username "$POSTGRES_USER" --dbname "$POSTGRES_DB"  <<-EOSQL

  ALTER SYSTEM SET autovacuum = off;
  ALTER SYSTEM SET track_counts = off;
  ALTER SYSTEM SET autovacuum_max_workers = 2;
  SELECT pg_reload_conf();

  -- Initialize database for HammerDB testing
  CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
  ALTER SYSTEM SET shared_preload_libraries = 'pg_stat_statements';

  -- Create additional monitoring views
  CREATE OR REPLACE VIEW vacuum_stats AS
  SELECT
      schemaname,
      relname,
      n_tup_ins,
      n_tup_upd,
      n_tup_del,
      n_dead_tup,
      last_vacuum,
      last_autovacuum,
      vacuum_count,
      autovacuum_count
  FROM pg_stat_user_tables
  ORDER BY n_dead_tup DESC;

EOSQL
