use TestDbServer::Schema;

use Test::More;
use Test::Exception;
use File::Temp;

use lib 't/lib';
use FakeApp;

use strict;
use warnings;

plan tests => 10;

my($schema, $temp_db_file);

# initialize

subtest initialize => sub {
    plan tests => 5;

    $temp_db_file = File::Temp->new(TEMPLATE => 'dbschema-sqliteXXXX', SUFFIX => '.sqlite3');
    $temp_db_file->close();
    my $connect_string = 'dbi:SQLite:' . $temp_db_file->filename;

    throws_ok { TestDbServer::Schema->connect($connect_string) }
        'Exception::NotInitialized',
        'Cannot call connect without initialize() first';

    my $fake_app = FakeApp->new();

    ok( TestDbServer::Schema->initialize($fake_app), 'Initialize schema');

    $schema = TestDbServer::Schema->connect($connect_string);
    ok($schema, 'Connect schema');

    ok(has_table($schema, 'db_template'), 'Table db_template_exists');
    ok(has_table($schema, 'live_database'), 'Table live_database exists');
};

my @templates;
subtest save_template => sub {
    plan tests => 6;

    my $template_1 = $schema->create_template(name => 'template 1', file_path => '/tmp/file1', note => 'hi there');
    ok($template_1,'Save template with a note');
    push @templates, $template_1;

    my $template_2 = $schema->create_template(name => 'template_2', file_path => '/tmp/file2');
    ok($template_2, 'Save template without a note');
    push @templates, $template_2;

    throws_ok { $schema->create_template(name => 'template 1', file_path => 'garbage', note => 'garbage') }
        'DBIx::Class::Exception',
        'Cannot save_template() with duplicate name';

    throws_ok { $schema->create_template(name => 'duplicate', file_path => '/tmp/file1') }
        'DBIx::Class::Exception',
        'Cannot save_template() with duplicate file_path';

    check_required_attributes_for_save(
        sub { $schema->create_template(@_) },
        { name => 'template name', file_path => '/path/to/file' },
    );
};

my @databases;
subtest save_database => sub {
    plan tests => 11;

    my @database_info = (
        { host => 'localhost', port => 123, name => 'joe', template_id => $templates[0]->template_id },
        { host => 'localhost', port => 123, name => 'bob', template_id => $templates[0]->template_id },
        { host => 'other', port => 123, name => 'bob', template_id => $templates[0]->template_id },
        { host => 'localhost', port => 456, name => 'bob', template_id => $templates[0]->template_id },
        { host => 'other', port => 999, name => 'frank', template_id => $templates[1]->template_id },
    );

    for (my $i = 0; $i < @database_info; $i++) {
        my $db = $schema->create_database(%{ $database_info[$i] });
        ok($db, "Save database $i");
        push @databases, $db;
    }

    check_required_attributes_for_save(
        sub { $schema->create_database(@_) },
        { host => 'localhost', port => 123, name => 'joe', template_id => $templates[0] }
    );

    throws_ok { $schema->create_database(template_id => 'garbage',  host => 'h', port => 1, user => 'u', password => 'p') }
        'DBIx::Class::Exception',
        'Cannot insert database that is not linked to a template';

    my %duplicate_host_port_name = %{$database_info[0]};
    $duplicate_host_port_name{template_id} = $templates[1]->template_id;
    throws_ok { $schema->create_database(%duplicate_host_port_name) }
        'DBIx::Class::Exception',
        'Cannot insert database with duplicate host port and name';
};

sub check_required_attributes_for_save {
    my $create_sub = shift;
    my $all_params_hash = shift;

    foreach my $missing ( keys %$all_params_hash ) {
        my %params = %$all_params_hash;
        delete $params{$missing};
        throws_ok { $create_sub->(%params) }
            'DBIx::Class::Exception',
            "$missing is a requried to save";
    }
}

subtest get_template => sub {
    plan tests => scalar(@templates) * 2;

    foreach my $template ( @templates ) {
        my $template_id = $template->template_id;
        my $tmpl = $schema->find_template($template_id);
        ok($tmpl, "Get template $template_id");
        is($tmpl->template_id, $template_id, 'template_id is correct');
    }
};

subtest get_database => sub {
    plan tests => scalar(@databases) * 2;

    foreach my $database ( @databases ) {
        my $database_id = $database->database_id;
        my $db = $schema->find_database($database_id);
        ok($db, "Get template $database_id");
        is($db->database_id, $database_id, 'database_id is correct');
    }
};

subtest all_get_templates => sub {
    plan tests => 2;

    my $got_templates = $schema->search_template();
    _assert_all_matching($got_templates, \@templates, 'template');
};

subtest get_all_databases => sub {
    plan tests => 2;

    my $got_databases = $schema->search_database();
    _assert_all_matching($got_databases, \@databases, 'database');
};

subtest count => sub {
    plan tests => 2;

    my $count;

    $count = $schema->search_template();
    is($count->count, scalar(@templates), 'count templates');

    $count = $schema->search_database();
    is($count->count, scalar(@databases), 'count databases');
};

# $databases[2] is linked to $templates[1]
subtest delete_database => sub {
    plan tests => 3;

    dies_ok { $schema->delete_database('garbage') }
        'Deleting unknown database throws exception';

    delete_thing('database', $databases[-1]->database_id);
};

subtest delete_template => sub {
    plan tests => 5;

    dies_ok { $schema->delete_template('garbage') }
        'Deleting unknown template throws exception';

    throws_ok { $schema->delete_template($templates[0]->template_id) }
        'DBIx::Class::Exception',
        'Cannot remove template with linked databases';
    ok($schema->find_template($templates[0]->template_id), 'template still exists');

    delete_thing('template', $templates[1]->template_id);
};

sub delete_thing {
    my($thing_type, $id) = @_;

    my $delete_sub = "delete_${thing_type}";
    ok($schema->$delete_sub($id), "Delete $thing_type");

    my $find_sub = "find_${thing_type}";
    ok(! $schema->$find_sub($id), "$thing_type was deleted");
}


sub _assert_all_matching {
    my($got_resultset, $expected_list, $label) = @_;

    my %got;
    my $id_method = "${label}_id";
    while(my $got = $got_resultset->next) {
        my $id = $got->$id_method();
        $got{$id} = 1;
    }

    is(scalar( keys %got ), scalar(@$expected_list), 'Got expected number of items');

    foreach my $expected ( @$expected_list ) {
        my $id = $expected->$id_method;
        unless (delete $got{$id}) {
            ok(0, "${label}_id $id in result set");
        }
    }

    is(scalar( keys %got ), 0, "Found all expected ${label}s");
}

sub has_table {
    my $schema = shift;
    my $table_name = shift;

    my $dbh = $schema->storage->dbh;
    my $sth = $dbh->prepare(q(select * from sqlite_master where type = 'table' and tbl_name = ?));
    $sth->execute($table_name);
    return $sth->fetchrow_hashref;
}
