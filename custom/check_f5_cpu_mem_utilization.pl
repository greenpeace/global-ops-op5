#!/usr/bin/perl

# somewhat based on http://www.sladder.org/?p=317
#=============================================================================================================================
#       FILE:  check_f5_cpu_mem_utilization.pl
#       USAGE:  ./check_f5_cpu_mem_utilization.pl 
#       <f5_host> <community_string> <cpu warn threshold> <cpu err threshold> <memory warn threashold> <memory err threashold> 
#       description:  checks CPU and memory utilization on F5 using SNMP 
#       author:  Jess Portnoy <kernel01@gmail.com> 
#       VERSION:  0.1
#       CREATED:  06/08/2013 02:34:58 AM EDT
#       REVISION:  ---
#       CHANGELOG:
#==============================================================================================================================
use strict;
use warnings;
use Net::SNMP qw(:snmp);
#use Data::Dumper;

if ($#ARGV < 5 ){ 
	print "Usage:\n $0 <f5_host> <community_string> <cpu warn threshold> <cpu err threshold> <memory warn threashold> <memory err threashold>\n";
	exit (-1);
}


my %ERRORS=('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3);
my $host = $ARGV[0];
my $snmp_comm = $ARGV[1];
my $cpu_warn = $ARGV[2];
my $cpu_crit = $ARGV[3];
my $mem_warn = $ARGV[4];
my $mem_crit = $ARGV[5];

chomp $host;
chomp $snmp_comm;
chomp $cpu_warn;
chomp $cpu_crit;
chomp $mem_warn;
chomp $mem_crit;

#oids
my $tmmTotalCyl = '.1.3.6.1.4.1.3375.2.1.1.2.1.41.0';
my $tmmIdleCyl = '.1.3.6.1.4.1.3375.2.1.1.2.1.42.0';
my $tmmSleepCyl = '.1.3.6.1.4.1.3375.2.1.1.2.1.43.0';
my $sysStatMemoryTotal='.1.3.6.1.4.1.3375.2.1.1.2.1.44.0';
my $sysStatMemoryUsed='.1.3.6.1.4.1.3375.2.1.1.2.1.45.0';

my ($session, $error) = Net::SNMP->session(
-hostname => $host,
-community => $snmp_comm,
-port => 161,
-version => 'snmpv2c',
-nonblocking => 0
);

if (!defined $session)
{
	print "Received no SNMP response from $host\n";
	print STDERR "Error: $error\n";
	exit -2;
}

# poll CPU oids
my $polled_oids_0 = $session->get_request(
-varbindlist =>
[$tmmTotalCyl, $tmmIdleCyl, $tmmSleepCyl] );

sleep 10;
my $polled_oids_1 = $session->get_request(-varbindlist => [$tmmTotalCyl, $tmmIdleCyl, $tmmSleepCyl]);
#debug
#print Dumper($polled_oids_1);
my $tmm_cpu = (( ($polled_oids_1->{$tmmTotalCyl} - $polled_oids_0->{$tmmTotalCyl}) - ( ($polled_oids_1->{$tmmIdleCyl} - $polled_oids_0->{$tmmIdleCyl}) + ($polled_oids_1->{$tmmSleepCyl} - $polled_oids_0->{$tmmSleepCyl}) )) / ($polled_oids_1->{$tmmTotalCyl} - $polled_oids_0->{$tmmTotalCyl}) ) * 100 ;

# Round to integer
$tmm_cpu = int($tmm_cpu + .5);

# poll memory oids
$polled_oids_1 = $session->get_request(-varbindlist => [$sysStatMemoryUsed, $sysStatMemoryTotal]);
#print Dumper $polled_oids_1;
my $mem_prct=$polled_oids_1->{$sysStatMemoryUsed}/$polled_oids_1->{$sysStatMemoryTotal}*100;
$mem_prct = int($mem_prct + .5);
my $RC=undef;
if($tmm_cpu > $cpu_crit) {
	print "CRITICAL: TMM CPU utilization on $host is higher than threashold ($cpu_crit) - $tmm_cpu%\n";
	$RC=$ERRORS{"CRITICAL"};
}
if($mem_prct > $mem_crit){
	print "CRITICAL: TMM Memory utilization on $host is higher than threashold ($mem_crit) - $mem_prct%\n";
	$RC=$ERRORS{"CRITICAL"};
}
if($tmm_cpu > $cpu_warn) {
	print "WARNING: TMM CPU utilization on $host is higher than threashold ($cpu_warn) - $tmm_cpu%\n";
	$RC=$ERRORS{"WARNING"};
}
if($mem_prct > $mem_warn){
	print "WARNING: TMM Memory utilization on $host is higher than threashold ($mem_warn) - $mem_prct%\n";
	$RC=$ERRORS{"WARNING"};
}
if (!defined $RC){
	print "OK: TMM CPU on $host is $tmm_cpu%\n";
	print "OK: TMM Memory utilization on $host is $mem_prct%\n";
	$RC=$ERRORS{"OK"};
}
exit($RC);
