package XenAPI::VM;

use strict;
use warnings;

use XenAPI::Host;
use XenAPI::RRD;
use Data::Dumper;

sub new {
	my ($class, $session, $vm_ref) = @_;
	return bless { session => $session, vm_ref => $vm_ref }, $class;
}

sub get_uuid {
	my $self = shift;
	return $self->get_generic('VM.get_uuid');
}

sub get_name {
	my $self = shift;
	return $self->get_generic('VM.get_name_label');
}

sub get_description {
	my $self = shift;
	return $self->get_generic('VM.get_name_description');
}

sub get_domid {
	my $self = shift;
	return $self->get_generic('VM.get_domid');
}

sub get_domarch {
	my $self = shift;
	return $self->get_generic('VM.get_domarch');
}

sub get_current_operations {
	my $self = shift;
	return $self->get_generic('VM.get_current_operations');
}

sub get_allowed_operations {
	my $self = shift;
	return $self->get_generic('VM.get_allowed_operations');
}

sub get_user_version {
	my $self = shift;
	return $self->get_generic('VM.get_user_version');
}

sub get_suspend_vdi {
	my $self = shift;
	return $self->get_generic('VM.get_suspend_vdi');
}

sub get_resident_on {
	my $self = shift;
	return XenAPI::Host->new($self->{session}, $self->get_generic('VM.get_resident_on'));
}

sub get_affinity {
	my $self = shift;
	return XenAPI::Host->new($self->{session}, $self->get_generic('VM.get_affinity'));
}

sub get_memory_overhead {
	my $self = shift;
	return $self->get_generic('VM.get_memory_overhead');
}

sub get_memory_target {
	my $self = shift;
	return $self->get_generic('VM.get_memory_target');
}

sub get_memory_static_max {
	my $self = shift;
	return $self->get_generic('VM.get_memory_static_max');
}

sub get_memory_static_min {
	my $self = shift;
	return $self->get_generic('VM.get_memory_static_min');
}

sub get_memory_dynamic_max {
	my $self = shift;
	return $self->get_generic('VM.get_memory_dynamic_max');
}

sub get_memory_dynamic_min {
	my $self = shift;
	return $self->get_generic('VM.get_memory_dynamic_min');
}

sub get_vcpus_params {
	my $self = shift;
	return $self->get_struct('VM.get_VCPUs_params');
}

sub get_vcpus_max {
	my $self = shift;
	return $self->get_generic('VM.get_VCPUs_max');
}

sub get_vcpus_at_startup {
	my $self = shift;
	return $self->get_generic('VM.get_VCPUs_at_startup');
}

sub get_actions_after_shutdown {
	my $self = shift;
	return $self->get_generic('VM.get_actions_after_shutdown');
}

sub get_actions_after_reboot {
	my $self = shift;
	return $self->get_generic('VM.get_actions_after_reboot');
}

sub get_actions_after_crash {
	my $self = shift;
	return $self->get_generic('VM.get_actions_after_crash');
}

sub get_crash_dumps {
	my $self = shift;
	return $self->get_struct('VM.get_crash_dumps');
}

sub get_consoles {
	my $self = shift;
	return $self->get_generic('VM.get_consoles');
}

sub get_last_boot_cpu_flags {
	my $self = shift;
	return $self->get_struct('VM.get_last_boot_CPU_flags');
}

sub get_pv_bootloader {
	my $self = shift;
	return $self->get_generic('VM.get_PV_bootloader');
}

sub get_pv_kernel {
	my $self = shift;
	return $self->get_generic('VM.get_PV_kernel');
}

sub get_pv_ramdisk {
	my $self = shift;
	return $self->get_generic('VM.get_PV_ramdsk');
}

sub get_pv_args {
	my $self = shift;
	return $self->get_generic('VM.get_PV_args');
}

sub get_pv_bootloader_args {
	my $self = shift;
	return $self->get_generic('VM.get_PV_bootloader_args');
}

sub get_pv_legacy_args {
	my $self = shift;
	return $self->get_generic('VM.get_PV_legacy_args');
}

sub get_hvm_boot_policy {
	my $self = shift;
	return $self->get_generic('VM.get_HVM_boot_policy');
}

sub get_hvm_boot_params {
	my $self = shift;
	return $self->get_generic('VM.get_HVM_boot_params');
}

sub get_hvm_boot_shadow_multiplier {
	my $self = shift;
	return $self->get_generic('VM.get_HVM_boot_shadow_multiplier');
}

sub get_power_state {
	my $self = shift;
	return $self->get_generic('VM.get_power_state');
}

sub get_platform {
	my $self = shift;
	return $self->get_generic('VM.get_platform');
}

sub get_pci_bus {
	my $self = shift;
	return $self->get_generic('VM.get_pci_bus');
}

sub get_recommendations {
	my $self = shift;
	return $self->get_generic('VM.get_recommendations');
}

sub is_control_domain {
	my $self = shift;
	return $self->get_boolean('VM.get_is_control_domain');
}

sub is_template {
	my $self = shift;
	return $self->get_boolean('VM.get_is_a_template');
}

sub get_metrics {
	my $self = shift;
	return $self->get_generic('VM.get_metrics');
}

sub get_guest_metrics {
	my $self = shift;
	return $self->get_generic('VM.get_guest_metrics');
}

sub get_last_booted_record {
	my $self = shift;
	return $self->get_generic('VM.get_last_booted_record');
}

sub get_xenstore_data {
	my $self = shift;
	return $self->get_generic('VM.get_xenstore_data');
}

sub get_vifs {
	my $self = shift;
	return $self->get_generic('VM.get_VIFs');
}

sub get_vtpms {
	my $self = shift;
	return $self->get_generic('VM.get_VTPMs');
}

sub get_vbds {
	my $self = shift;
	return $self->get_generic('VM.get_VBDs');
}

sub get_vgpus{
	my $self = shift;
	return $self->get_generic('VM.get_VGPUs');
}

sub get_attached_pcis {
	my $self = shift;
	return $self->get_generic('VM.get_attached_PCIs');
}

sub get_rrd_update {
	my ($self, $start, $cf) = @_;
	my $uuid = $self->get_uuid();
	my $rrd = XenAPI::RRD->new($self->{session}->rrd_updates($start, 0, $self->get_resident_on()->get_address() ,$cf));
	return $rrd->get_vm_data($uuid);
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
	unshift(@{$args}, {string => $self->{vm_ref}});
	return $self->{session}->method($method, $args);
}

1;
