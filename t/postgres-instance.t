use TestDbServer::Schema;

use Test::More;
use Test::Exception;
use DBI;
use File::Temp;

use TestDbServer::Configuration;
use TestDbServer::PostgresInstance;

use strict;
use warnings;

plan tests => 4;

my $config = TestDbServer::Configuration->new_from_path();
my $host = $config->db_host;
my $port = $config->db_port;
my $superuser = $config->db_user;
my $owner = 'genome';

subtest 'create connect delete' => sub {
    plan tests => 6;

    my $pg = TestDbServer::PostgresInstance->new(
                host => $host,
                port => $port,
                owner => $owner,
                superuser => $superuser,
            );
    ok($pg, 'Created new PostgresInstance');
    ok($pg->name, 'has a name: '. $pg->name);

    ok($pg->createdb, 'Create database');

    my $db_name = $pg->name;
    ok(connect_to_db($db_name), 'Connected');

    ok($pg->dropdb, 'Delete database');
    ok( ! connect_to_db($db_name), 'Cannot connect to deleted database');
};

subtest 'import db' => sub {
    plan tests => 4;

    my $fh = File::Temp->new();
    $fh->print('CREATE TABLE foo(foo_id integer NOT NULL PRIMARY KEY)');
    $fh->close();

    my $pg = TestDbServer::PostgresInstance->new(
                host => $host,
                port => $port,
                owner => $owner,
                superuser => $superuser,
            );
    ok($pg->createdb, 'Create database');

    ok($pg->importdb($fh->filename), 'import');

    my $dbh = connect_to_db($pg->name);
    my $sth = $dbh->table_info('','','foo','TABLE');
    my $rows = $sth->fetchall_arrayref({TABLE_NAME => 1});
    is_deeply($rows,
        [ { TABLE_NAME => 'foo' } ],
        'Import created table');

    $dbh->disconnect();
    ok($pg->dropdb(), 'drop database');
};

subtest 'importdb throws exception' => sub {
    plan tests => 3;

    my $fh = File::Temp->new();
    $fh->print('CREATE TABLE foo(foo_id integer NULL KEY)');  # invalid SQL
    $fh->close();

    my $pg = TestDbServer::PostgresInstance->new(
                host => $host,
                port => $port,
                owner => $owner,
                superuser => $superuser,
            );
    ok($pg->createdb, 'Create database');

    throws_ok { $pg->importdb($fh->filename) }
            'Exception::CannotImportDatabase',
            'Importing broken SQL generates exception';

    ok($pg->dropdb(), 'drop db');
};

subtest 'export db' => sub {
    plan tests => 6;

    my $pg = TestDbServer::PostgresInstance->new(
                host => $host,
                port => $port,
                owner => $owner,
                superuser => $superuser,
            );
    ok($pg->createdb, 'Create database');

    my $dbh = connect_to_db($pg->name);
    ok($dbh->do(q(CREATE TABLE foo (foo_id integer NOT NULL PRIMARY KEY))),
        'create table in database');

    my ($fh, $filename) = File::Temp::tempfile(UNLINK => 1);
    $fh->close();
    ok($pg->exportdb($filename), 'export');
    ok(-f $filename, "exported file exists: $filename");
    my $contents = do {
        local $/;
        open(my $fh, '<', $filename);
        <$fh>;
    };
    like($contents, qr/^CREATE TABLE foo/mi, 'Dump contains expected CREATE TABLE');

    $dbh->disconnect();
    ok($pg->dropdb(), 'drop database');
};

sub connect_to_db {
    my $db_name = shift;
    DBI->connect("dbi:Pg:dbname=$db_name;host=$host;port=$port", $owner, '', { PrintError => 0 });
}
