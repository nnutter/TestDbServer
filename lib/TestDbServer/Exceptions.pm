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

    # For some reason, we can't call it Exception::DB.  When we go
    # to throw() one of the derived classes, it complains
    # Can't locate object method "throw" via package "Exception::DB"
    Exception::Database => {
        isa => 'Exception::BaseException',
        description => 'Database exception',
        fields => ['sql'],
    },
    Exception::DB::CreateTable => {
        isa => 'Exception::Database',
        fields => ['table_name'],
    },
    Exception::DB::Select => {
        isa => 'Exception::Database',
    },
    Exception::DB::Select::Prepare => {
        isa => 'Exception::DB::Select',
    },
    Exception::DB::Select::Execute => {
        isa => 'Exception::DB::Select',
    },
    Exception::DB::Insert => {
        isa => 'Exception::Database',
    },
    Exception::DB::Insert::Prepare => {
        isa => 'Exception::DB::Insert',
    },
    Exception::DB::Insert::Execute => {
        isa => 'Exception::DB::Insert',
    },
    Exception::DB::Update => {
        isa => 'Exception::Database',
    },
    Exception::DB::Update::Prepare => {
        isa => 'Exception::DB::Update',
    },
    Exception::DB::Update::Execute => {
        isa => 'Exception::DB::Update',
    },
    Exception::DB::Delete => {
        isa => 'Exception::Database',
    },
    Exception::DB::Delete::Prepare => {
        isa => 'Exception::DB::Delete',
    },
    Exception::DB::Delete::Execute => {
        isa => 'Exception::DB::Delete',
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
