-- Verify database_template-table

BEGIN;

SELECT template_id, host, port, name, owner, note, create_time, last_used_time
FROM database_template
WHERE FALSE;

ROLLBACK;
