use App::Info::RDBMS::PostgreSQL;
use Data::UUID;

use TestDbServer::Exceptions;

package TestDbServer::PostgresInstance;

use Moose;

has 'host' => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);
has 'port' => (
    is => 'ro',
    isa => 'Int',
    required => 1,
);
has 'owner' => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);
has 'superuser' => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);
has 'name' => (
    is => 'ro',
    isa => 'Str',
    lazy_build => 1,
);
{
    my $app_pg = App::Info::RDBMS::PostgreSQL->new();
    sub app_pg { return $app_pg }
}

sub createdb {
    my $self = shift;

    my $createdb = $self->app_pg->createdb;

    my $host = $self->host;
    my $port = $self->port;
    my $owner = $self->owner;
    my $superuser = $self->superuser;
    my $name = $self->name;

    my $output = `$createdb -h $host -p $port -U $superuser -O $owner $name 2>&1`;
    if ($? != 0) {
        Exception::CannotCreateDatabase->throw(error => "$createdb failed", output => $output, exit_code => $?);
    }
    return 1;
}

my $uuid_gen = Data::UUID->new();
sub _build_name {
    my $class = shift;
    my $hex = $uuid_gen->create_hex();
    $hex =~ s/^0x//;
    return $hex;
}

sub dropdb {
    my $self = shift;
    my $dropdb = $self->app_pg->dropdb;

    my $host = $self->host;
    my $port = $self->port;
    my $owner = $self->owner;
    my $name = $self->name;

    my $output = `$dropdb -h $host -p $port -U $owner $name 2>&1`;
    if ($? != 0) {
        Exception::CannotDropDatabase->throw(error => "$dropdb failed", output => $output, exit_code => $?);
    }
    return 1;
}

1;
