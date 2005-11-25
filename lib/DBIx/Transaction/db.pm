#!perl;

package DBIx::Transaction::db;

use DBI;
use base q(DBI::db);
use strict;
use warnings (FATAL => 'all');
use Carp qw(confess);

return 1;

sub transaction_trace {
    my($self, $method) = @_;
    my @vals = map { "$_=$self->{$_}" } map { "private_DBIx_Transaction_$_" }
        qw(AutoCommit Level Error);

    $self->trace_msg("DBIx::Transaction: $method: " . join(" ", @vals), 3);
}

sub transaction_level {
    my $self = shift;
    return $self->{private_DBIx_Transaction_Level};
}

sub inc_transaction_level {
    my $self = shift;
    $self->{private_DBIx_Transaction_Level}++;
    return $self->{private_DBIx_Transaction_Level};
}

sub dec_transaction_level {
    my $self = shift;
    confess "Asked to decrement transaction level below zero!"
        unless($self->{private_DBIx_Transaction_Level});
    $self->{private_DBIx_Transaction_Level}--;
    return $self->{private_DBIx_Transaction_Level};
}

sub clear_transaction_error {
    my $self = shift;
    $self->{private_DBIx_Transaction_Error} = 0;
    return;    
}

sub inc_transaction_error {
    my $self = shift;
    $self->{private_DBIx_Transaction_Error}++;
    return;
}

sub transaction_error {
    my $self = shift;
    return $self->{private_DBIx_Transaction_Error};
}

sub close_transaction {
    my $self = shift;
    my $method = shift;
    my $code = DBI::db->can($method);

    $self->{private_DBIx_Transaction_Level} = 0;
    $self->clear_transaction_error;
    $self->transaction_trace($method);
    my $rv = $code->($self, @_);
    return $rv;
}

sub begin_work {
    my $self = shift;
    if(!$self->transaction_level) {
        $self->inc_transaction_level;
        if($self->{private_DBIx_Transaction_AutoCommit}) {
            $self->transaction_trace('begin_work');
            return DBI::db::begin_work($self, @_);
        } else {
            return 1;
        }
    } else {
        $self->inc_transaction_level;
        $self->transaction_trace('begin_work');
        return 1;
    }
}

sub commit {
    my $self = shift;
    if($self->transaction_error) {
        confess "commit() called after a transaction error or rollback!";
    }
    if(my $l = $self->dec_transaction_level) {
        $self->transaction_trace('fake_commit');
        return 1;
    }
    return $self->close_transaction('commit', @_);
}

sub rollback {
    my $self = shift;
    if(my $l = $self->dec_transaction_level) {
        $self->transaction_trace('fake_rollback');
        $self->inc_transaction_error;
        return 1;
    }
    return $self->close_transaction('rollback', @_);
}

=pod

=head1 NAME

DBIx::Transaction::db - Database handle that is aware of nested transactions

=head1 SYNOPSIS

See L<DBIx::Transaction>

=head1 DESCRIPTION

When you connect to a database using DBIx::Transaction, your database handle
will be a DBIx::Transaction::db object. These objects keep track of your
transaction state, allowing for transactions to occur within transactions,
and only sending "C<commit>" or "C<rollback>" instructions to the underlying
database when the outermost transaction has completed. See L<DBIx::Transaction>
for a more complete explanation.

=head1 METHODS

=head2 Overridden Methods

The following methods are overridden by DBIx::Transaction::db:

=over

=item begin_work

Start a transaction.

If there are no transactions currently running, C<begin_work> will check
if C<AutoCommit> is enabled. If it is enabled, a C<begin_work> instruction
is sent to the underlying database layer. If C<AutoCommit> is disabled, we
assume that the database has already started a transaction for us, and do
nothing. This means that B<you must always use begin_work to start a
transaction>, even if C<AutoCommit> is enabled!

If there is a transaction started, C<begin_work> simply records that a nested
transaction has started.

C<begin_work> returns the result of the database's C<begin_work> call if it
makes one; otherwise it always returns true.

=item rollback

Abort a transaction.

If there are no sub-transactions currently running, C<rollback> will issue the
C<rollback> call to the underlying database layer.

If there are sub-transactions currently running, C<rollback> notes that the
nested transaction has been aborted.

If there is no transaction running at all, C<rollback> will raise a fatal
error.

=item commit

If there are no sub-transactions currently running, C<commit> will issue the
C<commit> call to the underlying database layer, B<unless> a sub-transaction
of this transaction issued a C<rollback> request. In this case, C<commit>
will raise a fatal error.

If there are sub-transactions currently running, C<commit> records that this
transaction has completed successfully and does nothing to the underlying
database layer.

If there is no transaction running at all, C<commit> will raise a fatal
error.

=back

=head2 Other Methods

The following methods are used by the overridden methods. In most cases
you won't have to use them yourself.

=over

=item transaction_level

Returns an integer value representing how deeply nested our transactions
currently are. eg; if we are in a top-level transaction, this returns "1";
if we are 4 transactions deep, this returns "4", if we are not in a transaction
at all, this returns "0". In some extreme cases this may be used to bail out
of a nested transaction safely, as in:

  $dbh->rollback while $dbh->transaction_level;

But I would suggest that you structure your code so that each transaction
and sub-transaction bails out safely instead, as that's a lot easier to
trace and debug with confidence.

=item transaction_error

Returns a true value if a sub-transaction has rolled back, false otherwise.
Again, you could use this to back out of a transaction safely, but I'd suggest
just writing your code to handle this case on each transaction level instead.

=item transaction_trace

For debugging; If DBI's trace level is 3 or over, emit the current values
of all of the internal variables DBIx::Transaction uses to track it's
transaction states.

=item inc_transaction_level

Indicate that we have started a sub transaction by increasing
C<transaction_level> by one. This is used by the C<begin_work> override
and should not be called directly.

=item dec_transaction_level

Indicate that we have finished a sub transaction by decrementing
C<transaction_level> by one. If this results in a negative number
(meaning more transactions have been commited/rolled back than started),
C<dec_transaction_level> throws a fatal error. This is used by the
C<commit> and C<rollback> methods and should not be called directly.

=item inc_transaction_error

Indicate that a sub-transaction has failed and that the entire
transaction should not be allowed to be committed. This is done
automatically whenever a sub-transaction issues a C<rollback>.

=item clear_transaction_error

Clear the transaction error flag. This flag is set whenever a
sub-transaction issues a C<rollback>, and cleared whenever the
outermost transaction issues a C<rollback>.

=item close_transaction($method)

Close the outermost transaction by calling C<$method>
("C<commit>" or "C<rollback>") on the underlying database layer and
resetting the DBIx::Transaction state. This method is used by the
C<commit> and C<rollback> methods and you shouldn't need to use it yourself,
unless you wanted to forcibly bail out of an entire transaction without
calling C<rollback> repeatedly, but as stated above, that's a bad idea,
isn't it?

=back

=head1 SEE ALSO

L<DBI>, L<DBIx::Transaction>

=head1 AUTHOR

Tyler "Crackerjack" MacDonald <japh@crackerjack.net>

=head1 LICENSE

Copyright 2005 Tyler MacDonald
This is free software; you may redistribute it under the same terms as perl itself.

=cut
