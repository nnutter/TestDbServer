use Test::More;

use TestDbServer::CommandLineRunner;

use strict;
use warnings;

plan tests => 3;

subtest 'simple command' => sub {
    plan tests => 4;

    my $expected_output = 'hello';
    my $runner = TestDbServer::CommandLineRunner->new('echo', $expected_output);
    ok($runner, 'Create CommandLineRunner for echo');
    ok($runner->rv, 'ran ok');
    is($runner->child_error, 0, 'child error');
    is($runner->output, "$expected_output\n", 'output');
};

subtest 'failing command' => sub {
    plan tests => 2;

    my $runner = TestDbServer::CommandLineRunner->new('false');
    ok(! $runner->rv, 'rv is false');
    ok($runner->child_error, 'child error is true');
};

subtest 'stdout and stderr' => sub {
    plan tests => 3;

    my $expected_stderr = "This is stderr\n";
    my $expected_stdout = "This is stdout\n";
    my $runner = TestDbServer::CommandLineRunner->new(
                        $^X, '-e',
                        qq(print STDERR "$expected_stderr"; print STDOUT "$expected_stdout"; exit 1));
    ok(! $runner->rv, 'rv is false');
    is($runner->child_error, 1 << 8, 'child error');

    my $compare_output = ( $runner->output eq "${expected_stderr}${expected_stdout}"
                            or
                           $runner->output eq "${expected_stdout}${expected_stderr}"
                         );
    ok($compare_output, 'output');
};
    
