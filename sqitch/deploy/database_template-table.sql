-- Deploy database_template-table
-- requires: live_database_table

BEGIN;

CREATE TABLE IF NOT EXISTS database_template (
    template_id SERIAL NOT NULL PRIMARY KEY,
    host VARCHAR NOT NULL,
    port VARCHAR NOT NULL,
    name VARCHAR NOT NULL,
    owner VARCHAR NOT NULL,
    note VARCHAR,
    create_time TIMESTAMP NOT NULL DEFAULT(now()),
    last_used_time TIMESTAMP NOT NULL DEFAULT(now()),
    UNIQUE (host, port, name)
);

COMMIT;
