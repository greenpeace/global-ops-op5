package XenAPI::Session;

use strict;
use warnings;

use LWP::UserAgent;
use HTTP::Request::Common;
use XML::Simple;
use XenAPI::Host;
use XenAPI::VM;
use XenAPI::SR;
use XenAPI::VBD;
use XenAPI::PIF;
use XenAPI::VIF;
use XenAPI::Pool;
use XenAPI::Tunnel;
use XenAPI::RRD;
use Data::Dumper;

sub new {
	my $class = shift;
	return bless { user_agent => LWP::UserAgent->new( ssl_opts => { verify_hostname => undef } ), xml_parser => XML::Simple->new(), session_handle => '', host => '' }, $class;
}

sub connect {
	my ($self, $host, $username, $password, $api) = @_;
	$self->{session_handle} = undef;
	$self->{host} = $host;

	my $result = $self->_request('session.login_with_password', [{string => $username}, {string => $password}, {string => $api}]);
	die [ 'BAD_SERVER_RESPONSE', 'SessionID', 'No Session provided' ] if (!exists($result->{Value}->{value}));
	$self->{session_handle} = $result->{Value}->{value};
}

sub disconnect {
	my $self = shift;
	my $result = $self->method('session.logout', []);
}

sub get_this_host {
	my $self = shift;
	my $result = $self->method('session.get_this_host', []);
	return undef if (!exists($result->{Value}->{value}));
	return undef if (!$result->{Value}->{value});
	return XenAPI::Host->new($self, $result->{Value}->{value});
}

sub get_hosts {
	my $self = shift;
	return $self->get_objects('XenAPI::Host', 'host.get_all', []);
}

sub get_host_by_uuid {
	my ($self, $uuid) = @_;
	return $self->get_object_by_uuid('XenAPI::Host', 'host.get_by_uuid', $uuid);
}

sub get_host_by_name {
	my ($self, $name) = @_;
	return $self->get_objects('XenAPI::Host', 'host.get_by_name_label', [{string => $name}]);
}

sub get_vms {
	my $self = shift;
	return $self->get_objects('XenAPI::VM', 'VM.get_all', []);
}

sub get_vm_by_uuid {
	my ($self, $uuid) = @_;
	return $self->get_object_by_uuid('XenAPI::VM', 'VM.get_by_uuid', $uuid);
}

sub get_vm_by_name {
	my ($self, $name) = @_;
	return $self->get_objects('XenAPI::VM', 'VM.get_by_name_label', [{string => $name}]);
}

sub get_srs {
	my $self = shift;
	return $self->get_objects('XenAPI::SR', 'SR.get_all', []);
}

sub get_sr_by_uuid {
	my ($self, $uuid) = @_;
	return $self->get_object_by_uuid('XenAPI::SR', 'SR.get_by_uuid', $uuid);
}

sub get_sr_by_name {
	my ($self, $name) = @_;
	return $self->get_objects('XenAPI::SR', 'SR.get_by_name_label', [{string => $name}]);
}

sub get_vbds {
	my $self = shift;
	return $self->get_objects('XenAPI::VBD', 'VBD.get_all', []);
}

sub get_vbd_by_uuid {
	my ($self, $uuid) = @_;
	return $self->get_object_by_uuid('XenAPI::VBD', 'VBD.get_by_uuid', $uuid);
}

sub get_pifs {
	my $self = shift;
	return $self->get_objects('XenAPI::PIF', 'PIF.get_all', []);
}

sub get_pif_by_uuid {
	my ($self, $uuid) = @_;
	return $self->get_object_by_uuid('XenAPI::PIF', 'PIF.get_by_uuid', $uuid);
}

sub get_vifs {
	my $self = shift;
	return $self->get_objects('XenAPI::VIF', 'VIF.get_all', []);
}

sub get_vif_by_uuid {
	my ($self, $uuid) = @_;
	return $self->get_object_by_uuid('XenAPI::VIF', 'VIF.get_by_uuid', $uuid);
}

sub get_pools {
	my $self = shift;
	return $self->get_objects('XenAPI::Pool', 'pool.get_all', []);
}

sub get_pool_by_uuid {
	my ($self, $uuid) = @_;
	return $self->get_object_by_uuid('XenAPI::Pool', 'pool.get_by_uuid', $uuid);
}

sub get_tunnels {
	my $self = shift;
	return $self->get_objects('XenAPI::Tunnel', 'tunnel.get_all', []);
}

sub get_tunnel_by_uuid {
	my ($self, $uuid) = @_;
	return $self->get_object_by_uuid('XenAPI::Tunnel', 'tunnel.get_by_uuid', $uuid);
}

sub host_rrd {
	my ($self, $address, $cf) = @_;
	die [ 'SESSION_INVALID', 'Handle', 'Bad Session handle' ] if (!defined($self->{session_handle}));
	$address = $self->get_this_host()->get_address() if (!$address);
	my $respond = $self->{user_agent}->request(GET 'https://' . $address . '/host_rrd?session_id=' . $self->{session_handle} . ($cf ? '&cf=' . $cf : ''));
	die [ 'BAD_SERVER_RESPONSE', 'HTTP_CODE', $respond->status_line ] if (!$respond->is_success);
	return $respond->content;
}

sub vm_rrd {
	my ($self, $vm_uuid, $address, $cf) = @_;
	die [ 'SESSION_INVALID', 'Handle', 'Bad Session handle' ] if (!defined($self->{session_handle}));
	$address = $self->get_this_host()->get_address() if (!$address);
	my $respond = $self->{user_agent}->request(GET 'https://' . $address . '/vm_rrd?session_id=' . $self->{session_handle} . '&uuid=' . $vm_uuid . ($cf ? '&cf=' . $cf : ''));
	die [ 'BAD_SERVER_RESPONSE', 'HTTP_CODE', $respond->status_line ] if (!$respond->is_success);
	return $respond->content;
}

sub rrd_updates {
	my ($self, $start, $host, $address, $cf) = @_;
	die [ 'SESSION_INVALID', 'Handle', 'Bad Session handle' ] if (!defined($self->{session_handle}));
	$address = $self->get_this_host()->get_address() if (!$address);
	my $respond = $self->{user_agent}->request(GET 'https://' . $address . '/rrd_updates?session_id=' . $self->{session_handle} . '&start=' . $start . ($host ? '&host=true' : '') . (defined($cf) ? '&cf=' . $cf : ''));
	die [ 'BAD_SERVER_RESPONSE', 'HTTP_CODE', $respond->status_line ] if (!$respond->is_success);
	return $respond->content;
}

sub get_object_by_uuid {
	my ($self, $class, $property, $uuid) = @_;
	my $result = $self->method($property, [{string => $uuid}]);
	return undef if (!exists($result->{Value}->{value}));
	return undef if (!$result->{Value}->{value});
	return $class->new($self, $result->{Value}->{value});
}

sub get_objects {
	my ($self, $class, $property, $args) = @_;
	my $list = [];
	my $result = $self->method($property, $args);
	return undef if (!exists($result->{Value}->{value}->{array}[0]->{value}));
	my $objs = $result->{Value}->{value}->{array}[0]->{value};
	if (ref($objs) eq 'ARRAY') {
		push(@{$list}, $class->new($self, $_)) foreach (@{$objs});
	} else {
		push(@{$list}, $class->new($self, $objs)) if ($objs);
	}
	return $list;
}

sub method {
	my ($self, $method, $args) = @_;
	unshift(@{$args}, {string => $self->{session_handle}});
	return $self->_request($method, $args);
}

sub _request {
	my ($self, $method, $parameters) = @_;

	my $rpc_req = {
		methodName => [ $method ],
		params => {
			param => []
		}
	};

	foreach my $param (@{$parameters}) {
		push(@{$rpc_req->{params}->{param}}, {value => [$param]});
	}

	my $request = $self->{xml_parser}->XMLout($rpc_req, XMLDecl => 1, NoAttr => 1, RootName => 'methodCall');
	my $respond = $self->{user_agent}->request(POST $self->{host}, Content => $request);
	die [ 'BAD_SERVER_RESPONSE', 'HTTP_CODE', $respond->status_line ] if (!$respond->is_success);
	my $xml = $self->{xml_parser}->XMLin($respond->content, ForceArray => [ 'data', 'param', 'member' ], GroupTags => { array => 'data', struct => 'member' });
	die [ 'BAD_SERVER_RESPONSE', 'Structure', 'Not a response structure' ] if (!exists($xml->{params}->{param}[0]->{value}->{struct}));
	my $result = $xml->{params}->{param}[0]->{value}->{struct};
	die [ 'BAD_SERVER_RESPONSE', 'Status', 'No Status provided' ] if (!exists($result->{Status}->{value}));
	if ($result->{Status}->{value} eq "Success") {
		return $result;
	} elsif ($result->{Status}->{value} eq "Failure") {
		die [ {value => [ 'BAD_SERVER_RESPONSE', 'ErrorDescription', 'No ErrorDescription provided' ]} ] if (!exists($result->{ErrorDescription}->{value}->{array}));
		die $result->{ErrorDescription}->{value}->{array}[0]->{value};
	}
	die [ 'BAD_SERVER_RESPONSE', 'Status', 'Unknown status = ' . $result->{Status}->{value} ];
}

1;
