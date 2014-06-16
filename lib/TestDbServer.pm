package TestDbServer;

use Moose;
use MooseX::NonMoose;
extends 'Mojolicious';

has db_storage => (
    is => 'ro',
    isa => 'TestDbServer::DbStorage',
    lazy_build => 1,
);
has file_storage => (
    is => 'ro',
    isa => 'TestDbServer::FileStorage',
    lazy_build => 1,
);
has file_storage_path => (
    is => 'ro',
    isa => 'Str',
    default => '/home/archive/test-db-server-templates',
);

# This method will run once at server start
sub startup {
    my $self = shift;

    $self->_setup_routes();
}

sub _setup_routes {
    my $self = shift;

    my $r = $self->routes;

    # Normal route to controller
    $r->get('/')->to('info#root');
}

sub _build_db_storage {
    my $self = shift;

    my $storage;
    if ($self->mode eq 'development') {
        require TestDbServer::DbStorage::SQLite;
        $storage = TestDbServer::DbStorage::SQLite->new(app => $self);
    } else {
        Carp::croak('Unknown run mode ',$self->mode);
    }
    return $storage;
}

sub _build_file_storage {
    my $self = shift;

#    my $storage = TestDbServer::FileStorage->new($self);
}

1;
