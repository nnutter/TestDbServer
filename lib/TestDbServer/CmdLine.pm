package TestDbServer::CmdLine;

# helpers for the command-line tools

use File::Spec;
use File::Basename;
use LWP;
use Carp;
use URI::Escape qw(uri_escape);

use strict;
use warnings;

use Exporter 'import';
our @EXPORT_OK = qw(make_user_agent url_for assert_success);

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

sub make_user_agent {
    my $ua = LWP::UserAgent->new;
    $ua->agent("TestDbServer::CmdLine/0.1 ");
    return $ua;
}

sub base_url {
    return $ENV{TESTDBSERVER_URL} || 'http://localhost';
}

sub url_for {
    my $query_string;
    if (ref($_[$#_])) {
        my $query_list = pop @_;
        my @query_list = map { uri_escape($_) } @$query_list;

        my @query_strings;
        for(my $i = 0; $i < @query_list; $i+=2) {
            push @query_strings, join('=', @query_list[$i, $i+1]);
        }
        $query_string = join('&', @query_strings);
    }

    my $url = join('/', base_url(), @_);
    if ($query_string) {
        $url .= '?' . $query_string;
    }
    return $url;
}

sub assert_success {
    my $rsp = shift;
    unless (ref($rsp) && $rsp->isa('HTTP::Response')) {
        Carp::croak("Expected an HTTP::Response instance, but got " . ref($rsp) || $rsp);
    }

    unless ($rsp->is_success) {
        Carp::croak('Got error response '.$rsp->code . ': '. $rsp->message);
    }
    return 1;
}


1;

    
