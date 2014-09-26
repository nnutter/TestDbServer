-- Revert db_template_table

BEGIN;

drop table db_template;

COMMIT;
