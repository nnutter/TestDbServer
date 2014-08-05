package TestDbServer::Command::CreateDatabaseFromTemplate;

use TestDbServer::PostgresInstance;
use TestDbServer::Command::CreateDatabase;
use TestDbServer::Exceptions;

use Moose;

extends 'TestDbServer::Command::CreateDatabase';

has '+template_id' => ( isa => 'Str', is => 'ro', required => 1 );
has '+owner' => ( isa => 'Maybe[Str]', is => 'ro', required => 0 );
has 'file_storage' => ( isa => 'TestDbServer::FileStorage', is => 'ro', required => 1 );

no Moose;

sub BUILDARGS {
    my($class, %params) = @_;
    # if no owner specified, get it from the template
    unless ($params{owner} || $params{template_id}) {
        Exception::RequiredParamMissing->throw(error => 'owner or template_id is required',
                                                params => ['owner','template_id']);
    }

    unless ($params{owner}) {
        my $template = $params{schema}->find_template($params{template_id});
        $params{owner} = $template->owner if $template;
    }
    return \%params;
}

sub execute {
    my $self = shift;

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
                        owner => $self->owner || $database->owner,
                        superuser => $self->superuser,
                    );

    $pg->importdb($pathname);

    return $database;
}

1;
