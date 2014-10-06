package TestDbServer::CommandLineRunner;

use IPC::Run;

use Moose;

has cmdline => (
    is => 'ro',
    isa => 'ArrayRef[Str]',
    required => 1,
);

has rv => (
    is => 'rw',
    isa => 'Bool',
    init_arg => undef
);

has child_error => (
    is => 'rw',
    isa => 'Int',
    init_arg => undef,
);

has output => (
    is => 'rw',
    isa => 'Str',
    init_arg => undef,
);

around BUILDARGS => sub {
    my $orig = shift;
    my $class = shift;
    my @cmdline = @_;
    return $class->$orig(cmdline => \@cmdline);
};

sub BUILD {
    my $self = shift;

    my $output = '';
    my $rv = IPC::Run::run($self->cmdline,
                           '>', \$output,
                           '2>', \$output,
                        );
    $self->child_error($?);
    $self->rv($rv);
    $self->output($output);
}

1;
