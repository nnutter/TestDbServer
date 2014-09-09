use Mojo::Base -strict;

use Test::More;
use Test::Exception;
use Mojo::Upload;
use Mojo::Asset::Memory;

use File::Temp;

use TestDbServer::Schema;
use TestDbServer::PostgresInstance;
use lib 't/lib';
use FakeApp;
use DBI;

use TestDbServer::Command::SaveTemplateFile;
use TestDbServer::Command::CreateTemplateFromDatabase;
use TestDbServer::Command::CreateDatabase;
use TestDbServer::Command::CreateDatabaseFromTemplate;
use TestDbServer::Command::DeleteTemplate;
use TestDbServer::Command::DeleteDatabase;

plan tests => 7;

subtest 'save template file' => sub {
    plan tests => 4;

    my $upload = new_upload( my $file_name = File::Temp::tmpnam(),
                             my $file_contents = "This is the test contents\n");

    my $schema = new_schema();

    my $command = TestDbServer::Command::SaveTemplateFile->new(
                        name => $file_name,
                        owner => 'bob',
                        note => 'test note',
                        upload => $upload,
                        schema => $schema,
                    );
    ok($command, 'new');
    ok(my $template_id = $command->execute(), 'execute');

    my $template = $schema->find_template($template_id);
    ok($template, 'get created template');

    is($template->sql_script, $file_contents, 'SQL script');
};

subtest 'create template from database' => sub {
    plan tests => 5;

    my $app = FakeApp->new();
    my $pg = new_pg_instance();

    my $schema = new_schema();
    my $base_template_name = File::Temp::tmpnam();

    my $base_template = $schema->create_template(name => $base_template_name,
                                                 sql_script => '',
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

    my $cmd = TestDbServer::Command::CreateTemplateFromDatabase->new(
                    name => $new_template_name,
                    note => 'new template from database',
                    database_id => $database->database_id,
                    schema => $schema,
                );
    ok($cmd, 'new');
    my $template_id = $cmd->execute();
    ok($template_id, 'execute');

    my $template = $schema->find_template($template_id);
    ok($template, 'get created template');

    like($template->sql_script, qr(CREATE TABLE $table_name), 'Template sql script');

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
                                sql_script => '',
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

subtest 'create database from template' => sub {
    plan tests => 6;

    my $schema = new_schema();

    my $sql_script = 'CREATE TABLE foo(foo_id integer NOT NULL PRIMARY KEY)';

    my $template = $schema->create_template(
                                name => 'foo',
                                owner => pg_owner(),
                                sql_script => $sql_script,
                            );

    my $cmd = TestDbServer::Command::CreateDatabaseFromTemplate->new(
                            host => pg_host(),
                            port => pg_port(),
                            superuser => pg_superuser(),
                            schema => $schema,
                            template_id => $template->template_id,
                        );
    ok($cmd, 'new');
    my $database = $cmd->execute();
    ok($database, 'execute');

    my $dbi = DBI->connect(sprintf('dbi:Pg:dbname=%s;host=%s;port=%s',
                                    $database->name, $database->host, $database->port),
                            $database->owner,
                            '',
                            { RaiseError => 1 });
    ok($dbi->do('select * from foo'), 'Table exists');
    $dbi->disconnect();

    my $db_pg =  TestDbServer::PostgresInstance->new(
                                host => $database->host,
                                port => $database->port,
                                name => $database->name,
                                owner => $database->owner,
                        );
    ok($db_pg->dropdb, 'drop db');

    throws_ok { TestDbServer::Command::CreateDatabaseFromTemplate->new(
                    host => pg_host(),
                    port => pg_port(),
                    superuser => pg_superuser(),
                    schema => $schema);
                }
        'Exception::RequiredParamMissing',
        'instantiation without owner and template_id fails';

    throws_ok { TestDbServer::Command::CreateDatabaseFromTemplate->new(
                    host => pg_host(),
                    port => pg_port(),
                    superuser => pg_superuser(),
                    schema => $schema,
                    template_id => 'bogus'
                  )->execute();
               }
        'Exception::TemplateNotFound',
        'instantiate with bogus template_id';
};

subtest 'delete template' => sub {
    plan tests => 4;

    my $upload = new_upload( my $file_name = File::Temp::tmpnam(),
                             my $file_contents = "This is the test contents\n");

    my $schema = new_schema();

    ok(my $template_id = TestDbServer::Command::SaveTemplateFile->new(
                name => $file_name,
                owner => 'bob',
                note => 'test note',
                upload => $upload,
                schema => $schema,
            )->execute(),
        'Create file to unlink');
    my $short_name = File::Basename::basename($file_name);

    my $cmd = TestDbServer::Command::DeleteTemplate->new(
                template_id => $template_id,
                schema => $schema);
    ok($cmd, 'new');
    ok($cmd->execute(), 'execute');

    ok(! $schema->find_template($template_id),
        'template is deleted');
};

subtest 'delete database' => sub {
    plan tests => 5;

    my $schema = new_schema();

    my $database = TestDbServer::Command::CreateDatabase->new(
                            host => pg_host(),
                            port => pg_port(),
                            owner => pg_owner(),
                            superuser => pg_superuser(),
                            template_id => undef,
                            schema => $schema,
                    )->execute();
    ok($database, 'Created database to delete');

    my $cmd = TestDbServer::Command::DeleteDatabase->new(
                            database_id => $database->database_id,
                            schema => $schema);
    ok($cmd, 'new delete database');
    ok($cmd->execute(), 'execute delete database');


    my $not_found_cmd = TestDbServer::Command::DeleteDatabase->new(
                            database_id => 'bogus',
                            schema => $schema);
    ok($cmd, 'new delete not existant');
    throws_ok { $cmd->execute() }
        'Exception::DatabaseNotFound',
        'Cannot delete unknown database';
};

subtest 'delete with connections' => sub {
    plan tests => 5;

    my $schema = new_schema();

    my $database = TestDbServer::Command::CreateDatabase->new(
                            host => pg_host(),
                            port => pg_port(),
                            owner => pg_owner(),
                            superuser => pg_superuser(),
                            template_id => undef,
                            schema => $schema,
                    )->execute();
    ok($database, 'Create database');
    my $dbh = DBI->connect(sprintf('dbi:Pg:dbname=%s;host=%s;port=%s',
                                    $database->name, $database->host, $database->port),
                            $database->owner,
                            '');
    ok($dbh, 'connect to created database');
    my $cmd = TestDbServer::Command::DeleteDatabase->new(
                                    database_id => $database->id,
                                    schema => $schema);
    ok($cmd, 'new');
    throws_ok { $cmd->execute() }
        'Exception::CannotDropDatabase',
        'cannot execute - has connections';

    $dbh->disconnect();
    ok($cmd->execute(), 'delete after disconnecting');
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

