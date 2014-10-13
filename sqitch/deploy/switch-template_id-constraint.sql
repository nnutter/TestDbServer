-- Deploy switch-template_id-constraint
-- requires: database_template-table
-- requires: live_database_table

BEGIN;

ALTER TABLE live_database DROP CONSTRAINT live_database_template_id_fkey;
ALTER TABLE live_database ADD CONSTRAINT live_database_template_id_fkey FOREIGN KEY (template_id) REFERENCES database_template(template_id);

COMMIT;
