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

1;
