#!/usr/bin/tclsh

proc test_database {db_host db_port user_name superuser_username test_name {warehouse_count 2} {test_duration 1}} {
    dbset db pg
    dbset bm TPC-C

# These are the Internal Variables: DB Name, Passwords, Number of Virtual Users

    set db_name "playground_database"    
    set password "abcd1234"
    set superuser_password "abcd1234"
    set vu_count 3

    puts "Starting test: $test_name"
    puts "Database: $db_host:$db_port/$db_name"

# Input Validation: Checks if required parameters are provided and ensures a valid Port Range.

    if {$db_host eq "" || $db_port eq "" || $user_name eq "" || $superuser_username eq ""} {
        puts "Error: Missing required parameters"
        return -1
    }

    if {$db_port < 1 || $db_port > 65535} {
        puts "Error: Invalid port number: $db_port"
        return -1
    }

    # Clean up Previously virtual users
    catch {vudestroy}

# PHASE 1: Schema build using superuser: Connects to target DB Host, Sets Warehouse and VU Count

    puts "Configuring superuser connection for schema creation..."
    diset connection pg_host $db_host

    diset tpcc pg_count_ware $warehouse_count
    diset tpcc pg_num_vu $warehouse_count
    diset tpcc pg_user $superuser_username
    diset tpcc pg_pass $superuser_password
    diset tpcc pg_superuser $superuser_username
    diset tpcc pg_superuserpass $superuser_password
    diset tpcc pg_dbase $db_name

    puts "Building TPC-C schema..."
    if {[catch {buildschema} result]} {
        puts "Schema build failed: $result"
        catch {vudestroy}
        return -1
    }

# PHASE 2: Configure TPC-C test for regular user

    puts "Switching to regular user connection for testing..."

    diset tpcc pg_user $user_name
    diset tpcc pg_pass $password

# Set test mode to TIMED

    diset tpcc pg_driver timed
    diset tpcc pg_rampup 1
    diset tpcc pg_duration $test_duration
    diset tpcc pg_allwarehouse false
    diset tpcc pg_timeprofile true

# Configure virtual users and Execution

    catch {vudestroy}
    vuset logtotemp 1
    vuset unique 1
    vuset showoutput 1
    vuset vu $vu_count

    if {[catch {loadscript} result]} {
        puts "Script loading failed: $result"
        return -1
    }

    puts "Creating virtual users..."
    if {[catch {vucreate} result]} {
        puts "Virtual user creation failed: $result"
        return -1
    }

    puts "Running initial performance test..."
    if {[catch {vurun} result]} {
        puts "Initial test run failed: $result"
        catch {vudestroy}
        return -1
    }

# Generate load for dead tuples and waits 20 Seconds after each Load Iteration

    puts "Creating workload to generate dead tuples..."
    set load_iterations 1
    for {set i 0} {$i < $load_iterations} {incr i} {
        puts "Running load iteration [expr $i + 1] of $load_iterations..."
        if {[catch {vurun} result]} {
            puts "Load iteration $i failed: $result"
        }
        after 20000 ;# Wait 20s
    }

# Final Performance Test - Runs one more test to assess performance after dead tuple generation

    puts "Running final performance test..."
    if {[catch {vurun} result]} {
        puts "Final test run failed: $result"
    }

# Cleans up all VUs

    puts "Cleaning up virtual users..."
    catch {vudestroy}

    puts "Test completed: $test_name"
    puts "Configuration summary:"
    puts "  - Warehouses: $warehouse_count"
    puts "  - Virtual Users: $vu_count"
    puts "  - Test Duration: ${test_duration}m"
    puts "  - Load Iterations: $load_iterations"

    return 0
}

# Test both databases
puts "=== Starting Vacuum Impact Testing ==="

# Run test on vacuum-enabled database
test_database "vacuum-db" "5432" "postgres" "postgres" "WITH_VACUUM"

# Run test on vacuum-disabled database
test_database "no-vacuum-db" "5432" "postgres" "postgres" "WITHOUT_VACUUM"

puts "=== Testing Complete ==="
puts "Compare the results from both databases to see vacuum impact"