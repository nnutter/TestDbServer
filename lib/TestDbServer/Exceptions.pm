package Exception::RequiredParamMissing;
use Moose;
with 'Throwable';

has params => (
    is => 'ro',
    isa => 'ArrayRef[Str]',
);

1;
