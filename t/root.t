use Mojo::Base -strict;

use Test::More;
use Test::Mojo;

use File::Temp;

plan tests => 2;

my $t = Test::Mojo->new('TestDbServer');
my $app = $t->app;

my $temp_db = File::Temp->new(TEMPLATE => 'testdbserver_root_XXXXX', SUFFIX => 'sqlite3');
$app->config->{'db_connect_string'} = "dbi:SQLite:${temp_db}";

subtest 'root with no db entities' => sub {
    plan tests => 5;

    $t->get_ok('/')
        ->status_is(200)
        ->json_is('/template_count' => 0)
        ->json_is('/database_count' => 0)
        ->json_is('/file_path' => $app->file_storage_path);
};

subtest 'root with one template and one database' => sub {
    plan tests => 5;

    my $storage = $app->db_storage();
    my $template = $storage->create_template(name => 'foo', file_path => 'bar');
    my $database = $storage->create_database(host => 'localhost',
                                             port => 123,
                                             user => 'bob',
                                             password => 'secret',
                                             template_id => $template->template_id);
    $t->get_ok('/')
        ->status_is(200)
        ->json_is('/template_count' => 1)
        ->json_is('/database_count' => 1)
        ->json_is('/file_path' => $app->file_storage_path);
};
