use TestDbServer::Schema;

use Test::More;
use Test::Exception;
use DBI;

use TestDbServer::PostgresInstance;

use strict;
use warnings;

plan tests => 1;

my $host = 'localhost';
my $port = 5434;
my $owner = 'genome';
my $superuser = 'postgres';

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

sub connect_to_db {
    my $db_name = shift;
    DBI->connect("dbi:Pg:dbname=$db_name;host=$host;port=$port", $owner, '', { PrintError => 0 });
}
