package TestDbServer::Command::SaveTemplateFile;

use File::Basename;
use Try::Tiny;

use Moose;

has name => ( isa => 'Str', is => 'ro', required => 1 );
has owner => ( isa => 'Str', is => 'ro', required => 1 );
has note => ( isa => 'Maybe[Str]', is => 'ro', required => 1 );
has upload => ( isa => 'Mojo::Upload', is => 'ro', required => 1 );
has schema => ( isa => 'TestDbServer::Schema', is => 'ro', required => 1 );

no Moose;


sub execute {
    my $self = shift;

    my $template = $self->schema->create_template(
                                        name => $self->name,
                                        owner => $self->owner,
                                        note => $self->note,
                                        sql_script => $self->upload->slurp,
                                    );
    my $template_id = $template->template_id;
    return $template_id;
}

1;
