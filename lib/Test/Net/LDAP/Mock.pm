use 5.006;
use strict;
use warnings;

package Test::Net::LDAP::Mock;

use base 'Test::Net::LDAP';

use IO::Socket;
use Net::LDAP;
use Net::LDAP::Constant qw(LDAP_SUCCESS);

=head1 NAME

Test::Net::LDAP::Mock - A mock LDAP client with simulated search in memory

=cut

=head1 SYNOPSIS

C<Test::Net::LDAP::Mock> is a subclass of L<Test::Net::LDAP>, which is
a subclass of L<Net::LDAP>.
All the LDAP operations are performed in memory, instead of connecting to the
real LDAP server.

    use Test::Net::LDAP::Mock;
    my $ldap = Test::Net::LDAP::Mock->new();

In practice, it is recommended to use L<Test::Net::LDAP::Util/ldap_mockify> as
below.

    use Test::More tests => 1;
    use Test::Net::LDAP::Util qw(ldap_mockify);
    
    ldap_mockify {
        # Anywhere in this block, all the occurrences of Net::LDAP::new are
        # replaced by Test::Net::LDAP::Mock::new
        ok my_application_routine();
    };

Note: if no LDAP entries have been added to the in-memory directory, the
C<search> method will silently succeed with no entries found.

Below is an example to set up some fake data for particular test cases.

    use Test::More tests => 1;
    use Test::Net::LDAP::Util qw(ldap_mockify);
    
    ldap_mockify {
        my $ldap = Net::LDAP->new('ldap.example.com');
        
        $ldap->add('uid=user1, ou=users, dc=example, dc=com');
        $ldap->add('uid=user2, ou=users, dc=example, dc=com');
        $ldap->add('cn=group1, ou=groups, dc=example, dc=com', attrs => [
            member => [
                'uid=user1, ou=users, dc=example, dc=com',
                'uid=user2, ou=users, dc=example, dc=com',
            ]
        ]);
        
        ok my_application_routine();
    };

C<Test::Net::LDAP::Mock> maintains a shared LDAP directory tree for the same
host/port, while it separates the directory trees for different
host/port combinations.
Thus, it is important to specify a correct server location consistently.

=head1 DESCRIPTION

=head2 Overview

C<Test::Net::LDAP::Mock> provides all the operations of C<Net::LDAP>, while
they are performed in memory with fake data that are set up just for testing.

It is most useful for developers who write testing for an application that
uses LDAP search, while they do not have full control over the organizational
LDAP server.
In many cases, developers do not have write access to the LDAP data, and the
organizational information changes over time, which makes it difficult to write
stable test cases with LDAP.
C<Test::Net::LDAP::Mock> helps developers set up any fake LDAP directory tree
in memory, so that they can test sufficient varieties of senarios for the
application.

Without this module, an alternative way to test an application using LDAP is to
run a real server locally during testing. (See how C<Net::LDAP> is tested with
a local OpenLDAP server.)
However, it may not be always trivial to set up such a server with correct
configurations and schemas, where this module makes testing easier.

=head2 LDAP Schema

In the current version, the LDAP schema is ignored when entries are added or
modified, although a schema can optionally be specified only for the search
filter matching (based on L<Net::LDAP::FilterMatch>).

An advantage is that it is much easier to set up fake data with any arbitrary
LDAP attributes than to care about all the restrictions with the schema.
A disadvantage is that it cannot test schema-sensitive cases.

=head2 Controls

LDAPv3 controls are not supported (yet).
The C<control> parameter given as an argument of a method will be ignored.

=head1 METHODS

=head2 new

Creates a new object. It does not connect to the real LDAP server.
Each object is associated with a shared LDAP data tree in memory, depending on
the target (host/port/path) and scheme (ldap/ldaps/ldapi).

    Test::Net::LDAP::Mock->new();
    Test::Net::LDAP::Mock->new('ldap.example.com', port => 3389);

=cut

my $mock_map = {};

sub new {
	my $class = shift;
	$class = ref $class || $class;
	$class = __PACKAGE__ if $class eq 'Net::LDAP'; # special case (ldap_mockify)
	my $target = &_mock_target;
	
	my $self = bless {
		mock_data  => undef,
		net_ldap_socket => IO::Socket->new(),
	}, $class;
	
	$self->{mock_data} = ($mock_map->{$target} ||= do {
		require Test::Net::LDAP::Mock::Data;
		Test::Net::LDAP::Mock::Data->new($self);
	});
	
	return $self;
}

sub _mock_target {
	my $host = shift if @_ % 2;
	my $arg = &Net::LDAP::_options;
	my $scheme = $arg->{scheme} || 'ldap';
	
	if (length $host) {
		if ($scheme ne 'ldapi' && $host !~ /:\d+$/) {
			$host .= ':'.($arg->{port} || 389);
		}
	} else {
		$host = '';
	}
	
	return "$scheme://$host";
}

sub _mock_message {
	my $self = shift;
	my $mesg = $self->message(@_);
	$mesg->{resultCode} = LDAP_SUCCESS;
	$mesg->{errorMessage} = '';
	$mesg->{matchedDN} = '';
	$mesg->{raw} = undef;
	$mesg->{controls} = undef;
	$mesg->{ctrl_hash} = undef;
	return $mesg;
}

#override
sub _send_mesg {
	my $ldap = shift;
	my $mesg = shift;
	return $mesg;
}

=head2 mock_data

Retrieves the currently associated data tree (for the internal purpose only).

=cut

sub mock_data {
	return shift->{mock_data};
}

=head2 mock_schema

Gets or sets the LDAP schema (L<Net::LDAP::Schema> object) for the currently
associated data tree.

In this version, the schema is used only for the search filter matching (based
on L<Net::LDAP::FilterMatch> internally).
It has no effect for any modification operations such as C<add>, C<modify>, and
C<delete>.

=cut

sub mock_schema {
	my $self = shift;
	$self->schema(@_);
}

=head2 search

Searches for entries in the currently associated data tree.

    $ldap->search(
        base => 'dc=example, dc=com', scope => 'sub',
        filter => '(cn=*)', attrs => ['uid', 'cn']
    );

See L<Net::LDAP/search> for more parameter usage.

=cut

sub search {
	my $ldap = shift;
	return $ldap->mock_data->search(@_);
}

=head2 compare

Compares an attribute/value pair with an entry in the currently associated data
tree.

    $ldap->compare('uid=test, dc=example, dc=com',
        attr => 'cn',
        value => 'Test'
    );

See L<Net::LDAP/compare> for more parameter usage.

=cut

sub compare {
	my $ldap = shift;
	return $ldap->mock_data->compare(@_);
}

=head2 add

Adds an entry to the currently associated data tree.

    $ldap->add('uid=test, dc=example, dc=com', attrs => [
        cn => 'Test'
    ]);

See L<Net::LDAP/add> for more parameter usage.

=cut

sub add {
	my $ldap = shift;
	return $ldap->mock_data->add(@_);
}

=head2 modify

Modifies an entry in the currently associated data tree.

    $ldap->modify('uid=test, dc=example, dc=com', add => [
        cn => 'Test2'
    ]);

See L<Net::LDAP/modify> for more parameter usage.

=cut

sub modify {
	my $ldap = shift;
	return $ldap->mock_data->modify(@_);
}

=head2 delete

Deletes an entry from the currently associated data tree.

    $ldap->delete('uid=test, dc=example, dc=com');

See L<Net::LDAP/delete> for more parameter usage.

=cut

sub delete {
	my $ldap = shift;
	return $ldap->mock_data->delete(@_);
}

=head2 moddn

Modifies DN of an entry in the currently associated data tree.

    $ldap->moddn('uid=test, dc=example, dc=com',
        newrdn => 'uid=test2'
    );

See L<Net::LDAP/moddn> for more parameter usage.

=cut

sub moddn {
	my $ldap = shift;
	return $ldap->mock_data->moddn(@_);
}

=head2 bind

Does nothing except for returning a success message.

=cut

sub bind {
	my $ldap = shift;
	return $ldap->mock_data->bind(@_);
}

=head2 unbind

Does nothing except for returning a success message.

=cut

sub unbind {
	my $ldap = shift;
	return $ldap->mock_data->unbind(@_);
}

=head2 abandon

Does nothing except for returning a success message.

=cut

sub abandon {
	my $ldap = shift;
	return $ldap->mock_data->abandon(@_);
}

1;
