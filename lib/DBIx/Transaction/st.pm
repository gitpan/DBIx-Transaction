package DBIx::Transaction::st;

use DBI;
use base q(DBI::st);
use strict;
use warnings (FATAL => 'all');

return 1;

=pod

=head1 NAME

DBIx::Transaction::st - Statement handle when running under DBIx::Transaction

=head1 DESCRIPTION

This class is empty; it just inherits from the L<DBI::st|DBI> class. It is
only here to allow DBI to use L<DBIx::Transaction> as a subclass.

=head1 SEE ALSO

L<DBI>, L<DBIx::Transaction>

=cut
