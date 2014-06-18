use TestDbServer::Exceptions;
use File::Basename;
use File::Spec;
use IO::File;

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

    my $base_name = File::Basename::basename($upload->filename);

    my $stored_filename = $self->path_for_name($base_name);
    if (-f $stored_filename) {
        Exception::FileExists->throw(path => $stored_filename);
    }

    $upload->move_to($stored_filename);

    return $base_name;
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


1;
