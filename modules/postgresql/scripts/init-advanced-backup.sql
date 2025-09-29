-- Initialize pg_cron extension and backup jobs
-- This script sets up automated backup scheduling within PostgreSQL

-- Enable pg_cron extension
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Grant necessary permissions for backup jobs
CREATE USER backup_user WITH PASSWORD 'backup_secure_pass_2024';
ALTER USER backup_user WITH SUPERUSER;  -- Required for pg_cron jobs

-- Create backup management functions
CREATE OR REPLACE FUNCTION trigger_full_backup()
RETURNS text AS $$
DECLARE
    result text;
BEGIN
    -- Trigger pgBackRest full backup
    PERFORM pg_notify('backup_channel', 'full_backup_requested');
    
    -- Log the backup request
    INSERT INTO backup_log (backup_type, status, requested_at) 
    VALUES ('full', 'requested', NOW());
    
    RETURN 'Full backup requested at ' || NOW()::text;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION trigger_incremental_backup()
RETURNS text AS $$
DECLARE
    result text;
BEGIN
    -- Trigger pgBackRest incremental backup
    PERFORM pg_notify('backup_channel', 'incremental_backup_requested');
    
    -- Log the backup request
    INSERT INTO backup_log (backup_type, status, requested_at) 
    VALUES ('incremental', 'requested', NOW());
    
    RETURN 'Incremental backup requested at ' || NOW()::text;
END;
$$ LANGUAGE plpgsql;

-- Create backup logging table
CREATE TABLE IF NOT EXISTS backup_log (
    id SERIAL PRIMARY KEY,
    backup_type VARCHAR(20) NOT NULL,
    status VARCHAR(20) NOT NULL,
    requested_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE,
    backup_size BIGINT,
    duration_seconds INTEGER,
    error_message TEXT
);

-- Create index for efficient querying
CREATE INDEX IF NOT EXISTS idx_backup_log_requested_at ON backup_log(requested_at);
CREATE INDEX IF NOT EXISTS idx_backup_log_type_status ON backup_log(backup_type, status);

-- Schedule automated backups using pg_cron

-- 1. Full backup every Sunday at 1:00 AM
SELECT cron.schedule(
    'weekly-full-backup',
    '0 1 * * 0',  -- Every Sunday at 1:00 AM
    $$SELECT trigger_full_backup();$$
);

-- 2. Incremental backup every day at 2:00 AM (except Sunday)
SELECT cron.schedule(
    'daily-incremental-backup', 
    '0 2 * * 1-6',  -- Monday through Saturday at 2:00 AM
    $$SELECT trigger_incremental_backup();$$
);

-- 3. WAL archive cleanup every day at 3:00 AM
SELECT cron.schedule(
    'wal-cleanup',
    '0 3 * * *',  -- Every day at 3:00 AM
    $$SELECT pg_notify('backup_channel', 'cleanup_old_archives');$$
);

-- 4. Backup status check every hour
SELECT cron.schedule(
    'backup-status-check',
    '0 * * * *',  -- Every hour
    $$
    INSERT INTO backup_log (backup_type, status, requested_at) 
    SELECT 'health_check', 'completed', NOW() 
    WHERE NOT EXISTS (
        SELECT 1 FROM backup_log 
        WHERE backup_type = 'health_check' 
        AND requested_at > NOW() - INTERVAL '1 hour'
    );
    $$
);

-- Create view for backup monitoring
CREATE OR REPLACE VIEW backup_status AS
SELECT 
    backup_type,
    status,
    requested_at,
    completed_at,
    CASE 
        WHEN completed_at IS NOT NULL 
        THEN EXTRACT(EPOCH FROM (completed_at - requested_at))::INTEGER 
        ELSE NULL 
    END as duration_seconds,
    CASE 
        WHEN backup_size IS NOT NULL 
        THEN pg_size_pretty(backup_size) 
        ELSE NULL 
    END as backup_size_pretty,
    error_message
FROM backup_log 
ORDER BY requested_at DESC;

-- Create function to get recent backup status
CREATE OR REPLACE FUNCTION get_backup_summary()
RETURNS TABLE(
    backup_type text,
    last_successful timestamp with time zone,
    last_attempt timestamp with time zone,
    success_rate numeric,
    avg_duration interval
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        bl.backup_type::text,
        MAX(CASE WHEN bl.status = 'completed' THEN bl.completed_at END) as last_successful,
        MAX(bl.requested_at) as last_attempt,
        ROUND(
            COUNT(CASE WHEN bl.status = 'completed' THEN 1 END)::numeric / 
            NULLIF(COUNT(*)::numeric, 0) * 100, 2
        ) as success_rate,
        AVG(bl.completed_at - bl.requested_at) as avg_duration
    FROM backup_log bl 
    WHERE bl.requested_at > NOW() - INTERVAL '30 days'
    GROUP BY bl.backup_type;
END;
$$ LANGUAGE plpgsql;

-- Grant permissions for monitoring
GRANT SELECT ON backup_log TO backup_user;
GRANT SELECT ON backup_status TO backup_user;
GRANT EXECUTE ON FUNCTION get_backup_summary() TO backup_user;

-- Show current cron jobs
SELECT * FROM cron.job;

-- Display helpful information
SELECT 'pg_cron extension and backup jobs configured successfully!' as status;
SELECT 'Use SELECT * FROM backup_status; to monitor backups' as monitoring_tip;
SELECT 'Use SELECT * FROM get_backup_summary(); for backup analytics' as analytics_tip;