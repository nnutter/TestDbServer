requires 'perl', 'v5.18.2';

requires 'App::Info::RDBMS::PostgreSQL';
requires 'Carp';
requires 'Data::UUID';
requires 'DBD::Pg';
requires 'DBD::SQLite', '1.42';
requires 'DBI', '1.63';
requires 'DBIx::Class';
requires 'Exception::Class';
requires 'IPC::Run';
requires 'Mojolicious', '5';
requires 'Moose', '2.1';
requires 'MooseX::NonMoose';
requires 'Sub::Install';
requires 'Sub::Name';
requires 'Test::Exception';
requires 'Test::More';

feature 'cli', 'command-line interface' => sub {
    requires 'LWP';
    requires 'LWP::Protocol::https';
};
