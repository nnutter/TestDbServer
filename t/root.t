use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
use File::Temp;

use TestDbServer::Configuration;

plan tests => 2;

my $file_storage_path = File::Temp::tempdir( CLEANUP => 1);
my $db = File::Temp->new(TEMPLATE => 'testdbserver_testdb_XXXXX', SUFFIX => 'sqlite3');
my $connect_string = 'dbi:SQLite:' . $db->filename;
my $config = TestDbServer::Configuration->new(
                    file_storage_path => $file_storage_path,
                    db_connect_string => $connect_string
                );

my $t = Test::Mojo->new('TestDbServer');
my $app = $t->app;
$app->configuration($config);

subtest 'root with no db entities' => sub {
    plan tests => 5;

    $t->get_ok('/')
        ->status_is(200)
        ->json_is('/template_count' => 0)
        ->json_is('/database_count' => 0)
        ->json_is('/file_path' => $app->configuration->file_storage_path);
};

subtest 'root with one template and one database' => sub {
    plan tests => 5;

    my $storage = $app->db_storage();
    my $template = $storage->create_template(name => 'foo', file_path => 'bar', owner => 'bubba');
    my $database = $storage->create_database(host => 'localhost',
                                             port => 123,
                                             name => 'bob',
                                             owner => 'bubba',
                                             template_id => $template->template_id);
    $t->get_ok('/')
        ->status_is(200)
        ->json_is('/template_count' => 1)
        ->json_is('/database_count' => 1)
        ->json_is('/file_path' => $app->configuration->file_storage_path);
};
