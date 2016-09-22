package XenAPI::Pool;

use strict;
use warnings;

use Data::Dumper;

sub new {
	my ($class, $session, $pool_ref) = @_;
	return bless { session => $session, pool_ref => $pool_ref }, $class;
}

sub get_uuid {
	my $self = shift;
	return $self->get_generic('pool.get_uuid');
}

sub get_name {
	my $self = shift;
	return $self->get_generic('pool.get_name_label');
}

sub get_description {
	my $self = shift;
	return $self->get_generic('pool.get_name_description');
}

sub get_master {
	my $self = shift;
	return $self->get_generic('pool.get_master');
}

sub get_default_sr {
	my $self = shift;
	return $self->get_generic('pool.get_default_SR');
}

sub get_suspend_image_sr {
	my $self = shift;
	return $self->get_generic('pool.get_suspend_image_SR');
}

sub get_crash_dump_sr {
	my $self = shift;
	return $self->get_generic('pool.crash_dump_SR');
}

sub get_ha_enabled {
	my $self = shift;
	return $self->get_boolean('pool.get_ha_enabled');
}

sub get_ha_configuration {
	my $self = shift;
	return $self->get_struct('pool.get_ha_configuration');
}

sub get_ha_statefiles {
	my $self = shift;
	return $self->get_struct('pool.get_ha_statefiles');
}

sub get_ha_host_failures_to_tolerate {
	my $self = shift;
	return $self->get_generic('pool.get_ha_host_failures_to_tolerate');
}

sub get_ha_plan_exists_for {
	my $self = shift;
	return $self->get_generic('pool.get_ha_plan_exists_for');
}

sub get_ha_allow_overcommit {
	my $self = shift;
	return $self->get_boolean('pool.get_ha_allow_overcommit');
}

sub get_ha_overcommitted {
	my $self = shift;
	return $self->get_boolean('pool.get_ha_overcommitted');
}

sub get_blobs {
	my $self = shift;
	return $self->get_struct('pool.get_blobs');
}

sub get_tags {
	my $self = shift;
	return $self->get_struct('pool.get_tags');
}

sub get_gui_config {
	my $self = shift;
	return $self->get_struct('pool.get_gui_config');
}

sub get_wlb_url {
	my $self = shift;
	return $self->get_generic('pool.get_wlb_url');
}

sub get_wlb_username {
	my $self = shift;
	return $self->get_generic('pool.get_wlb_username');
}

sub get_wlb_password {
	my $self = shift;
	return $self->get_generic('pool.get_wlb_password');
}

sub get_wlb_enabled {
	my $self = shift;
	return $self->get_boolean('pool.get_wlb_enabled');
}

sub get_wlb_verify_cert {
	my $self = shift;
	return $self->get_generic('pool.get_wlb_verify_cert');
}

sub get_redo_log_enabled {
	my $self = shift;
	return $self->get_boolean('pool.get_redo_log_enabled');
}

sub get_redo_log_vdi {
	my $self = shift;
	return $self->get_generic('pool.get_redo_log_vdi');
}

sub get_record {
	my $self = shift;
	return $self->get_generic('pool.get_record');
}

sub get_vswitch_controller {
	my $self = shift;
	return $self->get_generic('pool.get_vswitch_controller');
}

sub get_restrictions {
	my $self = shift;
	return $self->get_struct('pool.get_restrictions');
}

sub get_metadata_VDIs {
	my $self = shift;
	return $self->get_struct('pool.get_metadata_VDIs');
}

sub get_generic {
	my ($self, $property) = @_;
	my $result = $self->method($property, []);
	return $result->{Value}->{value};
}

sub get_boolean {
	my ($self, $property) = @_;
	my $result = $self->method($property, []);
	return $result->{Value}->{value}->{boolean};
}

sub get_struct {
	my ($self, $property) = @_;
	my $result = $self->method($property, []);
	return $result->{Value}->{value}->{struct};
}

sub method {
	my ($self, $method, $args) = @_;
	die [ 'SESSION_INVALID', 'Handle', 'Bad Session handle' ] if (!$self->{session});
	unshift(@{$args}, {string => $self->{pool_ref}});
	return $self->{session}->method($method, $args);
}

1;
