use TestDbServer::Schema;

use Test::More;
use Test::Exception;
use DBI;

use TestDbServer::PostgresInstance;

use strict;
use warnings;

plan tests => 5;

my $host = 'localhost';
my $port = 5434;
my $owner = 'genome';
my $superuser = 'postgres';

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
my $dbh = DBI->connect("dbi:Pg:dbname=$db_name;host=$host;port=$port", $owner, '');
ok($dbh, 'Connected');

undef $dbh;

ok($pg->dropdb, 'Delete database');
