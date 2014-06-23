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

    Exception::CannotMakeDirectory => {
        isa => 'Exception::BaseException',
        fields => ['path'],
    },

    Exception::FileExists => {
        description => 'File exists',
        isa => 'Exception::BaseException',
        fields => ['path'],
    },

    Exception::CannotOpenFile => {
        isa => 'Exception::BaseException',
        fields => ['path'],
    },
);

package Exception::BaseException;

sub full_message {
    my $self = shift;

    my $class = ref($self);
    return "$class: " . $self->error . " at " . $self->_find_source_location();
}

sub _find_source_location {
    my $self = shift;

    my $frame = $self->trace->next_frame;

    my $fields_string = join("\n\t", map { "$_: " . $self->$_ } $self->Fields);
    my $message = $frame->filename . ': ' . $frame->line;
    $message .= "\n\t$fields_string\n" if length($fields_string);
    return $message;
}

1;
