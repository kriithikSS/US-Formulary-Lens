-- Run once by docker-entrypoint-initdb.d on first container start
-- Creates the application role and sets search_path

CREATE ROLE flens LOGIN PASSWORD 'changeme';
ALTER DATABASE formulary_lens OWNER TO flens;
GRANT ALL PRIVILEGES ON DATABASE formulary_lens TO flens;

-- Extensions
CREATE EXTENSION IF NOT EXISTS pg_trgm;    -- fuzzy name matching for drug joins
CREATE EXTENSION IF NOT EXISTS btree_gin;  -- GIN indexes on composite keys

-- Schema will be built by the ETL schema migration (sql/schema.sql)
