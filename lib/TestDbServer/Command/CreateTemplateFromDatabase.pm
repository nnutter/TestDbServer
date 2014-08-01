package TestDbServer::Command::CreateTemplateFromDatabase;

use File::Temp;
use TestDbServer::PostgresInstance;

use Moose;

has name => ( isa => 'Str', is => 'ro', required => 1 );
has note => ( isa => 'Maybe[Str]', is => 'ro', required => 1 );
has database_id => ( isa => 'Str', is => 'ro', required => 1 );
has schema => ( isa => 'TestDbServer::Schema', is => 'ro', required => 1 );
has file_storage => ( isa => 'TestDbServer::FileStorage', is => 'ro', required => 1 );

no Moose;

sub execute {
    my $self = shift;

    my $database = $self->schema->find_database($self->database_id);
    unless ($database) {
        Exception::DatabaseNotFound->throw(database_id => $self->database_id);
    }

    my $pg = TestDbServer::PostgresInstance->new(
                    host => $database->host,
                    port => $database->port,
                    owner => $database->owner,
                    name => $database->name,
                );

    my(undef, $dump_file) = File::Temp::tempfile(TEMPLATE => 'dump_' . $self->database_id . '_XXXX',
                                                 SUFFIX => '.sql');
    $pg->exportdb($dump_file);

    my $template = $self->schema->create_template(
                                name => $self->name,
                                note => $self->note,
                                owner => $database->owner,
                                file_path => $dump_file,
                            );
    $self->file_storage->save($dump_file);

    return $template->template_id;
}

1;
