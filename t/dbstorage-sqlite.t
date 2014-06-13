use TestDbServer::DbStorage::SQLite;
use Test::More;
use Test::Exception;
use File::Temp;

use lib 'lib';
use FakeApp;

plan tests => 8;

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

ok($storage->save_template(file_path => '/tmp/file1', note => 'hi there'),
    'Save template with a note');
ok($storage->save_template(file_path => '/tmp/file2'),
    'Save template without a note');

throws_ok { $storage->save_template(note => 'denied') }
    'Exception::RequiredParamMissing',
    'save_template() requires file_path param';

throws_ok { $storage->save_template(file_path => '/tmp/file1') }
    'Exception::DB::Insert',
    'Cannot save_template() with duplicate file_path';

sub has_table {
    my $storage = shift;
    my $table_name = shift;

    my $dbh = $storage->dbh;
    my $sth = $dbh->prepare(q(select * from sqlite_master where type = 'table' and tbl_name = ?));
    $sth->execute($table_name);
    return $sth->fetchrow_hashref;
}
