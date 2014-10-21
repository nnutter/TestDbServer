-- Verify switch-template_id-constraint

BEGIN;

SELECT 1/count(*)
FROM pg_catalog.pg_class c
join pg_catalog.pg_constraint r on r.conrelid = c.oid
WHERE c.relname = 'live_database'
  AND conname = 'live_database_template_id_fkey'
  AND pg_catalog.pg_get_constraintdef(r.oid, true) = 'FOREIGN KEY (template_id) REFERENCES database_template(template_id)';

ROLLBACK;
