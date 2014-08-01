package TestDbServer::Command::SaveTemplateFile;

use File::Basename;
use Try::Tiny;

use Moose;

has name => ( isa => 'Str', is => 'ro', required => 1 );
has owner => ( isa => 'Str', is => 'ro', required => 1 );
has note => ( isa => 'Maybe[Str]', is => 'ro', required => 1 );
has upload => ( isa => 'Mojo::Upload', is => 'ro', required => 1 );
has schema => ( isa => 'TestDbServer::Schema', is => 'ro', required => 1 );
has file_storage => ( isa => 'TestDbServer::FileStorage', is => 'ro', required => 1 );

no Moose;


sub execute {
    my $self = shift;

    my $upload_filename = File::Basename::basename($self->upload->filename);
    my $template_id;

    my $template = $self->schema->create_template(
                                        name => $self->name,
                                        owner => $self->owner,
                                        note => $self->note,
                                        file_path => $upload_filename,
                                    );
    $self->file_storage->save_upload($self->upload);
    $template_id = $template->template_id;
    return $template_id;
}

1;
