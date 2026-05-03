-- init-hive-db.sql
-- Runs automatically when the postgres container starts for the first time.
-- Creates the two databases needed by the lab stack.
-- The 'hive' user is already created by POSTGRES_USER in .env.

-- Hive Metastore database (schematool will populate the schema)
-- CREATE DATABASE metastore;  <--- COMMENT THIS OUT OR DELETE IT

-- Hue web UI database (Hue's syncdb / migrate will populate the schema)
-- contents of init-hive-db.sql
CREATE USER hive WITH PASSWORD 'hive';
CREATE DATABASE hive;
GRANT ALL PRIVILEGES ON DATABASE hive TO hive;
CREATE DATABASE hue;

-- Grant full privileges to the lab user on both databases
GRANT ALL PRIVILEGES ON DATABASE metastore TO hive;
GRANT ALL PRIVILEGES ON DATABASE hue TO hive;