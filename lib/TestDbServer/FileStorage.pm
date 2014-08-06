use TestDbServer::Exceptions;
use File::Basename;
use File::Spec;
use IO::File;
use File::Copy;

package TestDbServer::FileStorage;

use Moose;

has base_path => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

has app => (
    is => 'ro',
    isa => 'TestDbServer',
    required => 1,
);

sub BUILD {
    my $self = shift;

    unless (-d $self->base_path) {
        $self->app->log->info('Creating base_path directory: ' . $self->base_path);
        mkdir($self->base_path)
            || Exception::CannotMakeDirectory->throw(error => $!, path => $self->base_path);
    }
}

sub save_upload {
    my($self, $upload) = @_;

    my $stored_filename = $self->_validate_saved_file($upload->filename);
    $upload->move_to($stored_filename);

    return File::Basename::basename($stored_filename);
}

sub save {
    my($self, $pathname) = @_;

    my $stored_filename = $self->_validate_saved_file($pathname);
    File::Copy::move($pathname, $stored_filename);

    return File::Basename::basename($stored_filename);
}

sub _validate_saved_file {
    my($self, $pathname) = @_;

    my $base_name = File::Basename::basename($pathname);

    my $stored_filename = $self->path_for_name($base_name);
    if (-f $stored_filename) {
        Exception::FileExists->throw(path => $stored_filename);
    }

    return $stored_filename;
}

sub path_for_name {
    my($self, $name) = @_;

    return File::Spec->catfile($self->base_path, $name);
}

sub open_file {
    my($self, $name) = @_;

    my $stored_filename = $self->path_for_name($name);
    my $fh = IO::File->new($stored_filename, 'r');
    $fh || Exception::CannotOpenFile->throw(error => $!, path => $stored_filename);

    return $fh;
}

sub unlink {
    my($self, $pathname) = @_;

    my $stored_filename = $self->path_for_name($pathname);
    unless (unlink $stored_filename) {
        Exception::CannotUnlinkFile->throw(error => $!, path => $stored_filename);
    }
    return 1;
}

1;
