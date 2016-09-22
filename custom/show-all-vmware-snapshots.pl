#!/usr/bin/perl
#
# Nagios check for dated VMware Snapshots. Works with vCenter 4&5
#
# This check searches the vCenter for snapshots and notifies when there is a
# Snapshots that is older than 3 Days. (Based on best practices KB1025279) 
# This check produces a warning when a old snapshot is found. You can change 
# the exit code when you want to receive a critial state.
#
# Author: Florian Grehl - www.virten.net
# Version: 1.0 - January 2013
#
# http://www.virten.net/2013/01/nagios-check-vmware-virtual-machine-snapshot-age/
#
# Usage:
# ./check_snapshot.pl --server <VCENTER> --username <USER> --password <PW>
#

use VMware::VIRuntime; 
#yum install perl-DateTime-Format-DateParse to get this to work ~Larry
use Date::Parse;
use POSIX;

my @old_snapshots = ();

Opts::parse();
Opts::validate();
Util::connect();

my $vm = Vim::find_entity_views(view_type => 'VirtualMachine');

# 1 Day = 86400s
# 3 Days = 259200s
# 1 Week = 604800s
sub check_age {
  my $date_created = shift;
  return(1) if ((time() - $date_created) > 1);
  return(0);
}

sub check_snaplist {
  my $vm_name = shift;
  my $vm_snaptree = shift;
  foreach my $vm_snapshot (@{$vm_snaptree}) {
    my $date_snapshot = str2time($vm_snapshot->{createTime});
    next unless (check_age($date_snapshot));
    $old_snapshots[scalar(@old_snapshots)] = {
      'vm' => $vm_name,
      'age' => ceil(((time() - $date_snapshot)/86400)),
    };
  }
}

foreach my $vm_view (@{$vm}) {
  my $vm_name     = $vm_view->{summary}->{config}->{name};
  my $vm_snaptree = $vm_view->{snapshot};
  next unless defined $vm_snaptree;
  check_snaplist($vm_name, $vm_snaptree->{rootSnapshotList});
}

if (scalar(@old_snapshots) > 0){
  print "Old Snapshots found.\n";
  map {
    printf "%s (%s Days) \n",
    $_->{'vm'}, $_->{'age'}
  } @old_snapshots;
  exit 1; # Nagios: Warning
# exit 2; # Nagios: Critical
}
else{ 
  print "No Snapshots found.\n"; 
  exit 0; # Nagios: OK
}
