package TestDbServer::Info;
use Mojo::Base 'Mojolicious::Controller';

# This action will render a template
sub root {
    my $self = shift;

    $self->app->log->debug('Getting server info');
    my $storage = $self->app->db_storage();

    $self->render(json =>
        {
            template_count => $storage->count_templates,
            database_count => $storage->count_databases,
            file_path      => $self->app->file_storage_path,
        }
    );
}

1;
