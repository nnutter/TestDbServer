use Test::More tests => 2;
use File::Temp;
use File::Spec;

use TestDbServer::CmdLine qw(url_for);

subtest split_into_command_to_run_and_args => sub {
    # make some fake commands
    my $dir = File::Temp::tempdir( CLEANUP => 1 );
    foreach my $file ( qw(base base-foo base-foo-bar base-foo-bar-baz) ) {
        my $pathname = File::Spec->catfile($dir, $file);
        open my $fh, '>', $pathname;
        chmod 0755, $pathname;
    }

    my $base_command = "${dir}/base";
    my @tests = (
        ['foo'] => "${base_command}-foo", [],
        [qw(foo bar)] => "${base_command}-foo-bar", [],
        [qw(foo bar --arg1 --arg2)] => "${base_command}-foo-bar", [qw(--arg1 --arg2)],
        [qw(foo bar baz)] => "${base_command}-foo-bar-baz", [],
        [qw(foo baz)] => "${base_command}-foo", ['baz'],
        [qw(bob joe mike)] => $base_command, [qw(bob joe mike)],
        [qw(bob joe mike --arg1)] => $base_command, [qw(bob joe mike --arg1)],
    );
    plan tests => 2 * scalar(@tests) / 3;

    for(my $i = 0; $i < @tests; $i+=3) {
        my($argv, $expected_command_to_run, $expected_args_for_command) = @tests[$i .. $i+2];
        my($command_to_run, @args_for_command) = TestDbServer::CmdLine::split_into_command_to_run_and_args($base_command, @$argv);
        is($command_to_run, $expected_command_to_run, 'command '.$i/3);
        is_deeply(\@args_for_command, $expected_args_for_command, 'command args');
    }
};

subtest url_for => sub {
    plan tests => 3;

    my $base_url = local $ENV{TESTDBSERVER_URL} = 'http://test.url.example.com';
    is(url_for('templates'),
        "${base_url}/templates",
        'templates');

    is(url_for('templates',123),
        "${base_url}/templates/123",
        'templates/123');

    is(url_for('databases', 123, [owner => 'bob', foo => 'bar']),
        "${base_url}/databases/123?owner=bob&foo=bar",
        'url with query string');
};
