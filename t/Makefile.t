#!perl

use Test::More qw(no_plan);
use Test::CPANpm;

local %ENV = %ENV;

$ENV{PERL_MM_USE_DEFAULT} = 1;

$ENV{AUTOMATED_TESTING} = 0;

cpan_depends_ok(
    ['Test::CPANpm', 'DBI'],
    'Dont depend on DBD::SQLite2 for testing by default'
);

$ENV{AUTOMATED_TESTING} = 1;

cpan_depends_ok(
    ['Test::CPANpm', 'DBI', 'DBD::SQLite2' ],
    "Depend on DBD::SQLite2 when AUTOMATED_TESTING is set"
);
