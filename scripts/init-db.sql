-- Keycloak Database Initialization Script
-- This script sets up the initial database configuration for Keycloak

-- Create additional database schemas if needed
-- CREATE SCHEMA IF NOT EXISTS keycloak_audit;

-- Set up database extensions if needed
-- CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create additional users for different environments
-- Development user
-- CREATE USER keycloak_dev WITH PASSWORD 'keycloak_dev_password';
-- GRANT CONNECT ON DATABASE keycloak_db TO keycloak_dev;

-- Read-only user for monitoring/reporting
-- CREATE USER keycloak_readonly WITH PASSWORD 'keycloak_readonly_password';
-- GRANT CONNECT ON DATABASE keycloak_db TO keycloak_readonly;

-- Set default transaction isolation level
-- ALTER DATABASE keycloak_db SET default_transaction_isolation = 'read committed';

-- Configure connection limits
-- ALTER DATABASE keycloak_db SET max_connections = 100;

-- Set timezone
-- ALTER DATABASE keycloak_db SET timezone = 'UTC';

-- Create indexes for better performance (these will be created by Keycloak automatically)
-- But we can prepare the database for optimal performance

-- Set up database parameters for optimal Keycloak performance
-- ALTER DATABASE keycloak_db SET shared_preload_libraries = 'pg_stat_statements';
-- ALTER DATABASE keycloak_db SET log_statement = 'mod';
-- ALTER DATABASE keycloak_db SET log_min_duration_statement = 1000;

-- Log completion
SELECT 'Keycloak database initialization completed' AS status;