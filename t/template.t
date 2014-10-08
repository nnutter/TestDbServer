use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
use Test::Deep qw(cmp_deeply supersetof);
use Mojo::JSON;
use Data::UUID;

use File::Temp qw();

use TestDbServer::Configuration;
plan tests => 7;

my $config = TestDbServer::Configuration->new_from_path();

my $t = Test::Mojo->new('TestDbServer');
my $app = $t->app;
$app->configuration($config);

my $uuid_gen = Data::UUID->new();

my @templates;
subtest 'list' => sub {
    plan tests => 6;

    my $req = $t->get_ok('/templates')
        ->status_is(200);

    my $db_list = $req->tx->res->json;
    is(ref($db_list), 'ARRAY', '/templates is an arrayref');
    
    my $db = $app->db_storage;
    my $owner = $uuid_gen->create_str;
    @templates = (  $db->create_template(name => $uuid_gen->create_str, owner => $owner, sql_script => 'script 1'),
                    $db->create_template(name => $uuid_gen->create_str, owner => $owner, sql_script => 'script 2'),
                );

    $req = $t->get_ok('/templates')
                ->status_is(200);

    $db_list = $req->tx->res->json;
    cmp_deeply($db_list, supersetof(map { $_->template_id } @templates), 'Found created templates');
};

subtest 'search' => sub {
    plan tests => 11;

    $t->get_ok('/templates?name='.$templates[0]->name)
        ->status_is(200)
        ->json_is([$templates[0]->template_id]);

    $t->get_ok('/templates?owner='.$templates[0]->owner)
        ->status_is(200)
        ->json_is([map { $_->template_id } @templates]);

    $t->get_ok('/templates?owner=garbage')
        ->status_is(200)
        ->json_is([]);

    $t->get_ok('/templates?garbage=foo')
        ->status_is(400);
};

subtest 'get' => sub {
    plan tests => 12;

    $t->get_ok('/templates/'.$templates[0]->template_id)
        ->status_is(200)
        ->json_is('/template_id' => $templates[0]->template_id)
        ->json_is('/name' => $templates[0]->name)
        ->json_is('/sql_script' => $templates[0]->sql_script)
        ->json_is('/note' => undef)
        ->json_has('/create_time')
        ->json_has('/last_used_time');

    $t->get_ok('/templates/99999')
        ->status_is(404);

    $t->get_ok('/templates/garbage')
        ->status_is(400);
};

subtest 'delete' => sub {
    plan tests => 8;

    my $template_id = $templates[0]->template_id;
    $t->delete_ok("/templates/$template_id")
        ->status_is(204);

    $t->get_ok("/templates/$template_id")
        ->status_is(404);

    $t->delete_ok('/templates/99999')
        ->status_is(404);

    $t->delete_ok('/templates/garbage')
        ->status_is(400);
};

subtest 'upload file' => sub {
    plan tests => 9;

    my $upload_file_contents = "This is test content\n";
    my $upload_file = File::Temp->new();
    $upload_file->print($upload_file_contents);
    $upload_file->close();
    my $upload_file_name = File::Basename::basename($upload_file->filename);

    my $template_name = $uuid_gen->create_str;
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
        ->json_is('/sql_script', $upload_file_contents);
};

subtest 'upload duplicate' => sub {
    plan tests => 4;

    my $upload_file = File::Temp->new();
    $upload_file->print("This is test content\n");
    $upload_file->close();

    my $template_name = $uuid_gen->create_str;
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
                        name => $template_name,
                        owner => $template_owner,
                        file => { file => __FILE__ }
                    },
                )
            ->status_is(409, 'Upload with duplicate name returns 409');
};

subtest 'based on database' => sub {
    plan tests => 18;

    my $template_owner = $config->test_db_owner;

    my $create_database =
        $t->post_ok("/databases?owner=$template_owner")
            ->status_is(201)
            ->json_has('/id');

    my $database_details = $create_database->tx->res->json;
    my $database_id = $database_details->{id};

    my $template_name = $uuid_gen->create_str;
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

    $t->post_ok("/templates?based_on=99999&name=qwerty")  # template does not exist with this id
        ->status_is(404);

    $t->post_ok("/templates?based_on=bogus&name=qwerty")  # bogus template id
        ->status_is(400);

    $t->post_ok("/templates?based_on=$database_id&name=${template_name}") # same as first
        ->status_is(409);
};

