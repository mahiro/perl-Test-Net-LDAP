#!perl -T
use strict;
use warnings;

use Test::More tests => 31;

use Net::LDAP::Constant qw(
    LDAP_SUCCESS
    LDAP_PARAM_ERROR
    LDAP_INVALID_DN_SYNTAX
    LDAP_ALREADY_EXISTS
);
use Net::LDAP::Entry;
use Net::LDAP::Util qw(canonical_dn);
use Test::Net::LDAP::Util qw(ldap_result_is);
use Test::Net::LDAP::Mock::Data;

my $data = Test::Net::LDAP::Mock::Data->new;
my $search;

# Add an entry
$data->add_ok('uid=user1, dc=example, dc=com', attrs => [
    sn => 'User',
    cn => 'One',
]);

$search = $data->search_ok(
    base => 'dc=example, dc=com', scope => 'one',
    filter => '(uid=*)', attrs => [qw(uid sn cn)],
);

is(scalar($search->entries), 1);
is($search->entry->dn, 'uid=user1,dc=example,dc=com');
is($search->entry->get_value('uid'), 'user1');
is($search->entry->get_value('sn'), 'User');
is($search->entry->get_value('cn'), 'One');

# Add more entries
$data->add_ok('uid=user2, dc=example, dc=com', attrs => [
    sn => 'User',
    cn => 'Two',
]);

$data->add_ok('uid=user3, dc=example, dc=com', attrs => [
    sn => 'User',
    cn => 'Three',
]);

$search = $data->search_ok(
    base => 'dc=example, dc=com', scope => 'one',
    filter => '(uid=*)', attrs => [qw(uid sn cn)],
);

is(scalar($search->entries), 3);

my @entries = sort {$a->get_value('uid') cmp $b->get_value('uid')} $search->entries;
is($entries[0]->dn, 'uid=user1,dc=example,dc=com');
is($entries[0]->get_value('uid'), 'user1');
is($entries[0]->get_value('sn'), 'User');
is($entries[0]->get_value('cn'), 'One');
is($entries[1]->dn, 'uid=user2,dc=example,dc=com');
is($entries[1]->get_value('uid'), 'user2');
is($entries[1]->get_value('sn'), 'User');
is($entries[1]->get_value('cn'), 'Two');
is($entries[2]->dn, 'uid=user3,dc=example,dc=com');
is($entries[2]->get_value('uid'), 'user3');
is($entries[2]->get_value('sn'), 'User');
is($entries[2]->get_value('cn'), 'Three');

# Callback
my @callback_args;

my $mesg = $data->add_ok('uid=user4, dc=example, dc=com',
    callback => sub {
        push @callback_args, \@_;
    }
);

is(scalar(@callback_args), 1);
is(scalar(@{$callback_args[0]}), 1);
cmp_ok($callback_args[0][0], '==', $mesg);

# Error: dn is missing
$data->add_is([attrs => [
    cn => 'Test']
], LDAP_PARAM_ERROR);

# Error: dn is invalid
$data->add_is(['invalid', attrs => [
    cn => 'Test'
]], LDAP_INVALID_DN_SYNTAX);

$data->add_is([dn => 'invalid', attrs => [
    cn => 'Test'
]], LDAP_INVALID_DN_SYNTAX);

# Error: Attempt to add a duplicate
$data->add_is(['uid=user1, dc=example, dc=com', attrs => [
    cn => 'Test'
]], LDAP_ALREADY_EXISTS);
