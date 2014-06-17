package TestDbServer::Schema::ResultBase;

use strict;
use warnings;

use parent 'DBIx::Class::Core';

sub _create_table_sql_getter {
    my($class, $dbh) = @_;

    my $driver = $dbh->{Driver}->{Name};
    return "_create_table_sql_$driver";
}

sub _create_table {
    my $class = shift;
    my $schema = shift;

    my $storage = $schema->storage;

    $storage->dbh_do(sub {
        my($storage, $dbh, @cols) = @_;

        my $getter = $class->_create_table_sql_getter($dbh);
        my $sql = $class->$getter();

        $dbh->do($sql);
    });
}

1;
