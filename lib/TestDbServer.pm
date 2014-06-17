use TestDbServer::Schema;

package TestDbServer;

use Moose;
use MooseX::NonMoose;
extends 'Mojolicious';

has db_storage => (
    is => 'ro',
    isa => 'TestDbServer::Schema',
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

    $r->get('/templates')->to('template_routes#list');
    $r->get('/templates/:id')->to('template_routes#get');
    $r->put('/templates/:id')->to('template_routes#save');
    $r->delete('/templates/:id')->to('template_routes#delete');

    $r->get('/databases')->to('database_routes#list');
    $r->post('/databases')->to('database_routes#create');
    $r->get('/databases/:id')->to('database_routes#get');
    $r->patch('/databases/:id')->to('database_routes#patch');
    $r->delete('/databases/:id')->to('database_routes#delete');
}

sub _build_db_storage {
    my $self = shift;

    TestDbServer::Schema->initialize($self);

    my $config = $self->plugin('Config');

    my $test_connect_string;
    if ($self->mode eq 'test_harness') {
        require File::Temp;
        my $temp_file = File::Temp->new(TEMPLATE => 'testdbserver_testdb_XXXXX', SUFFIX => 'sqlite3');
        $test_connect_string = 'dbi:SQLite:' . $temp_file->filename;
        $self->{__temp_db_file__} = $temp_file;

    }

    return TestDbServer::Schema->connect(
                $test_connect_string || $config->{db_connect_string},
                $config->{db_user},
                $config->{db_password},
            );
}

sub _build_file_storage {
    my $self = shift;

#    my $storage = TestDbServer::FileStorage->new($self);
}

1;
