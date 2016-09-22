package XenAPI::VBD;

use strict;
use warnings;

use Data::Dumper;

sub new {
	my ($class, $session, $vbd_ref) = @_;
	return bless { session => $session, vbd_ref => $vbd_ref }, $class;
}

sub get_uuid {
	my $self = shift;
	return $self->get_generic('VBD.get_uuid');
}

sub get_device {
	my $self = shift;
	return $self->get_generic('VBD.get_device');
}

sub get_userdevice {
	my $self = shift;
	return $self->get_generic('VBD.get_userdevice');
}

sub get_current_operations {
	my $self = shift;
	return $self->get_generic('VBD.get_current_operations');
}

sub get_allowed_operations {
	my $self = shift;
	return $self->get_generic('VBD.get_allowed_operations');
}

sub get_vm {
	my $self = shift;
	return $self->get_generic('VBD.get_VM');
}

sub get_vdi {
	my $self = shift;
	return $self->get_generic('VBD.get_VDI');
}

sub get_bootable {
	my $self = shift;
	return $self->get_generic('VBD.get_bootable');
}

sub get_mode {
	my $self = shift;
	return $self->get_generic('VBD.get_mode');
}

sub get_unpluggable {
	my $self = shift;
	return $self->get_generic('VBD.get_unpluggable');
}

sub get_type {
	my $self = shift;
	return $self->get_generic('VBD.get_type');
}

sub get_storage_lock {
	my $self = shift;
	return $self->get_generic('VBD.get_storage_lock');
}

sub get_empty {
	my $self = shift;
	return $self->get_generic('VBD.get_empty');
}

sub get_currently_attached {
	my $self = shift;
	return $self->get_generic('VBD.get_currently_attached');
}

sub get_status_code {
	my $self = shift;
	return $self->get_generic('VBD.get_status_code');
}

sub get_status_detail {
	my $self = shift;
	return $self->get_generic('VBD.get_status_detail');
}

sub get_runtime_properties {
	my $self = shift;
	return $self->get_generic('VBD.get_runtime_properties');
}

sub get_qos_algorithm_type {
	my $self = shift;
	return $self->get_generic('VBD.get_qos_algorithm_type');
}

sub get_qos_algorithm_params {
	my $self = shift;
	return $self->get_generic('VBD.get_qos_algorithm_params');
}

sub get_qos_algorithm_algorithms {
	my $self = shift;
	return $self->get_generic('VBD.get_qos_algorithm_algorithms');
}

sub get_metrics {
	my $self = shift;
	return $self->get_generic('VBD.get_metrics');
}

sub get_generic {
	my ($self, $property) = @_;
	my $result = $self->method($property, []);
	return $result->{Value}->{value};
}

sub method {
	my ($self, $method, $args) = @_;
	die [ 'SESSION_INVALID', 'Handle', 'Bad Session handle' ] if (!$self->{session});
	unshift(@{$args}, {string => $self->{vbd_ref}});
	return $self->{session}->method($method, $args);
}

1;
