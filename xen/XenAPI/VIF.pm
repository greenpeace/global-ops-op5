package XenAPI::VIF;

use strict;
use warnings;

use Data::Dumper;

sub new {
	my ($class, $session, $vif_ref) = @_;
	return bless { session => $session, vif_ref => $vif_ref }, $class;
}

sub get_uuid {
	my $self = shift;
	return $self->get_generic('VIF.get_uuid');
}

sub get_device {
	my $self = shift;
	return $self->get_generic('VIF.get_device');
}

sub get_network {
	my $self = shift;
	return $self->get_generic('VIF.get_network');
}

sub get_current_operations {
	my $self = shift;
	return $self->get_generic('VIF.get_current_operations');
}

sub get_allowed_operations {
	my $self = shift;
	return $self->get_generic('VIF.get_allowed_operations');
}

sub get_vm {
	my $self = shift;
	return $self->get_generic('VIF.get_VM');
}

sub get_mac {
	my $self = shift;
	return $self->get_generic('VIF.get_MAC');
}

sub get_mac_autogenerated {
	my $self = shift;
	return $self->get_generic('VIF.get_MAC_autogenerated');
}

sub get_mtu {
	my $self = shift;
	return $self->get_generic('VIF.get_MTU');
}

sub get_currently_attached {
	my $self = shift;
	return $self->get_generic('VIF.get_currently_attached');
}

sub get_status_code {
	my $self = shift;
	return $self->get_generic('VIF.get_status_code');
}

sub get_status_detail {
	my $self = shift;
	return $self->get_generic('VIF.get_status_detail');
}

sub get_runtime_properties {
	my $self = shift;
	return $self->get_generic('VIF.get_runtime_properties');
}

sub get_qos_algorithm_type {
	my $self = shift;
	return $self->get_generic('VIF.get_qos_algorithm_type');
}

sub get_qos_algorithm_params {
	my $self = shift;
	return $self->get_generic('VIF.get_qos_algorithm_params');
}

sub get_qos_algorithm_algorithms {
	my $self = shift;
	return $self->get_generic('VIF.get_qos_algorithm_algorithms');
}

sub get_metrics {
	my $self = shift;
	return $self->get_generic('VIF.get_metrics');
}

sub get_generic {
	my ($self, $property) = @_;
	my $result = $self->method($property, []);
	return $result->{Value}->{value};
}

sub method {
	my ($self, $method, $args) = @_;
	die [ 'SESSION_INVALID', 'Handle', 'Bad Session handle' ] if (!$self->{session});
	unshift(@{$args}, {string => $self->{vif_ref}});
	return $self->{session}->method($method, $args);
}

1;