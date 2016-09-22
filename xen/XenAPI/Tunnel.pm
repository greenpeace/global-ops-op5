package XenAPI::Tunnel;

use strict;
use warnings;

use Data::Dumper;

sub new {
	my ($class, $session, $tunnel_ref) = @_;
	return bless { session => $session, tunnel_ref => $tunnel_ref }, $class;
}

sub get_uuid {
	my $self = shift;
	return $self->get_generic('tunnel.get_uuid');
}

sub get_status {
	my $self = shift;
	return $self->get_struct('tunnel.get_status');
}

sub get_access_pif {
	my $self = shift;
	return $self->get_generic('tunnel.get_access_PIF');
}

sub get_generic {
	my ($self, $property) = @_;
	my $result = $self->method($property, []);
	return $result->{Value}->{value};
}

sub get_struct {
	my ($self, $property) = @_;
	my $result = $self->method($property, []);
	return $result->{Value}->{value}->{struct};
}

sub method {
	my ($self, $method, $args) = @_;
	die [ 'SESSION_INVALID', 'Handle', 'Bad Session handle' ] if (!$self->{session});
	unshift(@{$args}, {string => $self->{sr_ref}});
	return $self->{session}->method($method, $args);
}

1;
