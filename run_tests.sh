#!/bin/bash
set -e

echo "Starting HammerDB Vacuum Impact Testing..."

# Start services
docker-compose up -d
echo "Waiting for services to be ready..."
#sleep 30

# Run the HammerDB test
echo "Executing HammerDB vacuum comparison test..."
docker-compose exec hammerdb ./hammerdbcli auto /home/HammerDB-5.0/scripts/vacuum_test.tcl

# Collect statistics from both databases
echo "Collecting statistics from vacuum-enabled database..."
# export superuser to hammerdb container
#docker-compose run -e PGSUPERUSERPASS="abcd1234" -e PGSUPERUSER="vacuum_superuser" hammerdb
docker-compose exec vacuum-db psql -U postgres -d playground_database -f /docker-entrypoint-initdb.d/monitor.sql > hammerdb/test-results/vacuum_enabled_stats.txt
#docker-compose exec vacuum-db psql -U vacuum_user -d playground_database -f hammerdb/scripts/monitor.sql > hammerdb/test-results/vacuum_enabled_stats.txt

echo "Collecting statistics from no-vacuum database..."
# export superuser to hammerdb container
#docker-compose run -e PGSUPERUSERPASS="abcd1234" -e PGSUPERUSER="no_vacuum_superuser" hammerdb
docker-compose exec no-vacuum-db psql -U postgres -d playground_database -f /docker-entrypoint-initdb.d/monitor.sql > hammerdb/test-results/no_vacuum_stats.txt
#docker-compose exec no-vacuum-db psql -U postgres -d playground_database -f hammerdb/scripts/monitor.sql > hammerdb/test-results/no_vacuum_stats.txt

echo "Testing complete! Check the results directory for detailed statistics."
echo "You can also access:"
echo "- Vacuum DB metrics: http://localhost:9187/metrics"
echo "- No-vacuum DB metrics: http://localhost:9188/metrics"