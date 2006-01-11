#!perl

use Test::More qw(no_plan);
use Test::CPANpm;

local %ENV = %ENV;

$ENV{PERL_MM_USE_DEFAULT} = 1;
delete $ENV{DBI_DSN};

cpan_depends_ok(
    ['Test::CPANpm', 'DBI', 'DBD::SQLite2'],
    'Depend on DBD::SQLite2 for testing when DBI_DSN is not set'
);

$ENV{DBI_DSN} = '';

cpan_depends_ok(
    ['Test::CPANpm', 'DBI'],
    "Don't depend on DBD::SQLite2 when DBI_DSN is an empty string"
);

$ENV{DBI_DSN} = 'DBD:Pg:';

cpan_depends_ok(
    ['Test::CPANpm', 'DBI'],
    "Don't depend on DBD::SQLite2 when DBI_DSN isn't a SQLite DSN"
);

$ENV{DBI_DSN} = 'DBD:SQLite2:foo';

cpan_depends_ok(
    ['Test::CPANpm', 'DBI'],
    "Depend on DBD::SQLite2 when DBI_DSN is a SQLite DSN"
);
