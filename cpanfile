requires 'perl', 'v5.18.2';

requires 'Mojolicious', '5';
requires 'Carp';
requires 'DBI', '1.63';
requires 'DBD::SQLite', '1.42';
requires 'Moose', '2.1';
requires 'Exception::Class';
requires 'MooseX::NonMoose';
requires 'DBIx::Class';
requires 'DBD::Pg';
requires 'App::Info::RDBMS::PostgreSQL';
requires 'Data::UUID';

on develop => sub {
    requires 'Test::More';
    requires 'Test::Exception';
};

feature 'cli', 'command-line interface' => sub {
    recommends 'LWP';
    recommends 'LWP::Protocol::https';
};
