package XenAPI::SR;

use strict;
use warnings;

use Data::Dumper;

sub new {
	my ($class, $session, $sr_ref) = @_;
	return bless { session => $session, sr_ref => $sr_ref }, $class;
}

sub get_uuid {
	my $self = shift;
	return $self->get_generic('SR.get_uuid');
}

sub get_name {
	my $self = shift;
	return $self->get_generic('SR.get_name_label');
}

sub get_description {
	my $self = shift;
	return $self->get_generic('SR.get_name_description');
}

sub get_current_operations {
	my $self = shift;
	return $self->get_generic('SR.get_current_operations');
}

sub get_allowed_operations {
	my $self = shift;
	return $self->get_generic('SR.get_allowed_operations');
}

sub get_vdis {
	my $self = shift;
	return $self->get_generic('SR.get_VDIs');
}

sub get_pbds {
	my $self = shift;
	return $self->get_generic('SR.get_PBDs');
}

sub get_virtual_allocation {
	my $self = shift;
	return $self->get_generic('SR.get_virtual_allocation');
}

sub get_physical_utilisation {
	my $self = shift;
	return $self->get_generic('SR.get_physical_utilisation');
}

sub get_physical_size {
	my $self = shift;
	return $self->get_generic('SR.get_physical_size');
}

sub get_type {
	my $self = shift;
	return $self->get_generic('SR.get_type');
}

sub get_content_type {
	my $self = shift;
	return $self->get_generic('SR.get_content_type');
}

sub get_shared {
	my $self = shift;
	return $self->get_generic('SR.get_shared');
}

sub get_tags {
	my $self = shift;
	return $self->get_generic('SR.get_tags');
}

sub get_sm_config {
	my $self = shift;
	return $self->get_generic('SR.get_sm_config');
}

sub get_blobs {
	my $self = shift;
	return $self->get_generic('SR.get_shared');
}

sub get_local_cache_enabled {
	my $self = shift;
	return $self->get_generic('SR.get_local_cache_enabled');
}

sub get_introduced_by {
	my $self = shift;
	return $self->get_generic('SR.get_introduced_by');
}

sub get_generic {
	my ($self, $property) = @_;
	my $result = $self->method($property, []);
	return $result->{Value}->{value};
}

sub method {
	my ($self, $method, $args) = @_;
	die [ 'SESSION_INVALID', 'Handle', 'Bad Session handle' ] if (!$self->{session});
	unshift(@{$args}, {string => $self->{sr_ref}});
	return $self->{session}->method($method, $args);
}

1;
