package XenAPI::Host;

use strict;
use warnings;

use XenAPI::VM;
use XenAPI::RRD;
use Data::Dumper;

sub new {
	my ($class, $session, $host_ref) = @_;
	return bless { session => $session, host_ref => $host_ref }, $class;
}

sub get_uuid {
	my $self = shift;
	return $self->get_generic('host.get_uuid');
}

sub get_name {
	my $self = shift;
	return $self->get_generic('host.get_hostname');
}

sub get_label {
	my $self = shift;
	return $self->get_generic('host.get_name_label');
}

sub get_description {
	my $self = shift;
	return $self->get_generic('host.get_name_description');
}

sub get_address {
	my $self = shift;
	return $self->get_generic('host.get_address');
}

sub get_enabled {
	my $self = shift;
	return $self->get_boolean('host.get_enabled');
}

sub get_power_on_mode {
	my $self = shift;
	return $self->get_generic('host.get_power_on_mode');
}

sub get_power_on_config {
	my $self = shift;
	return $self->get_struct('host.get_power_on_config');
}

sub get_memory_overhead {
	my $self = shift;
	return $self->get_generic('host.get_memory_overhead');
}

sub get_api_version_major {
	my $self = shift;
	return $self->get_generic('host.get_API_version_major');
}

sub get_api_version_minor {
	my $self = shift;
	return $self->get_generic('host.get_API_version_minor');
}

sub get_api_version_vendor {
	my $self = shift;
	return $self->get_generic('host.get_API_version_vendor');
}

sub get_api_version_vendor_implementation {
	my $self = shift;
	return $self->get_struct('host.get_API_version_vendor_implementation');
}

sub get_software_version {
	my $self = shift;
	return $self->get_generic('host.get_software_version');
}

sub get_capabilities {
	my $self = shift;
	return $self->get_generic('host.get_capabilities');
}

sub get_sched_policy {
	my $self = shift;
	return $self->get_generic('host.get_sched_policy');
}

sub get_supported_bootloaders {
	my $self = shift;
	return $self->get_struct('host.get_supported_bootloaders');
}

sub get_logging {
	my $self = shift;
	return $self->get_struct('host.get_logging');
}

sub get_suspend_image_sr {
	my $self = shift;
	return $self->get_generic('host.get_suspend_image_sr');
}

sub get_crash_dump_sr {
	my $self = shift;
	return $self->get_generic('host.get_crash_dump_sr');
}

sub get_crashdumps {
	my $self = shift;
	return $self->get_generic('host.get_crashdumps');
}

sub get_patches {
	my $self = shift;
	return $self->get_struct('host.get_patches');
}

sub get_allowed_operations {
	my $self = shift;
	return $self->get_struct('host.get_allowed_operations');
}

sub get_current_operations {
	my $self = shift;
	return $self->get_struct('host.get_current_operations');
}

sub get_license_params {
	my $self = shift;
	return $self->get_struct('host.get_license_params');
}

sub get_ha_statefiles {
	my $self = shift;
	return $self->get_struct('host.get_ha_statefiles');
}

sub get_ha_network_peers {
	my $self = shift;
	return $self->get_struct('host.get_ha_network_peers');
}

sub get_blobs {
	my $self = shift;
	return $self->get_struct('host.get_blobs');
}

sub get_tags {
	my $self = shift;
	return $self->get_struct('host.get_tags');
}

sub get_external_auth_type {
	my $self = shift;
	return $self->get_generic('host.get_external_auth_type');
}

sub get_external_auth_service_name {
	my $self = shift;
	return $self->get_generic('host.get_external_auth_service_name');
}

sub get_external_auth_configuration {
	my $self = shift;
	return $self->get_struct('host.get_external_auth_configuration');
}

sub get_edition {
	my $self = shift;
	return $self->get_generic('host.get_edition');
}

sub get_license_server {
	my $self = shift;
	return $self->get_struct('host.get_license_server');
}

sub get_bios_strings {
	my $self = shift;
	return $self->get_struct('host.get_bios_strings');
}

sub get_chipset_info {
	my $self = shift;
	return $self->get_generic('host.get_chipset_info');
}

sub get_record {
	my $self = shift;
	return $self->get_generic('host.get_record');
}

sub get_cpu_configuration {
	my $self = shift;
	return $self->get_struct('host.get_cpu_configuration');
}

sub get_cpu_info {
	my $self = shift;
	return $self->get_struct('host.get_cpu_info');
}

sub get_metrics {
	my $self = shift;
	return $self->get_generic('host.get_metrics');
}

sub get_thread_diagnostics {
	my $self = shift;
	return $self->get_generic('host.get_thread_diagnostics');
}

sub get_other_config {
	my $self = shift;
	return $self->get_generic('host.get_other_config');
}

sub get_log {
	my $self = shift;
	return $self->get_generic('host.get_log');
}

sub get_vms_which_prevent_evacuation {
	my $self = shift;
	return $self->get_generic('host.get_vms_which_prevent_evacuation');
}

sub get_uncooperative_resident_vms {
	my $self = shift;
	return $self->get_generic('host.get_uncooperative_resident_VMs');
}

sub get_uncooperative_domains {
	my $self = shift;
	return $self->get_generic('host.get_uncooperative_domains');
}

sub get_system_status_capabilities {
	my $self = shift;
	return $self->get_generic('host.get_system_status_capabilities');
}

sub get_diagnostic_timing_stats {
	my $self = shift;
	return $self->get_generic('host.get_diagnostic_timing_stats');
}

sub get_servertime {
	my $self = shift;
	return $self->get_generic('host.get_servertime')->{'dateTime.iso8601'};
}

sub get_server_localtime {
	my $self = shift;
	return $self->get_generic('host.get_server_localtime')->{'dateTime.iso8601'};
}

sub get_server_certificate {
	my $self = shift;
	return $self->get_generic('host.get_server_certificate');
}

sub get_local_cache_sr {
	my $self = shift;
	return $self->get_generic('host.get_local_cache_sr');
}

sub get_sm_diagnostics {
	my $self = shift;
	return $self->get_generic('host.get_sm_diagnostics');
}

sub get_resident_vms {
	my $self = shift;
	return $self->get_objects('XenAPI::VM', 'host.get_resident_VMs', []);
}

sub get_cpus {
	my $self = shift;
	return $self->get_generic('host.get_host_CPUs');
}

sub get_pifs {
	my $self = shift;
	return $self->get_generic('host.get_PIFs');
}

sub get_pbds {
	my $self = shift;
	return $self->get_generic('host.get_PBDs');
}

sub get_pgpus {
	my $self = shift;
	return $self->get_generic('host.get_PGPUs');
}

sub get_pcis {
	my $self = shift;
	return $self->get_generic('host.get_PCIs');
}

sub get_rrd_update {
	my ($self, $start, $cf) = @_;
	my $uuid = $self->get_uuid();
	my $rrd = new XenAPI::RRD($self->{session}->rrd_updates($start, 1, $self->get_address(), $cf));
	return $rrd->get_host_data($uuid);
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

sub get_objects {
	my ($self, $class, $property, $args) = @_;
	my $list = [];
	my $result = $self->method($property, $args);
	return undef if (!exists($result->{Value}->{value}->{array}[0]->{value}));
	my $objs = $result->{Value}->{value}->{array}[0]->{value};
	if (ref($objs) eq 'ARRAY') {
		push(@{$list}, $class->new($self->{session}, $_)) foreach (@{$objs});
	} else {
		push(@{$list}, $class->new($self->{session}, $objs)) if ($objs);
	}
	return $list;
}

sub method {
	my ($self, $method, $args) = @_;
	die [ 'SESSION_INVALID', 'Handle', 'Bad Session handle' ] if (!$self->{session});
	unshift(@{$args}, {string => $self->{host_ref}});
	return $self->{session}->method($method, $args);
}

1;
