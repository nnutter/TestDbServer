package TestDbServer::Command::CreateDatabaseFromTemplate;

use TestDbServer::PostgresInstance;
use TestDbServer::Command::CreateDatabase;
use TestDbServer::Exceptions;

use Moose;

extends 'TestDbServer::Command::CreateDatabase';

has '+template_id' => ( isa => 'Str', is => 'ro', required => 1 );
has 'file_storage' => ( isa => 'TestDbServer::FileStorage', is => 'ro', required => 1 );

no Moose;

sub execute {
    my $self = shift;

$DB::single=1;
    my $database = $self->SUPER::execute();

    my $template = $self->schema->find_template($self->template_id);
    unless ($template) {
        Exception::TemplateNotFound->throw(template_id => $self->template_id);
    }

    my $pathname = $self->file_storage->path_for_name($template->file_path);
    unless ($pathname and -f $pathname) {
        Exception::CannotOpenFile->throw(path => $pathname);
    }

    my $pg = TestDbServer::PostgresInstance->new(
                        name => $database->name,
                        host => $database->host,
                        port => $database->port,
                        owner => $database->owner,
                        superuser => $self->superuser,
                    );

    $pg->importdb($pathname);

    return $database;
}

1;
