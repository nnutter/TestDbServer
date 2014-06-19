package TestDbServer::Schema::Result::Database;
use parent 'TestDbServer::Schema::ResultBase';

__PACKAGE__->table('live_database');
__PACKAGE__->add_columns(qw(database_id host port name create_time expire_time template_id));
__PACKAGE__->set_primary_key('database_id');
__PACKAGE__->belongs_to(template => 'TestDbServer::Schema::Result::Template', 'template_id');

sub _create_table_sql_SQLite {
    q(
        CREATE TABLE IF NOT EXISTS live_database (
            database_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            host VARCHAR NOT NULL,
            port INTEGER NOT NULL,
            name VARCHAR NOT NULL,
            create_time TIMESTAMP NOT NULL DEFAULT(datetime('now')),
            expire_time TIMESTAMP NOT NULL DEFAULT(datetime('now')),
            template_id INTEGER NOT NULL REFERENCES db_template(template_id),
            UNIQUE (host, port, name))
    );
}

1;
