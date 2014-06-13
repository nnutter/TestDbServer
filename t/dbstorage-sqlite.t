use TestDbServer::DbStorage::SQLite;
use Test::More;
use Test::Exception;
use File::Temp;

use lib 'lib';
use FakeApp;

plan tests => 4;

throws_ok { TestDbServer::DbStorage::SQLite->new() }
    qr/Attribute \(app\) is required/,
    'Creating SQLite storage requires arguments';

my $fake_app = FakeApp->new();
my $temp_db_file = File::Temp->new(TEMPLATE => 'dbstorage-sqliteXXXX', SUFFIX => '.sqlite3');
$temp_db_file->close();
my $storage = TestDbServer::DbStorage::SQLite->new(app => $fake_app, file => $temp_db_file->filename);
ok($storage, 'Create new SQLite storaage');

ok(has_table($storage, 'db_template'), 'Table db_template_exists');
ok(has_table($storage, 'live_database'), 'Table live_database exists');

sub has_table {
    my $storage = shift;
    my $table_name = shift;

    my $dbh = $storage->dbh;
    my $sth = $dbh->prepare(q(select * from sqlite_master where type = 'table' and tbl_name = ?));
    $sth->execute($table_name);
    return $sth->fetchrow_hashref;
}
