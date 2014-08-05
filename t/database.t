use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
use Mojo::JSON;
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

my @databases;
subtest 'list' => sub {
    plan tests => 6;

    my $r = $t->get_ok('/databases')
        ->status_is(200)
        ->json_is([]);

    my $db = $app->db_storage;
    @databases = ( $db->create_database( host => 'foo', port => '123', name => 'qwerty', owner => 'me' ),
                   $db->create_database( host => 'bar', port => '456', name => 'uiop', owner => 'you' ),
                );
    my $expected_data = [ map { $_->database_id } @databases ];
    $t->get_ok('/databases')
      ->status_is(200)
      ->json_is($expected_data);
};

subtest 'get' => sub {
    plan tests => 12;

    $t->get_ok('/databases/'.$databases[0]->database_id)
        ->status_is(200)
        ->json_is('/database_id' => $databases[0]->database_id)
        ->json_is('/host' => 'foo')
        ->json_is('/port' => '123' )
        ->json_is('/name' => 'qwerty')
        ->json_is('/owner' => 'me')
        ->json_is('/template_id' => undef)
        ->json_has('/create_time')
        ->json_has('/expire_time');

    $t->get_ok('/databases/garbage')
        ->status_is(404);
};
