package TestDbServer::DatabaseRoutes;
use Mojo::Base 'Mojolicious::Controller';

use Try::Tiny;

use TestDbServer::Command::CreateDatabaseFromTemplate;

sub list {
    my $self = shift;

    my $databases = $self->app->db_storage->search_database;
    my @ids;
    while (my $db = $databases->next) {
        push @ids, $db->database_id;
    }
    $self->render(json => \@ids);
}

sub get {
    my $self = shift;
    my $id = $self->stash('id');

    my $schema = $self->app->db_storage();
    my $database = $schema->find_database($id);
    if ($database) {
        my %database = map { $_ => $database->$_ } qw( database_id host port name owner create_time expire_time template_id );
        $self->render(json => \%database);
    } else {
        $self->render_not_found;
    }
}

sub create {
    my $self = shift;

    if (my $template_id = $self->req->param('based_on')) {
        $self->_create_database_from_template($template_id);

    } else {
        $self->render_not_found;
    }
}

sub _create_database_from_template {
    my($self, $template_id) = @_;

    my $schema = $self->app->db_storage;

    my($database, $return_code);
    try {
        $schema->txn_do(sub {
            my($host, $port) = $self->app->host_and_port_for_created_database();

            my $cmd = TestDbServer::Command::CreateDatabaseFromTemplate->new(
                            template_id => $template_id,
                            host => $host,
                            port => $port,
                            superuser => $self->app->configuration->db_user,
                            file_storage => $self->app->file_storage,
                            schema => $schema,
                    );
            $database = $cmd->execute();
        });
    }
    catch {
        if (ref($_)
                && ( $_->isa('Exception::TemplateNotFound') || $_->isa('Exception::CannotOpenFile'))
        ) {
            $return_code = 404;

        } else {
            $self->app->log->error("_create_database_from_template: $_");
            die $_;
        }
    };

    if ($database) {
        my $response_location = join('/', $self->req->url, $database->database_id);
        $self->res->headers->location($response_location);

        my %resp;
        @resp{'id','host','port','name','owner','expires'}
            = map { $database->$_ } qw(database_id host port name owner expire_time);

        $self->render(json => \%resp, status => 201);

    } else {
        $self->rendered($return_code);
    }
}

1;
