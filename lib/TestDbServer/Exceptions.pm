use Exception::Class (
    Exception::BaseException,

    Exception::RequiredParamMissing => {
        isa => 'Exception::BaseException',
        description => 'Required parameter is missing',
        fields => ['params'],
    },

    Exception::NotInitialized => {
        isa => 'Exception::BaseException',
    },

);

package Exception::BaseException;
use Carp;
our @CARP_NOT = qw( Test::Builder Exception::Class::Base );

sub full_message {
    my $self = shift;

    my $message = $self->SUPER::full_message(@_);
    return Carp::shortmess($message);
}

1;
