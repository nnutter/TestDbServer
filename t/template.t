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
                    db_connect_string => $connect_string,
                    db_user => 'postgres',
                    db_host => 'localhost',
                    db_port => 5434,
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
    my $file_store = $app->file_storage;
    @templates = (  $db->create_template(name => 'foo', owner => 'bubba', file_path => make_file_for_template($file_store)),
                    $db->create_template(name => 'baz', owner => 'bubba', file_path => make_file_for_template($file_store)),
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
        ->json_is('/file_path' => $templates[0]->file_path)
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
            ->status_is(409, 'Upload with duplicate file path returns 409');

    $t->post_ok('/templates' =>
                    form => {
                        name => $template_name,
                        owner => $template_owner,
                        file => { file => __FILE__ }
                    },
                )
            ->status_is(409, 'Upload with duplicate name returns 409');
};

subtest 'based on database' => sub {
    plan tests => 16;

    my $template_owner = 'genome';

    my $create_database =
        $t->post_ok("/databases?owner=$template_owner")
            ->status_is(201)
            ->json_has('/id');

    my $database_details = $create_database->tx->res->json;
    my $database_id = $database_details->{id};

    my $template_name = "test_template_$$";
    my $creation = $t->post_ok("/templates?based_on=${database_id}&name=${template_name}")
        ->status_is(201)
        ->header_like('Location' => qr(/templates/\w+), 'Location header');

    # Try getting the thing at the Location header
    $t->get_ok($creation->tx->res->headers->location)
        ->status_is(200)
        ->json_is('/name', $template_name)
        ->json_is('/owner', $template_owner);



    $t->post_ok("/templates?based_on=$database_id")  # missing name param
        ->status_is(400);

    $t->post_ok("/templates?based_on=bogus&name=qwerty")  # bogus database id
        ->status_is(404);

    $t->post_ok("/templates?based_on=$database_id&name=${template_name}") # same as first
        ->status_is(409);
};

my @files_for_template;
sub make_file_for_template {
    my $file_storage = shift;

    my $fh = File::Temp->new();
    $fh->print("hi\n");
    $fh->close();

    push @files_for_template, $fh;
    my $name = $file_storage->save($fh->filename);
    return $name;
}
