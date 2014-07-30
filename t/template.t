use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
use Mojo::JSON;

use File::Temp;

use TestDbServer::Configuration;
plan tests => 6;

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

my @templates;
subtest 'list' => sub {
    plan tests => 6;

    $t->get_ok('/templates')
        ->status_is(200)
        ->json_is([]);

    
    my $db = $app->db_storage;
    @templates = (  $db->create_template(name => 'foo', owner => 'bubba', file_path => 'bar'),
                    $db->create_template(name => 'baz', owner => 'bubba', file_path => 'quux')
                );

    my $expected_data = [ $templates[0]->template_id, $templates[1]->template_id ];
    my $req = $t->get_ok('/templates')
                ->status_is(200)
                ->json_is($expected_data);
};

subtest 'get' => sub {
    plan tests => 10;

    $t->get_ok('/templates/'.$templates[0]->template_id)
        ->status_is(200)
        ->json_is('/template_id' => $templates[0]->template_id)
        ->json_is('/name' => 'foo')
        ->json_is('/file_path' => 'bar')
        ->json_is('/note' => undef)
        ->json_has('/create_time')
        ->json_has('/last_used_time');

    $t->get_ok('/templates/garbage')
        ->status_is(404);
};

subtest 'delete' => sub {
    plan tests => 6;

    my $template_id = $templates[0]->template_id;
    $t->delete_ok("/templates/$template_id")
        ->status_is(204);

    $t->get_ok("/templates/$template_id")
        ->status_is(404);

    $t->delete_ok('/templates/garbage')
        ->status_is(404);
};

subtest 'upload file' => sub {
    plan tests => 11;

    my $upload_file_contents = "This is test content\n";
    my $upload_file = File::Temp->new();
    $upload_file->print($upload_file_contents);
    $upload_file->close();
    my $upload_file_name = File::Basename::basename($upload_file->filename);

    my $template_name = 'test upload';
    my $template_owner = 'bubba';
    my $template_note = 'This is some test data';

    my $test = $t->post_ok('/templates' =>
                    form => {
                        name => $template_name,
                        owner => $template_owner,
                        note => $template_note,
                        file => { file => $upload_file->filename },
                    })
            ->status_is(201)
            ->header_like('Location' => qr(/templates/\w+), 'Location header');

    my $location = $test->tx->res->headers->location;
    $t->get_ok($location)
        ->status_is(200)
        ->json_is('/name' => $template_name)
        ->json_is('/owner' => $template_owner)
        ->json_is('/note' => $template_note)
        ->json_is('/file_path', File::Basename::basename($upload_file_name));

    ok(-f $app->file_storage->path_for_name($upload_file_name),
        'Uploaded file exists');

    is(join('', $app->file_storage->open_file($upload_file_name)->getlines()),
        $upload_file_contents,
        'Upload file contents');
};

subtest 'upload duplicate' => sub {
    plan tests => 6;

    my $upload_file = File::Temp->new();
    $upload_file->print("This is test content\n");
    $upload_file->close();

    my $template_name = 'duplicate upload';
    my $template_owner = 'bubba';

    $t->post_ok('/templates' =>
                    form => {
                        name => $template_name,
                        owner => $template_owner,
                        file => { file => $upload_file->filename }
                    },
                )
            ->status_is(201);

    $t->post_ok('/templates' =>
                    form => {
                        name => $template_name . 'and more',
                        owner => $template_owner,
                        file => { file => $upload_file->filename }
                    },
                )
            ->status_is(403, 'Upload with duplicate file path returns 403');

    $t->post_ok('/templates' =>
                    form => {
                        name => $template_name,
                        owner => $template_owner,
                        file => { file => __FILE__ }
                    },
                )
            ->status_is(403, 'Upload with duplicate name returns 403');
};

subtest 'based on database' => sub {
    TODO: {
        local $TODO = 'creating template based on database not implemented yet';

        my $create_database =
            $t->post_ok('/databases')
                ->status_is(201)
                ->json_has('/id')
                ->json_has('/host')
                ->json_has('/port')
                ->json_has('/user')
                ->json_has('/password')
                ->json_has('/expires');

        my $body = $create_database->tx->res->body;
        my $database_details = Mojo::JSON::decode_json($body) if $create_database->tx->res->is_status_class(200);
        my $database_id = $database_details->{id};

        $t->post_ok("/templates?based_on=$database_id")
            ->status_is(201)
    }
};
