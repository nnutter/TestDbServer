use TestDbServer::DbStorage::SQLite;
use Test::More;
use Test::Exception;
use File::Temp;

use lib 'lib';
use FakeApp;

use strict;
use warnings;

plan tests => 8;

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
    plan tests => 6;

    my $template_1 = $storage->save_template(name => 'template 1', file_path => '/tmp/file1', note => 'hi there');
    ok($template_1,'Save template with a note');
    push @templates, $template_1;

    my $template_2 = $storage->save_template(name => 'template_2', file_path => '/tmp/file2');
    ok($template_2, 'Save template without a note');
    push @templates, $template_2;

    throws_ok { $storage->save_template(name => 'template 1', file_path => 'garbage', note => 'garbage') }
        'Exception::DB::Insert',
        'Cannot save_template() with duplicate name';

    throws_ok { $storage->save_template(name => 'duplicate', file_path => '/tmp/file1') }
        'Exception::DB::Insert',
        'Cannot save_template() with duplicate file_path';

    check_required_attributes_for_save(
        sub { $storage->save_template(@_) },
        { name => 'template name', file_path => '/path/to/file' },
    );
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

    check_required_attributes_for_save(
        sub { $storage->save_database(@_) },
        { host => 'localhost', port => 123, user => 'joe', password => 'secret', source_template_id => $templates[0] }
    );

    throws_ok { $storage->save_database( source_template_id => 'garbage',  host => 'h', port => 1, user => 'u', password => 'p') }
        'Exception::DB::Insert',
        'Cannot insert database that is not linked to a template';
};

sub check_required_attributes_for_save {
    my $create_sub = shift;
    my $all_params_hash = shift;

    foreach my $missing ( keys %$all_params_hash ) {
        my %params = %$all_params_hash;
        delete $params{$missing};
        throws_ok { $create_sub->(%params) }
            'Exception::RequiredParamMissing',
            "$missing is a requried param";
    }
}

subtest get_template => sub {
    plan tests => scalar(@templates) * 2;

    foreach my $template_id ( @templates ) {
        my $tmpl = $storage->get_template($template_id);
        ok($tmpl, "Get template $template_id");
        is($tmpl->{template_id}, $template_id, 'template_id is correct');
    }
};

subtest get_database => sub {
    plan tests => scalar(@databases) * 2;

    foreach my $database_id ( @databases ) {
        my $db = $storage->get_database($database_id);
        ok($db, "Get template $database_id");
        is($db->{database_id}, $database_id, 'database_id is correct');
    }
};

subtest all_get_templates => sub {
    plan tests => 2;

    my $got_templates = $storage->get_templates();
    _assert_all_matching($got_templates, \@templates, 'template');
};

subtest get_all_databases => sub {
    plan tests => 2;

    my $got_databases = $storage->get_databases();
    _assert_all_matching($got_databases, \@databases, 'database');
};

subtest count => sub {
    plan tests => 2;

    my $count;

    $count = $storage->count_templates();
    is($count, scalar(@templates), 'count templates');

    $count = $storage->count_databases();
    is($count, scalar(@databases), 'count databases');
};

sub _assert_all_matching {
    my($got_list, $expected_list, $label) = @_;

    is(scalar(@$got_list), scalar(@$expected_list), "Get all ${label}s");

    my %got = map { $_->{"${label}_id"} => 1 } @$got_list;

    foreach my $id ( @$expected_list ) {
        unless (delete $got{$id}) {
            ok(0, "${label}_id $id in result set");
        }
    }

    is(scalar( keys %got ), 0, "Found all expected ${label}s");
}

# get template

sub has_table {
    my $storage = shift;
    my $table_name = shift;

    my $dbh = $storage->dbh;
    my $sth = $dbh->prepare(q(select * from sqlite_master where type = 'table' and tbl_name = ?));
    $sth->execute($table_name);
    return $sth->fetchrow_hashref;
}
