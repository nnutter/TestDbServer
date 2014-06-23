package FakeApp;
use parent 'TestDbServer';

# Mimics the Mojo base application class for some tests that need it

sub new {
    my $class = shift;

    my $logger = FakeApp::Logger->new();
    my $self = { logger => $logger };
    return bless $self, $class;
}

sub log {
    return shift->{logger};
}

package FakeApp::Logger;

sub new {
    my $class = shift;
    return bless {}, $class;
}

sub AUTOLOAD {
    my $self = shift;
    $self->{$AUTOLOAD} ||= [];
    push @{ $self->{$AUTOLOAD} }, @_;
}

1;
