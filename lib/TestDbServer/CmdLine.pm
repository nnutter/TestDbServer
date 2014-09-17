package TestDbServer::CmdLine;

# helpers for the command-line tools

use File::Spec;
use File::Basename;

use strict;
use warnings;

sub find_available_sub_command_paths {
    my($cmd) = shift;

    return  grep { -x }
            glob("${cmd}-*");
}

sub split_into_command_to_run_and_args {
    my($base_command_path, @argv) = @_;

    for( my $split_pos = $#argv; $split_pos >= 0; $split_pos-- ) {
        my $command_to_run = join('-', $base_command_path, @argv[0 .. $split_pos]);

        if (-x $command_to_run) {
            my @args_for_command = @argv[$split_pos+1 .. $#argv];
            return ($command_to_run, @args_for_command);
        }
    }
    return ($base_command_path, @argv);
}

1;

    
