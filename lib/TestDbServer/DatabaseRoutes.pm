package TestDbServer::DatabaseRoutes;
use Mojo::Base 'Mojolicious::Controller';

use Try::Tiny;

use TestDbServer::Utils;
use TestDbServer::Command::CreateDatabaseFromTemplate;
use TestDbServer::Command::DeleteDatabase;

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

    } elsif (my $owner = $self->req->param('owner')) {
        $self->_create_new_database($owner);

    } else {
        $self->render_not_found;
    }
}

sub _create_new_database {
    my($self, $owner) = @_;

    $self->_create_database_common(sub {
            my($host, $port) = $self->app->host_and_port_for_created_database();
            my $cmd = TestDbServer::Command::CreateDatabase->new(
                            owner => $owner,
                            template_id => undef,
                            host => $host,
                            port => $port,
                            superuser => $self->app->configuration->db_user,
                            file_storage => $self->app->file_storage,
                            schema => $self->app->db_storage,
                    );
        });
}

sub _create_database_from_template {
    my($self, $template_id) = @_;

    $self->_create_database_common(sub {
            my($host, $port) = $self->app->host_and_port_for_created_database();
            TestDbServer::Command::CreateDatabaseFromTemplate->new(
                            template_id => $template_id,
                            host => $host,
                            port => $port,
                            superuser => $self->app->configuration->db_user,
                            file_storage => $self->app->file_storage,
                            schema => $self->app->db_storage,
                    );
        });
}

sub _create_database_common {
    my($self, $cmd_creator_sub) = @_;

    my $schema = $self->app->db_storage;

    my($database, $return_code);
    try {
        $schema->txn_do(sub {
            my $cmd = $cmd_creator_sub->();
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
        my $response_location = TestDbServer::Utils::id_url_for_request_and_entity_id($self->req, $database->database_id);
        $self->res->headers->location($response_location);

        my %resp;
        @resp{'id','host','port','name','owner','expires'}
            = map { $database->$_ } qw(database_id host port name owner expire_time);

        $self->render(json => \%resp, status => 201);

    } else {
        $self->rendered($return_code);
    }
}

sub delete {
    my $self = shift;
    my $id = $self->stash('id');

    my $schema = $self->app->db_storage;
    my $return_code;
    try {
        my $cmd = TestDbServer::Command::DeleteDatabase->new(
                        database_id => $id,
                        schema => $schema,
                    );
        $schema->txn_do(sub {
            $cmd->execute();
            $return_code = 204;
        });
    }
    catch {
        if (ref($_) && $_->isa('Exception::DatabaseNotFound')) {
            $return_code = 404;
        } elsif (ref($_) && $_->isa('Exception::CannotDropDatabase')) {
            $return_code = 409;
        } else {
            $self->app->log->error("delete database: $_");
            die $_;
        }
    };

    $self->rendered($return_code);
}

1;
