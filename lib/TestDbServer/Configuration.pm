package TestDbServer::Configuration;

use Moose;

has db_connect_string   => ( is => 'rw' );
has db_user             => ( is => 'rw' );
has db_password         => ( is => 'rw' );
has db_host             => ( is => 'rw' );
has db_port             => ( is => 'rw' );
has file_storage_path   => ( is => 'rw' );

sub new_from_app_config {
    my($class, $config) = @_;

    my $meta = $class->meta;
    my %props;
    foreach my $attr ( $meta->get_all_attributes ) {
        $props{$attr->name} = $config->{$attr->name};
    }

    return $class->SUPER::new(%props);
}

1;
