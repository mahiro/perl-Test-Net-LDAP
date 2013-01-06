#!perl -T
use strict;
use warnings;

use Test::More tests => 15;

use Test::Net::LDAP::Mock::Data;

my $data = Test::Net::LDAP::Mock::Data->new;

# Basic
$data->bind_ok();
$data->unbind_ok();
$data->abandon_ok();

# Callback - bind
my @callback_args;
my $mesg;

@callback_args = ();

$mesg = $data->bind_ok(callback => sub {
	push @callback_args, \@_;
});

is(scalar(@callback_args), 1);
is(scalar(@{$callback_args[0]}), 1);
cmp_ok($callback_args[0][0], '==', $mesg);

# Callback - unbind
@callback_args = ();

$mesg = $data->unbind_ok(callback => sub {
	push @callback_args, \@_;
});

is(scalar(@callback_args), 1);
is(scalar(@{$callback_args[0]}), 1);
cmp_ok($callback_args[0][0], '==', $mesg);

# Callback - abandon
@callback_args = ();

$mesg = $data->abandon_ok(callback => sub {
	push @callback_args, \@_;
});

is(scalar(@callback_args), 1);
is(scalar(@{$callback_args[0]}), 1);
cmp_ok($callback_args[0][0], '==', $mesg);
