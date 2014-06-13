use TestDbServer::DbStorage::SQLite;
use Test::More;
use Test::Exception;
use File::Temp;

use lib 'lib';
use FakeApp;

use strict;
use warnings;

plan tests => 3;

# initialize
my($storage, $temp_db_file);

subtest initialize => sub {
    plan tests => 4;

    throws_ok { TestDbServer::DbStorage::SQLite->new() }
        qr/Attribute \(app\) is required/,
        'Creating SQLite storage requires arguments';

    my $fake_app = FakeApp->new();
    $temp_db_file = File::Temp->new(TEMPLATE => 'dbstorage-sqliteXXXX', SUFFIX => '.sqlite3');
    $temp_db_file->close();
    $storage = TestDbServer::DbStorage::SQLite->new(app => $fake_app, file => $temp_db_file->filename);
    ok($storage, 'Create new SQLite storaage');

    ok(has_table($storage, 'db_template'), 'Table db_template_exists');
    ok(has_table($storage, 'live_database'), 'Table live_database exists');
};


my @templates;
subtest save_template => sub {
    plan tests => 4;

    my $template_1 = $storage->save_template(file_path => '/tmp/file1', note => 'hi there');
    ok($template_1,'Save template with a note');
    push @templates, $template_1;

    my $template_2 = $storage->save_template(file_path => '/tmp/file2');
    ok($template_2, 'Save template without a note');
    push @templates, $template_2;

    throws_ok { $storage->save_template(note => 'denied') }
        'Exception::RequiredParamMissing',
        'save_template() requires file_path param';

    throws_ok { $storage->save_template(file_path => '/tmp/file1') }
        'Exception::DB::Insert',
        'Cannot save_template() with duplicate file_path';
};


my @databases;
subtest save_database => sub {
    plan tests => 9;

    my @database_info = (
        { host => 'localhost', port => 123, user => 'joe', password => 'secret', source_template_id => $templates[0] },
        { host => 'localhost', port => 321, user => 'bob', password => 'secret', source_template_id => $templates[0] },
        { host => 'other', port => 999, user => 'frank', password => 'secret', source_template_id => $templates[1] },
    );

    for (my $i = 0; $i < @database_info; $i++) {
        my $db = $storage->save_database(%{ $database_info[$i] });
        push @databases, $db;
        ok($db, "Save database $i");
    }

    my %params_for_missing = ( host => 'localhost', port => 123, user => 'joe', password => 'secret', source_template_id => $templates[0] );
    foreach my $missing ( keys %params_for_missing ) {
        my %params = %params_for_missing;
        delete $params{$missing};
        throws_ok { $storage->save_database(%params) }
            'Exception::RequiredParamMissing',
            "save_database() requires $missing";
    }

    throws_ok { $storage->save_database( source_template_id => 'garbage',  host => 'h', port => 1, user => 'u', password => 'p') }
        'Exception::DB::Insert',
        'Cannot insert database that is not linked to a template';
};


# get template

sub has_table {
    my $storage = shift;
    my $table_name = shift;

    my $dbh = $storage->dbh;
    my $sth = $dbh->prepare(q(select * from sqlite_master where type = 'table' and tbl_name = ?));
    $sth->execute($table_name);
    return $sth->fetchrow_hashref;
}
