use Mojo::Base -strict;

use Test::More;
use Mojo::Upload;
use Mojo::Asset::Memory;

use File::Temp;

use TestDbServer::FileStorage;
use TestDbServer::Schema;
use TestDbServer::PostgresInstance;
use lib 't/lib';
use FakeApp;
use DBI;

use TestDbServer::Command::SaveTemplateFile;
use TestDbServer::Command::CreateTemplateFromDatabase;
use TestDbServer::Command::CreateDatabase;

plan tests => 3;

subtest 'save template file' => sub {
    plan tests => 5;

    my $tmpdir = File::Temp::tempdir();
    my $app = FakeApp->new();

    my $upload = new_upload( my $file_name = File::Temp::tmpnam(),
                             my $file_contents = "This is the test contents\n");

    my $file_storage = TestDbServer::FileStorage->new(base_path => $tmpdir, app => $app);
    my $schema = new_schema();

    my $command = TestDbServer::Command::SaveTemplateFile->new(
                        name => $file_name,
                        owner => 'bob',
                        note => 'test note',
                        upload => $upload,
                        schema => $schema,
                        file_storage => $file_storage,
                    );
    ok($command, 'new');
    ok(my $template_id = $command->execute(), 'execute');

    my $template = $schema->find_template($template_id);
    ok($template, 'get created template');
    my $template_file_path = join('/', $tmpdir, $template->file_path);
    ok(-f $template_file_path, 'Uploaded file exists');

    do {
        local $/;
        open(my $fh, '<', $template_file_path);
        my $content = <$fh>;
        is($content, $file_contents, 'File contents');
    };
};

subtest 'create template from database' => sub {
    plan tests => 6;

    my $app = FakeApp->new();
    my $pg = new_pg_instance();

    my $schema = new_schema();
    my $base_template_name = File::Temp::tmpnam();

    my $base_template = $schema->create_template(name => $base_template_name,
                                                 file_path => '/dev/null',
                                                 owner => $base_template_name );
    my $database = $schema->create_database(template_id => $base_template->template_id,
                                            map { $_ => $pg->$_ } qw( host port name owner ) );
    # Make a table in the database
    my $table_name = "test_table_$$";
    my $dbi = DBI->connect(sprintf('dbi:Pg:dbname=%s;host=%s;port=%s',
                                    $pg->name, $pg->host, $pg->port),
                            $pg->owner,
                            '');
    ok($dbi->do("CREATE TABLE $table_name (foo integer NOT NULL PRIMARY KEY)"),
        'Create table in base database');

    my $new_template_name = File::Temp::tmpnam();
    my $tmpdir = File::Temp::tempdir();
    my $file_storage = TestDbServer::FileStorage->new(base_path => $tmpdir, app => $app);

    my $cmd = TestDbServer::Command::CreateTemplateFromDatabase->new(
                    name => $new_template_name,
                    note => 'new template from database',
                    database_id => $database->database_id,
                    schema => $schema,
                    file_storage => $file_storage,
                );
    ok($cmd, 'new');
    my $template_id = $cmd->execute();
    ok($template_id, 'execute');

    my $template = $schema->find_template($template_id);
    ok($template, 'get created template');
    my $template_file_path = join('/', $tmpdir, $template->file_path);
    ok(-f $template_file_path, 'Uploaded file exists');

    do {
        local $/;
        open(my $fh, '<', $template_file_path);
        my $content = <$fh>;
        like($content, qr(CREATE TABLE $table_name), 'File contents');
    };

    $dbi->disconnect;
    $pg->dropdb;
};

subtest 'create database' => sub {
    plan tests => 6;

    my $schema = new_schema();

    # blank database
    my $create_blank_db_cmd = TestDbServer::Command::CreateDatabase->new(
                                host => pg_host(),
                                port => pg_port(),
                                owner => pg_owner(),
                                superuser => pg_superuser(),
                                template_id => undef,
                                schema => $schema,
                            );
    ok($create_blank_db_cmd, 'new - blank db');
    my $blank_db = $create_blank_db_cmd->execute();
    ok($blank_db->database_id, 'execute - blank db');

    my $blank_pg = TestDbServer::PostgresInstance->new(
                                host => $blank_db->host,
                                port => $blank_db->port,
                                name => $blank_db->name,
                                owner => $blank_db->owner,
                        );
    ok($blank_pg->dropdb, 'drop blank db');


    # with a template ID
    my $template = $schema->create_template(
                                name => 'foo',
                                owner => pg_owner(),
                                file_path => '/dev/null',
                            );
    my $create_db_cmd = TestDbServer::Command::CreateDatabase->new(
                                host => pg_host(),
                                port => pg_port(),
                                owner => pg_owner(),
                                superuser => pg_superuser(),
                                template_id => $template->template_id,
                                schema => $schema,
                            );
    ok($create_db_cmd, 'new - create with template');
    my $db = $create_db_cmd->execute();
    ok($db, 'execute - with template');

    my $db_pg =  TestDbServer::PostgresInstance->new(
                                host => $db->host,
                                port => $db->port,
                                name => $db->name,
                                owner => $db->owner,
                        );
    ok($db_pg->dropdb, 'drop db');
};

sub new_upload {
    my($name, $contents) = @_;

    my $asset = Mojo::Asset::Memory->new()->add_chunk($contents);

    return Mojo::Upload->new()
                        ->asset($asset)
                        ->filename($name);
}

sub pg_host { 'localhost' }
sub pg_port { 5434 }
sub pg_owner { 'genome' }
sub pg_superuser { 'postgres' }

sub new_pg_instance {
    my $pg = TestDbServer::PostgresInstance->new(
            host => pg_host(),
            port => pg_port(),
            owner => pg_owner(),
            superuser => pg_superuser(),
        );
    $pg->createdb();
    return $pg;
}


sub new_schema {
    my $app = FakeApp->new();
    TestDbServer::Schema->initialize($app);
    
    my(undef,$sqlite_file) = File::Temp::tempfile('command_t_XXXX', SUFFIX => '.sqlite3', UNLINK => 1);
    return TestDbServer::Schema->connect("dbi:SQLite:dbname=$sqlite_file", '','');
}
