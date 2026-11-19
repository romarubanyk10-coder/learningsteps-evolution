-- One-time database bootstrap, run by k8s-manifests/bootstrap/db-bootstrap-job.yaml.
-- Runs as the admin user. Safe to run more than once.

-- 1. Application role: can log in, owns nothing.
SELECT 'CREATE ROLE learningsteps_app LOGIN'
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'learningsteps_app')\gexec
ALTER ROLE learningsteps_app WITH LOGIN PASSWORD :'app_password';

-- 2. Schema (same as database_setup.sql). Owned by the admin, not by the app.
CREATE TABLE IF NOT EXISTS entries (
    id VARCHAR PRIMARY KEY,
    data JSONB NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_entries_created_at ON entries(created_at);
CREATE INDEX IF NOT EXISTS idx_entries_data_gin ON entries USING GIN (data);

-- 3. Least privilege: read and write rows in one table. No CREATE, DROP or ALTER.
GRANT CONNECT ON DATABASE learning_journal TO learningsteps_app;
GRANT USAGE ON SCHEMA public TO learningsteps_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE entries TO learningsteps_app;

-- 4. Show the result.
\dt entries
\dp entries
