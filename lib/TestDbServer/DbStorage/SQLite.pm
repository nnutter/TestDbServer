use TestDbServer::Exceptions;
use DBI;

package TestDbServer::DbStorage::SQLite;

use Moose;
has app => (
    is => 'ro',
    isa => 'TestDbServer',
    required => 1,
);
has file => (
    is => 'ro',
    isa => 'Str',
    builder => '_db_file_pathname',
    required => 1,
);
has dbh => (
    is => 'rw',
    isa => 'DBI::db',
    lazy => 1,
    lazy_build => 1,
);

__PACKAGE__->meta->make_immutable;

sub BUILD {
    my $self = shift;

    $self->_init_db();
}

sub _init_db {
    my $self = shift;
    my $dbh = $self->dbh;

    $self->app->log->info('Initializing SQLite database');

    $dbh->do('PRAGMA foreign_keys = ON');

    my $create_db_template = q(
            CREATE TABLE IF NOT EXISTS db_template (
                template_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
                note VARCHAR,
                file_path VARCHAR NOT NULL UNIQUE,
                create_time TIMESTAMP NOT NULL,
                last_used_time TIMESTAMP NOT NULL));
    $dbh->do($create_db_template)
            || Exception::DB::CreateTable->throw(
                    error => $dbh->errstr,
                    table_name => 'db_template',
                    sql => $create_db_template,
                );

    my $create_live_database = q(
            CREATE TABLE IF NOT EXISTS live_database (
                database_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
                host VARCHAR NOT NULL,
                port INTEGER NOT NULL,
                user VARCHAR NOT NULL,
                password VARCHAR NOT NULL,
                create_time TIMESTAMP NOT NULL,
                expire_time TIMESTAMP NOT NULL,
                source_template_id INTEGER NOT NULL REFERENCES db_template(template_id),
                UNIQUE (host, port)));
    $dbh->do($create_live_database)
            || Exception::DB::CreateTable->throw(
                    error => $dbh->errstr,
                    table_name => 'live_database',
                    sql => $create_live_database,
                );

    return $dbh;
}

sub save_template {
    my $self = shift;
    my %params = @_;

    _verify_required_params(\%params, [qw( template_id file_path )]);

    return $self->_save_entity(
            'save_template',
            q(INSERT INTO db_template (template_id, note, file_path, create_time, last_used_time) VALUES (?, ?, ?, datetime('now'), datetime('now'))),
            @params{'template_id', 'note','file_path'},
    );
}

sub save_database {
    my $self = shift;
    my %params = @_;

    _verify_required_params(\%params, [qw(host port user password source_template_id)]);

    return $self->_save_entity(
        'save_database',
        q(INSERT INTO live_database (host, port, user, password, source_template_id, create_time, expire_time) VALUES (?, ?, ?, ?, ?, datetime('now'), datetime('now'))),
        @params{qw(host port user password source_template_id)},
    );
}

sub _verify_required_params {
    my $param_hash = shift;
    my $required_list = shift;

    if (my @missing = grep { ! exists $param_hash->{$_} } @$required_list) {
        Exception::RequiredParamMissing->throw(error => 'Required parameters missing: '.join(', ',@missing ),
                                               params => \@missing);
    }
    return 1;
}

sub _save_entity {
    my $self = shift;
    my $label = shift;
    my $sql = shift;

    my $dbh = $self->dbh;
    my $sth = $dbh->prepare_cached($sql)
            || Exception::DB::Insert::Prepare->throw(error => $dbh->errstr, sql => $sql);
    $sth->execute(@_)
            || Exception::DB::Insert::Execute->throw(error => $dbh->errstr, sql => $sql);

    my $id = $dbh->last_insert_id(undef, undef, undef, undef);
    $sth->finish;
    return $id;
}

sub get_template {
    my $self = shift;
    my $template_id = shift;

    return $self->_get_one_entity(
        'get_template',
        q(SELECT template_id, note, file_path create_time, last_used_time FROM db_template where template_id = ?),
        $template_id,
    );
}

sub get_database {
    my $self = shift;
    my $db_id = shift;

    return $self->_get_one_entity(
        'get_database',
        q(SELECT database_id, host, port, user, password, create_time, expire_time, source_template_id FROM live_database WHERE database_id = ?),
        $db_id,
    );
}

sub _get_one_entity {
    my($self, $label, $sql, $id) = @_;

    defined($id) || $self->_error("Getting one $label requires an ID argument");

    my $dbh = $self->dbh;
    my $sth = $dbh->prepare_cached($sql)
            || Exception::DB::Select::Prepare->throw(error => $dbh->errstr, sql => $sql);
    $sth->execute($id)
            || Exception::DB::Select::Execute->throw(error => $dbh->errstr, sql => $sql);

    my $row = $sth->fetchrow_hashref;
    $sth->finish;
    return $row;
}

sub get_templates {
    my $self = shift;

    return $self->_get_multiple_entities(
        'get_templates',
        q(SELECT template_id, note, file_path create_time, last_used_time FROM db_template),
    );
}

sub get_databases {
    my $self = shift;

    return $self->_get_multiple_entities(
        'get_databases',
        q(SELECT database_id, host, port, user, password, create_time, expire_time, source_template_id FROM live_database),
    );
}

sub _get_multiple_entities {
    my $self = shift;
    my $label = shift;
    my $sql = shift;

    my $dbh = $self->dbh;
    my $sth = $dbh->prepare_cached($sql)
            || Exception::DB::Select::Prepare->throw(error => $dbh->errstr, sql => $sql);
    $sth->execute(@_)
            || Exception::DB::Select::Execute->throw(error => $dbh->errstr, sql => $sql);

    my @rows;
    while( my $row = $sth->fetchrow_hashref ) {
        push @rows, $row;
    }
    $sth->finish;

    return \@rows;
}

sub count_templates {
    my $self = shift;

    return $self->_count_entities('db_template');
}

sub count_databases {
    my $self = shift;

    return $self->_count_entities('live_database');
}


sub _count_entities {
    my $self = shift;
    my $table_name = shift;

    my $dbh = $self->dbh;

    my $sql = qq(SELECT count(*) from $table_name);
    my $sth = $dbh->prepare_cached($sql)
        || Exception::DB::Select::Prepare->throw(error => $dbh->errstr, sql => $sql);
    $sth->execute()
        || Exception::DB::Select::Execute->throw(error => $dbh->errstr, sql => $sql);

    my @row = $sth->fetchrow_array;
    return $row[0];
}

sub _db_file_pathname {
    my $self = shift;

    my $class = ref($self) || $self;
    $class =~ s/::/\//g;
    my $file = $INC{"${class}.pm"};
    $file =~ s/pm$/sqlite3/;
    return $file;
}

sub _dbi_user { '' }
sub _dbi_password { '' }
sub _dbi_connect_options { { RaiseError => 0, AutoCommit => 0 } }

sub _dbi_connect_string {
    my $self = shift;
    my $filename = $self->file;
    return "dbi:SQLite:dbname=$filename";
}

sub _build_dbh {
    my $self = shift;

    my $connect_string = $self->_dbi_connect_string;
    $self->app->log->info("Connecting to SQLite database: $connect_string");
    my $dbh = DBI->connect(
                $connect_string,
                $self->_dbi_user,
                $self->_dbi_password,
                $self->_dbi_connect_options
             );
    return $dbh;
}

#sub DESTROY {
#    my $self = shift;
#    $self->dbh->disconnect;
#    $self->SUPER::DESTROY;
#}
