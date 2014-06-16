package TestDbServer::DbStorage;

use Moose;

has app => (
    is => 'ro',
    isa => 'TestDbServer',
    required => 1,
);
has dbh => (
    is => 'rw',
    isa => 'DBI::db',
    lazy => 1,
    lazy_build => 1,
);

1;
