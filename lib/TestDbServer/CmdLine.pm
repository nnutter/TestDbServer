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

1;

    
