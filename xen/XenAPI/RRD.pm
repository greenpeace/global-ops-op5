package XenAPI::RRD;

use strict;
use warnings;

use XML::Simple;
use Data::Dumper;

sub new {
	my ($class, $xml) = @_;
	my ($columns, $rows, $start, $end, $step, $data);
	my ($host, $vm) = ({}, {});

	my $rrd;
	if ($xml) {
		$rrd = XMLin($xml, ForceArray => [ 'row' ]);
		$columns = $rrd->{meta}->{columns};
		$rows = $rrd->{meta}->{rows};
		$start = $rrd->{meta}->{start};
		$end = $rrd->{meta}->{end};
		$step = $rrd->{meta}->{step};
		$data = $rrd->{data}->{row};
		my $pos = 0;
		foreach my $label (@{$rrd->{meta}->{legend}->{entry}}) {
			my ($cf, $vm_or_host, $uuid, $param) = split(/:/, $label, 4);
			if ($vm_or_host eq 'vm') {
				$vm->{$uuid}->{$param}->{$cf} = $pos;
			} elsif ($vm_or_host eq 'host') {
				$host->{$uuid}->{$param}->{$cf} = $pos;
			} else {
			}
			$pos++;
		}
	}

	return bless { columns => $columns, rows => $rows, start => $start, end => $end, step => $step, hosts => $host, vms => $vm, data => $data }, $class;
}

sub get_vm_data {
    my ($self, $uuid) = @_;
    return $self->_get_object_data('vms', $uuid);
}

sub get_host_data {
    my ($self, $uuid) = @_;
    return $self->_get_object_data('hosts', $uuid);
}

sub _get_object_data {
    my ($self, $type, $uuid) = @_;
    my $data = [];
    if (exists($self->{data})) {
        my $object = $self->{$type}->{$uuid};
        foreach my $row (@{$self->{data}}) {
            my $perf = {timestamp => $row->{t}, data => {}};
            foreach my $counter (keys(%{$object})) {
                $perf->{data}->{$counter} = {};
                foreach my $rollup (keys(%{$object->{$counter}})) {
                    $perf->{data}->{$counter}->{$rollup} = $row->{v}[$object->{$counter}->{$rollup}];
                }
            }
            push(@{$data}, $perf);
        }
    }
    return $data;
}

1;
