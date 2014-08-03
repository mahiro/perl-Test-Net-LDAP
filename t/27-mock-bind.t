#!perl -T
use strict;
use warnings;

use Test::More tests => 32;

use Net::LDAP::Constant qw(
    LDAP_SUCCESS LDAP_NO_SUCH_OBJECT
    LDAP_INVALID_CREDENTIALS LDAP_INAPPROPRIATE_AUTH
);
use Test::Net::LDAP::Mock::Data;

my $data = Test::Net::LDAP::Mock::Data->new;
$data->bind_ok();

# Set code only
$data->mock_bind(LDAP_INVALID_CREDENTIALS);
$data->bind_is([], LDAP_INVALID_CREDENTIALS);
$data->mock_bind(LDAP_SUCCESS);
$data->bind_ok();

# Set code & message
$data->mock_bind(LDAP_INVALID_CREDENTIALS, 'mock_bind error');
my $mesg = $data->bind();
is($mesg->code, LDAP_INVALID_CREDENTIALS);
is($mesg->error, 'mock_bind error');
$data->mock_bind(LDAP_SUCCESS);
$data->bind_ok();

# Set Net::LDAP::Message
my $mesg1 = bless({
    type         => 'Net::LDAP::Message',
    parent       => undef,
    callback     => undef,
    raw          => undef,
    resultCode   => LDAP_INVALID_CREDENTIALS,
    errorMessage => '', # empty errorMessage
}, 'Net::LDAP::Message');

my $mesg2 = bless({
    type         => 'Net::LDAP::Message',
    parent       => undef,
    callback     => undef,
    raw          => undef,
    resultCode   => LDAP_INAPPROPRIATE_AUTH,
    errorMessage => 'Net::LDAP::Message error',
}, 'Net::LDAP::Message');

$data->mock_bind($mesg1, '');
$mesg = $data->bind();
is($mesg->code, LDAP_INVALID_CREDENTIALS);
is($mesg->error, 'Invalid credentials');
$data->mock_bind(LDAP_SUCCESS);
$data->bind_ok();

$data->mock_bind($mesg1, 'mock_bind error');
$mesg = $data->bind();
is($mesg->code, LDAP_INVALID_CREDENTIALS);
is($mesg->error, 'mock_bind error');
$data->mock_bind(LDAP_SUCCESS);
$data->bind_ok();

$data->mock_bind($mesg2);
$mesg = $data->bind();
is($mesg->code, LDAP_INAPPROPRIATE_AUTH);
is($mesg->error, 'Net::LDAP::Message error');
$data->mock_bind(LDAP_SUCCESS);
$data->bind_ok();

$data->mock_bind($mesg2, 'mock_bind error');
$mesg = $data->bind();
is($mesg->code, LDAP_INAPPROPRIATE_AUTH);
is($mesg->error, 'mock_bind error'); # 2nd arg in mock_bind() has higher precedence
$data->mock_bind(LDAP_SUCCESS);
$data->bind_ok();

# Callback returning undef
$data->mock_bind(sub {
    my ($arg) = @_;
    is($arg->{dn}, 'cn=test1');
    is($arg->{password}, 'secret1');
    return undef;
}, 'mock_bind error');
$data->bind_ok('cn=test1', password => 'secret1');
$data->mock_bind(LDAP_SUCCESS);
$data->bind_ok();

# Callback returning code only
$data->mock_bind(sub {
    my ($arg) = @_;
    is($arg->{dn}, 'cn=test2');
    is($arg->{password}, 'secret2');
    return LDAP_INAPPROPRIATE_AUTH;
}, 'mock_bind error');
$mesg = $data->bind('cn=test2', password => 'secret2');
is($mesg->code, LDAP_INAPPROPRIATE_AUTH);
is($mesg->error, 'mock_bind error');
$data->mock_bind(LDAP_SUCCESS);
$data->bind_ok();

# Callback returning code & message
$data->mock_bind(sub {
    my ($arg) = @_;
    is($arg->{dn}, 'cn=test3');
    is($arg->{password}, 'secret3');
    return (LDAP_INAPPROPRIATE_AUTH, 'mock_bind callback error');
}, 'mock_bind error');
$mesg = $data->bind('cn=test3', password => 'secret3');
is($mesg->code, LDAP_INAPPROPRIATE_AUTH);
is($mesg->error, 'mock_bind callback error');
$data->mock_bind(LDAP_SUCCESS);
$data->bind_ok();



