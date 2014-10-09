package TestDbServer::Command::CreateTemplateFromDatabase;

use File::Temp;
use TestDbServer::PostgresInstance;

use Moose;
use namespace::autoclean;

has name => ( isa => 'Str', is => 'ro', required => 1 );
has note => ( isa => 'Maybe[Str]', is => 'ro', required => 1 );
has database_id => ( isa => 'Str', is => 'ro', required => 1 );
has schema => ( isa => 'TestDbServer::Schema', is => 'ro', required => 1 );
has superuser => ( isa => 'Str', is => 'ro', required => 1 );

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
                    superuser => $self->superuser,
                );

    my $dump_fh = File::Temp->new(TEMPLATE => 'dump_' . $self->database_id . '_XXXX',
                                    SUFFIX => '.sql',
                                    TMPDIR => 1);
    $dump_fh->close();

    $pg->exportdb($dump_fh->filename);

    my $sql_script = do {
        local $/;
        open my $fh, '<', $dump_fh;
        unless ($fh) {
            Exception::CannotOpenFile->throw(error => $!, path => $dump_fh->filename);
        }
        <$fh>;
    };

    my $template = $self->schema->create_template(
                                name => $self->name,
                                note => $self->note,
                                owner => $database->owner,
                                sql_script => $sql_script,
                            );

    return $template->template_id;
}

__PACKAGE__->meta->make_immutable;

1;
