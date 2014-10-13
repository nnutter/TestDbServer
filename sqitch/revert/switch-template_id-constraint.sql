-- Revert switch-template_id-constraint

BEGIN;

ALTER TABLE live_database DROP CONSTRAINT live_database_template_id_fkey;
ALTER TABLE live_database ADD CONSTRAINT live_database_template_id_fkey FOREIGN KEY (template_id) REFERENCES db_template(template_id);

COMMIT;
