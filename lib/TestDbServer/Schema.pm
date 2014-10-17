package TestDbServer::Schema;
use parent 'DBIx::Class::Schema';

use TestDbServer::Exceptions;
use strict;
use warnings;

__PACKAGE__->load_namespaces();

{
    my $MOJO_LOGGER;

    sub initialize {
        my $class = shift;
        my $app = shift;

        $app || Exception::RequiredParamMissing->throw(
                    error => __PACKAGE__ . '->initialize() requires a Mojolicious app object as a parameter',
                    params => [q($_[0])],
                );

        $MOJO_LOGGER = $app->log;
    }

    sub log {
        return $MOJO_LOGGER;
    }
}

sub connect {
    my $class = shift;

    $class->log || Exception::NotInitialized->throw( error => 'initialized() was not called' );

    my $self = $class->SUPER::connect(@_);
    return $self;
}

# create_database(), search_database(), find_database(), delete_database()
# create_template() search_template(), find_template(), delete_template
sub _resultset_type_from_type { join('', map { ucfirst $_ } split('_', $_[0])); }
foreach my $type ( qw( database template ) ) {
    _sub_creator($type, 'create');
    _sub_creator($type, 'search');

    my $resultset_type = _resultset_type_from_type($type);
    my $find_sub = sub {
        my $self = shift;
        $self->resultset($resultset_type)->find(@_);
    };
    my $find_name = "find_${type}";

    my $delete_sub = sub {
        my($self, $id) = @_;
        $self->$find_name($id)->delete();
    };
    my $delete_name = "delete_${type}";

    do {
        no strict 'refs';
        *$find_name = $find_sub;
        *$delete_name = $delete_sub;
    };
}    

sub _sub_creator {
    my $entity_type = shift;
    my $resultset_method = shift;

    my $resultset_type = _resultset_type_from_type($entity_type);

    my $sub = sub {
        my $self = shift;
        my %params = @_;
        $self->resultset($resultset_type)->$resultset_method(\%params);
    };

    my $method_name = "${resultset_method}_${entity_type}";
    do { no strict 'refs';
        *$method_name = $sub;
    };
}
        
sub sql_to_update_expire_column {
    my($self, $ttl) = @_;

    "now() + interval '$ttl second'"; # PostgreSQL
}

sub sql_to_update_last_used_column {
    my $self = shift;
    'now()'; # PostgreSQL
}

sub search_expired_databases {
    my $self = shift;

    my $criteria = 'now()';

    return $self->resultset('Database')->search({ expire_time => { '<' => \$criteria }});
}
 
1;
