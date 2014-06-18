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
