package TestDbServer::Info;
use Mojo::Base 'Mojolicious::Controller';

# This action will render a template
sub root {
    my $self = shift;

    $self->app->log->debug('Getting server info');
    my $templates = $self->app->db_storage->search_template();
    my $databases = $self->app->db_storage->search_database();

    $self->render(json =>
        {
            template_count => $templates->count,
            database_count => $databases->count,
            file_path      => $self->app->configuration->file_storage_path,
        }
    );
}

1;
