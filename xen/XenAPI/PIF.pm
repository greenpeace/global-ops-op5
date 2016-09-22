package XenAPI::PIF;

use strict;
use warnings;

use Data::Dumper;

sub new {
	my ($class, $session, $pif_ref) = @_;
	return bless { session => $session, pif_ref => $pif_ref }, $class;
}

sub get_uuid {
	my $self = shift;
	return $self->get_generic('PIF.get_uuid');
}

sub get_device {
	my $self = shift;
	return $self->get_generic('PIF.get_device');
}

sub get_network {
	my $self = shift;
	return $self->get_generic('PIF.get_network');
}

sub get_host {
	my $self = shift;
	return $self->get_generic('PIF.get_host');
}

sub get_mac {
	my $self = shift;
	return $self->get_generic('PIF.get_MAC');
}

sub get_mtu {
	my $self = shift;
	return $self->get_generic('PIF.get_MTU');
}

sub get_vlan {
	my $self = shift;
	return $self->get_generic('PIF.get_VLAN');
}

sub get_ip {
	my $self = shift;
	return $self->get_generic('PIF.get_IP');
}

sub get_dns {
	my $self = shift;
	return $self->get_generic('PIF.get_DNS');
}

sub get_currently_attached {
	my $self = shift;
	return $self->get_generic('PIF.get_currently_attached');
}

sub get_physical {
	my $self = shift;
	return $self->get_generic('PIF.get_physical');
}

sub get_ip_configuration_mode {
	my $self = shift;
	return $self->get_generic('PIF.get_ip_configuration_mode');
}

sub get_netmask {
	my $self = shift;
	return $self->get_generic('PIF.get_netmask');
}

sub get_gateway {
	my $self = shift;
	return $self->get_generic('PIF.get_gateway');
}

sub get_bond_slave_of {
	my $self = shift;
	return $self->get_generic('PIF.get_bond_slave_of');
}

sub get_bond_master_of {
	my $self = shift;
	return $self->get_generic('PIF.get_bond_master_of');
}

sub get_VLAN_master_of {
	my $self = shift;
	return $self->get_generic('PIF.get_VLAN_master_of');
}

sub get_VLAN_slave_of {
	my $self = shift;
	return $self->get_generic('PIF.get_VLAN_slave_of');
}

sub get_tunnel_access_PIF_of {
	my $self = shift;
	return $self->get_generic('PIF.get_tunnel_access_PIF_of');
}

sub get_tunnel_transport_PIF_of {
	my $self = shift;
	return $self->get_generic('PIF.get_tunnel_transport_PIF_of');
}

sub get_management {
	my $self = shift;
	return $self->get_generic('PIF.get_management');
}

sub get_unplug {
	my $self = shift;
	return $self->get_generic('PIF.get_unplug');
}

sub get_metrics {
	my $self = shift;
	return $self->get_generic('PIF.get_metrics');
}

sub get_generic {
	my ($self, $property) = @_;
	my $result = $self->method($property, []);
	return $result->{Value}->{value};
}

sub method {
	my ($self, $method, $args) = @_;
	die [ 'SESSION_INVALID', 'Handle', 'Bad Session handle' ] if (!$self->{session});
	unshift(@{$args}, {string => $self->{pif_ref}});
	return $self->{session}->method($method, $args);
}

1;
