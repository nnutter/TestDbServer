use Mojo::Base -strict;

use Test::More;
use Mojo::Upload;
use Mojo::Asset::Memory;

use File::Temp;

use TestDbServer::FileStorage;
use TestDbServer::Schema;
use lib 't/lib';
use FakeApp;

use TestDbServer::Command::SaveTemplateFile;

plan tests => 1;

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

sub new_upload {
    my($name, $contents) = @_;

    my $asset = Mojo::Asset::Memory->new()->add_chunk($contents);

    return Mojo::Upload->new()
                        ->asset($asset)
                        ->filename($name);
}

sub new_schema {
    my $app = FakeApp->new();
    TestDbServer::Schema->initialize($app);
    
    my(undef,$sqlite_file) = File::Temp::tempfile('command_t_XXXX', SUFFIX => '.sqlite3', UNLINK => 1);
    return TestDbServer::Schema->connect("dbi:SQLite:dbname=$sqlite_file", '','');
}
