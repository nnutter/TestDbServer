use strict;
use warnings;

use Mojo::Base -strict;

use Test::More;
use Test::Exception;
use File::Temp;
use File::Spec;
use File::Basename;
use IO::File;

use Mojo::Upload;
use Mojo::Asset::File;

use lib 't/lib';
use FakeApp;

use TestDbServer::FileStorage;

plan tests => 3;

subtest 'create' => sub {
    plan tests => 6;

    my $fake_app = FakeApp->new();

    my $restrictive_dir = File::Temp::tempdir( CLEANUP => 1 );
    chmod 0000, $restrictive_dir;
    my $restrictive_base_path = File::Spec->catfile($restrictive_dir, 'foo');
    throws_ok { TestDbServer::FileStorage->new(base_path => $restrictive_base_path, app => $fake_app) }
        'Exception::CannotMakeDirectory',
        'Caught CannotMakeDirectory';

    my $permissive_dir = File::Temp::tempdir( CLEANUP => 1 );
    my $store = TestDbServer::FileStorage->new(base_path => $permissive_dir, app => $fake_app);
    ok($store, 'Create FileStorage with exising dir');
    ok(-d $permissive_dir, 'Directory still exists');

    my $permissive_parent_dir = File::Temp::tempdir( CLEANUP => 1 );
    my $permissive_base_path = File::Spec->catfile($permissive_parent_dir, 'foo');
    ok(! -d $permissive_base_path, 'Path does not exist yet');
    $store = TestDbServer::FileStorage->new(base_path => $permissive_base_path, app => $fake_app);
    ok($store, 'Create FileStorage with new dir');
    ok(-d $permissive_base_path, 'Path now exists');
};

my $UPLOAD_FILE_CONTENTS = "stuff\n";
subtest 'save file' => sub {
    plan tests => 5;

    my $fake_app = FakeApp->new();
    my $base_dir = File::Temp::tempdir( CLEANUP => 1 );

    my $store = TestDbServer::FileStorage->new(base_path => $base_dir, app => $fake_app);

    my $upload = new_upload();
    my $name = $store->save_upload($upload);
    ok($name, 'save_upload');
    ok(-f File::Spec->catfile($base_dir, $name), 'File exists in storage directory');
    ok(-f $store->path_for_name($name), 'path_for_name() file exists');

    my $data = do {
        local $/;
        my $fh = IO::File->new($store->path_for_name($name));
        <$fh>;
    };
    is($data, $UPLOAD_FILE_CONTENTS, 'file contents');


    throws_ok { $store->save_upload($upload) }
        'Exception::FileExists',
        'Cannot save another file with the same name';
};

subtest 'open file' => sub {
    plan tests => 3;

    my $fake_app = FakeApp->new();
    my $base_dir = File::Temp::tempdir( CLEANUP => 1 );

    my $store = TestDbServer::FileStorage->new(base_path => $base_dir, app => $fake_app);

    my $upload = new_upload();
    my $name = $upload->filename;
    $store->save_upload($upload);

    my $fh = $store->open_file($name);
    ok($fh, 'open_file');

    my $contents = do {
        local $/;
        <$fh>;
    };
    is($contents, $UPLOAD_FILE_CONTENTS, 'file contents');

    throws_ok { $store->open_file('garbage') }
        'Exception::CannotOpenFile',
        'Cannot open non-existant file';
};

sub new_upload {
    my $asset = Mojo::Asset::File->new();
    $asset->add_chunk($UPLOAD_FILE_CONTENTS);

    my $upload = Mojo::Upload->new();
    my $filename = File::Basename::basename(scalar(File::Temp::tmpnam));
    $upload->filename($filename);
    $upload->asset($asset);

    return $upload;
}

