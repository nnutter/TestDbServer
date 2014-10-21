-- Verify remove-db_template-table

BEGIN;

SELECT 1/(count(*)-1) FROM pg_class WHERE relname = 'db_template';

ROLLBACK;
