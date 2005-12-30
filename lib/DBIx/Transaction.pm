package DBIx::Transaction;

use 5.006;
use strict;
use warnings (FATAL => 'all');
use base q(DBI);
use DBI;
use DBIx::Transaction::db;
use DBIx::Transaction::st;

our $VERSION = '0.003';

return 1;

sub connect_method {
    my($class, $method, @args) = @_;
    my $code = DBI->can($method);
    my $self = $code->($class, @args);
    return $self unless $self;
    if($self->{AutoCommit}) {
        $self->{private_DBIx_Transaction_AutoCommit} = 1;
    } else {
        $self->{private_DBIx_Transaction_AutoCommit} = 0;
    }
    $self->{private_DBIx_Transaction_Level} = 0;
    $self->{private_DBIx_Transaction_Error} = 0;
    $self->transaction_trace($method);
    return $self;
}

sub connect {
    my $class = shift;
    return $class->connect_method('connect', @_);
}

sub connect_cached {
    my $class = shift;
    return $class->connect_method('connect_cached', @_);
}
