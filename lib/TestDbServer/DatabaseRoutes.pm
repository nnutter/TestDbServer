package TestDbServer::DatabaseRoutes;
use Mojo::Base 'Mojolicious::Controller';

use Try::Tiny;

sub list {
    my $self = shift;

    my $databases = $self->app->db_storage->search_database;
    my @ids;
    while (my $db = $databases->next) {
        push @ids, $db->database_id;
    }
    $self->render(json => \@ids);
}

1;
