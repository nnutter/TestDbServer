-- Verify db_template_table

BEGIN;

select template_id, name, owner, note, sql_script, create_time, last_used_time
from db_template
where FALSE;

ROLLBACK;
