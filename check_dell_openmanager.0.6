#!/usr/bin/perl -w
#
# ============================== SUMMARY =====================================
#
# Program : check_dell_openmanager.pl
# Version : 0.6
# Date    : Nov 15 2007
# Author  : Jason Ellison - infotek@gmail.com
# Summary : This is a nagios plugin that checks the status of objects
#           monitored by Open Manager status on Dell PowerEdge 
#           servers via SNMP
# Licence : GPL - summary below, full text at http://www.fsf.org/licenses/gpl.txt
#
# =========================== PROGRAM LICENSE =================================
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#
# ===================== INFORMATION ABOUT THIS PLUGIN =========================
#
# This plugin checks the status of objects monitored by OpenManager via SNMP
# and returns OK, WARNING, CRITICAL or UNKNOWN.  If a failure occurs it will
# describe the subsystem that failed and the failure code.
#
# This program is written and maintained by:
#   Jason Ellison - infotek(at)gmail.com
#
# It is based on check_snmp_temperature.pl plugin by:
#   William Leibzon - william(at)leibzon.org
#
# Using information from the NagiosExchange article titled
# "Article: Dell OpenManage status OIDs"
#
# system type "pe2950" monitors the following OID's:
# systemStateChassisStatus .1.3.6.1.4.1.674.10892.1.200.10.1.4.1 
# systemStatePowerSupplyStatusCombined .1.3.6.1.4.1.674.10892.1.200.10.1.9.1 
# systemStateVoltageStatusCombined .1.3.6.1.4.1.674.10892.1.200.10.1.12.1 
# systemStateCoolingDeviceStatusCombined .1.3.6.1.4.1.674.10892.1.200.10.1.21.1 
# systemStateTemperatureStatusCombined .1.3.6.1.4.1.674.10892.1.200.10.1.24.1 
# systemStateMemoryDeviceStatusCombined .1.3.6.1.4.1.674.10892.1.200.10.1.27.1 
# systemStateChassisIntrusionStatusCombined .1.3.6.1.4.1.674.10892.1.200.10.1.30.1 
# systemStateEventLogStatus .1.3.6.1.4.1.674.10892.1.200.10.1.41.1
#
# ============================= SETUP NOTES ====================================
#
# Copy this file to your Nagios installation folder in "libexec/". Rename 
# to "check_dell_openmanager.pl".
#
# You must have Open Manager installed on the server.  You must have enabled
# SNMP on the server and allow SNMP queries.  On the server that will be
# running the plugin you must have the perl "Net::SNMP" module installed.
#
# perl -MCPAN -e shell
# cpan> install "Net::SNMP"
#
# Check Open Manager on the local host for alert threshholds like min/max
# fan speeds...
#
# ========================= SETUP EXAMPLES ==================================
#
# define command{
#       command_name    check_dell_open_manager
#       command_line    $USER1$/check_dell_openmanager.pl -H $HOSTADDRESS$ -C $ARG1$ -T $ARG2$
#       }
#
# define service{
#       use                     windowserver
#       host_name               DELL-SERVER-00
#       service_description     Open Manager Status
#       check_command           check_dell_open_manager!public!pe2950
#       normal_check_interval   3
#       retry_check_interval    1
#       }
#
# =================================== TODO ===================================
#
# + GlobalSystemStatus should be checked.  Only if GloballSystemStatus
# reports a failure should the other OID's be checked.
#
# + Verify and add other dell server types
#
# ================================ REVISION ==================================
#
# ver 0.6
#
# + Added StorageManagement GlobalSystemStatus
# StorageManagement-MIB::agentGlobalSystemStatus
# .1.3.6.1.4.1.674.10893.1.20.110.13.0
#
# ver 0.5
#
# + Cleaned up verbose output for debugging
#
# ver 0.4
#
# + Fixed major flaw in logic that cause errors to not be reported.
#
#
# + Added to the system_types error warning and unkown variables like seen on
# http://www.mail-archive.com/intermapper-talk@list.dartware.com/msg02687.html
# below section: "This section performs value to text conversions"
#
# ========================== START OF PROGRAM CODE ============================

use strict;
use Net::SNMP;
use Getopt::Long;
my $TIMEOUT = 20;
my %ERRORS=('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);
my %system_types = ( 
		     "dellom" => [ ['GlobalSystemStatus', 'ChassisStatus', 'PowerSupplyStatusCombined', 'VoltageStatusCombined', 'CoolingDeviceStatusCombined', 'TemperatureStatusCombined', 'MemoryDeviceStatusCombined', 'IntrusionStatusCombined', 'EventLogStatus'], ['.1.3.6.1.4.1.674.10892.1.200.10.1.2.1', '.1.3.6.1.4.1.674.10892.1.200.10.1.4.1', '.1.3.6.1.4.1.674.10892.1.200.10.1.9.1', '.1.3.6.1.4.1.674.10892.1.200.10.1.12.1', '.1.3.6.1.4.1.674.10892.1.200.10.1.21.1', '.1.3.6.1.4.1.674.10892.1.200.10.1.24.1', '.1.3.6.1.4.1.674.10892.1.200.10.1.27.1', '.1.3.6.1.4.1.674.10892.1.200.10.1.30.1', '.1.3.6.1.4.1.674.10892.1.200.10.1.41.1'] ],
		     "pe2950" => [ ['Chassis Status', 'Power Supply Status', 'Voltage Status', 'Cooling Device Status', 'Temperature Status', 'Memory Device Status', 'Intrusion Status', 'Event Log Status', 'Storage Management Status'], ['.1.3.6.1.4.1.674.10892.1.200.10.1.4.1', '.1.3.6.1.4.1.674.10892.1.200.10.1.9.1', '.1.3.6.1.4.1.674.10892.1.200.10.1.12.1', '.1.3.6.1.4.1.674.10892.1.200.10.1.21.1', '.1.3.6.1.4.1.674.10892.1.200.10.1.24.1', '.1.3.6.1.4.1.674.10892.1.200.10.1.27.1', '.1.3.6.1.4.1.674.10892.1.200.10.1.30.1', '.1.3.6.1.4.1.674.10892.1.200.10.1.41.1', '.1.3.6.1.4.1.674.10893.1.20.110.13.0'] ],
		     "ucdavis" => [ ['Chassis Status', 'Power Supply Status', 'Voltage Status', 'Cooling Device Status', 'Temperature Status', 'Memory Device Status', 'Intrusion Status', 'Event Log Status'], ['.1.3.6.1.4.1.2021.255.1','.1.3.6.1.4.1.2021.255.2','.1.3.6.1.4.1.2021.255.3','.1.3.6.1.4.1.2021.255.4','.1.3.6.1.4.1.2021.255.5','.1.3.6.1.4.1.2021.255.6','.1.3.6.1.4.1.2021.255.7','.1.3.6.1.4.1.2021.255.8'] ],
		   );
my $Version='0.6';
my $o_host=     undef;          # hostname
my $o_community= undef;         # community
my $o_port=     161;            # SNMP port
my $o_help=     undef;          # help option
my $o_verb=     undef;          # verbose mode
my $o_version=  undef;          # version info option
my $o_warn=     undef;          # warning level option
my @o_warnL=    ();             # array for above list
my $o_crit=     undef;          # Critical level option
my @o_critL=    ();             # array for above list
my $o_timeout=  5;              # Default 5s Timeout
my $o_version2= undef;          # use snmp v2c
# SNMPv3 specific
my $o_login=    undef;          # Login for snmpv3
my $o_passwd=   undef;          # Pass for snmpv3
my $o_attr=	undef;  	# What attribute(s) to check (specify more then one separated by '.')
my @o_attrL=    ();             # array for above list
my $oid_names=	undef;		# OID for base of sensor attribute names
my $oid_data=	undef;		# OID for base of actual data for those attributes found when walking name base
my $oid_resp=	undef;		# The expected response from the OID get
my $o_unkdef=	undef;		# Default value to report for unknown attributes
my $o_type=	undef;		# Type of system to check (predefined values for $oid_names, $oid_data, $oid_resp)

sub print_version { print "$0: $Version\n" };

sub print_usage {
	print "Usage: $0 [-v] -H <host> -C <snmp_community> [-2] | (-l login -x passwd)  [-P <port>] -T dellom|pe2950 [-f] [-t <timeout>] [-V] [-u <unknown_default>]\n";
}

# Return true if arg is a number
sub isnum {
	my $num = shift;
	if ( $num =~ /^(\d+\.?\d*)|(^\.\d+)$/ ) { return 1 ;}
	return 0;
}

sub help {
	print "\nSNMP Dell OpenManager Monitor for Nagios version ",$Version,"\n";
	print " by Jason Ellison - infotek(at)gmail.com\n\n";
	print_usage();
	print <<EOD;
-v, --verbose
	print extra debugging information
-h, --help
	print this help message
-H, --hostname=HOST
	name or IP address of host to check
-C, --community=COMMUNITY NAME
	community name for the host's SNMP agent (implies v 1 protocol)
-2, --v2c 
        use SNMP v2 (instead of SNMP v1)
-P, --port=PORT
	SNMPd port (Default 161)
-w, --warn=INT[,INT[,INT[..]]]
	warning temperature level(s) (if more then one attribute is checked, must have multiple values)
-c, --crit=INT[,INT[,INT[..]]]
	critical temperature level(s) (if more then one attribute is checked, must have multiple values)
-t, --timeout=INTEGER
	timeout for SNMP in seconds (Default: 5)
-V, --version
	prints version number
-u, --unknown_default=INT
        If attribute is not found then report the output as this number (i.e. -u 0)
-T, --type=pe2950|dellom
	This allows to use pre-defined system type to set Base, Data OIDs and incoming temperature measurement type
	Currently support systems types are: 
		dellom (dell OpenManager general)
		pe2950 (PowerEdge 2950)
EOD
}

# For verbose output - don't use it right now
sub verb { my $t=shift; print $t,"\n" if defined($o_verb) ; }
# Get the alarm signal (just in case snmp timout screws up)
$SIG{'ALRM'} = sub {
     print ("ERROR: Alarm signal (Nagios time-out)\n");
     exit $ERRORS{"UNKNOWN"};
};
sub check_options {
    Getopt::Long::Configure ("bundling");
    GetOptions(
        'v'     => \$o_verb,            'verbose'       => \$o_verb,
        'h'     => \$o_help,            'help'          => \$o_help,
        'H:s'   => \$o_host,            'hostname:s'    => \$o_host,
        'P:i'   => \$o_port,            'port:i'        => \$o_port,
        'C:s'   => \$o_community,       'community:s'   => \$o_community,
        'l:s'   => \$o_login,           'login:s'       => \$o_login,
        'x:s'   => \$o_passwd,          'passwd:s'      => \$o_passwd,
        't:i'   => \$o_timeout,         'timeout:i'     => \$o_timeout,
        'V'     => \$o_version,         'version'       => \$o_version,
        '2'     => \$o_version2,        'v2c'           => \$o_version2,
	'u:i'	=> \$o_unkdef,		'unknown_default:i' => \$o_unkdef,
	'T:s'   => \$o_type,		'type:s'	=> \$o_type
    );
    if (defined($o_help) ) { help(); exit $ERRORS{"UNKNOWN"}; }
    if (defined($o_version)) { print_version(); exit $ERRORS{"UNKNOWN"}; }
    if (! defined($o_host) ) # check host and filter
        { print "No host defined!\n";print_usage(); exit $ERRORS{"UNKNOWN"}; }
    # check snmp information
    if (!defined($o_community) && (!defined($o_login) || !defined($o_passwd)) )
        { print "Put snmp login info!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}; }
    if (!defined($o_type)) { print "Must define system type!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}; }
    if (defined ($o_type)) {
	if (defined($system_types{$o_type})) {
	   $oid_names = $system_types{$o_type}[0];
	   $oid_data = $system_types{$o_type}[1];
	}
	else { print "Unknown system type $o_type !\n"; print_usage(); exit $ERRORS{"UNKNOWN"}; }
    }
}
########## MAIN #######
check_options();
# Check global timeout if something goes wrong
if (defined($TIMEOUT)) {
  verb("Alarm at $TIMEOUT");
  alarm($TIMEOUT);
} else {
  verb("no timeout defined : $o_timeout + 10");
  alarm ($o_timeout+10);
}
# SNMP Connection to the host
my ($session,$error);
if (defined($o_login) && defined($o_passwd)) {
  # SNMPv3 login
  verb("SNMPv3 login");
  ($session, $error) = Net::SNMP->session(
      -hostname         => $o_host,
      -version          => '3',
      -username         => $o_login,
      -authpassword     => $o_passwd,
      -authprotocol     => 'md5',
      -privpassword     => $o_passwd,
      -timeout          => $o_timeout
   );
} else {
   if (defined ($o_version2)) {
     # SNMPv2 Login
         ($session, $error) = Net::SNMP->session(
        -hostname  => $o_host,
            -version   => 2,
        -community => $o_community,
        -port      => $o_port,
        -timeout   => $o_timeout
     );
   } else {
    # SNMPV1 login
    ($session, $error) = Net::SNMP->session(
       -hostname  => $o_host,
       -community => $o_community,
       -port      => $o_port,
       -timeout   => $o_timeout
    );
  }
}
# next part of the code builds list of attributes to be retrieved
my $i;
my $oid;
my $line;
my $resp;
my $attr;
my @varlist = ();
my %dataresults;
for ($i=0;$i<scalar(@{$oid_names});$i++) {
  $dataresults{$oid_names->[$i]} = [ $oid_data->[$i], undef ];
  #verb("dataresults stuffed with oid_name $oid_names->[$i] oid_data $oid_data->[$i]");
  push(@varlist, $oid_data->[$i]);
}

verb("Getting SNMP data for oids: " . join(" ",@varlist) . "\n");

my $result;

$result = $session->get_request(
	-Varbindlist => \@varlist
);
if (!defined($result)) {
        printf("ERROR: Can not retrieve OID(s) %s: %s.\n", join(" ",@varlist), $session->error);
        $session->close();
        exit $ERRORS{"UNKNOWN"};
}
else {
	foreach $attr (keys %dataresults) {
	    if (defined($$result{$dataresults{$attr}[0]})) {
               $dataresults{$attr}[1]=$$result{$dataresults{$attr}[0]};
  	       verb("attr = $attr \n snmp_oid = $dataresults{$attr}[0] \n snmp_response = $dataresults{$attr}[1] \n");
	    }
	    else { 
		if (defined($o_unkdef)) {
		   $dataresults{$attr}[1]=$o_unkdef;
		   verb("could not find snmp data for $attr, setting to to default value $o_unkdef");
		}
		else {
		   verb("could not find snmp data for $attr");
		}
	    }
	}
} 

# loop to check if warning & critical attributes are ok
verb("Loop through SNMP responses...");

my $statuscode = "OK";
my $statusinfo = "";
my $statusdata = "";

my $statuscritical = "0";
my $statuswarning = "0";
my $statusunknown = "0";

foreach $attr (keys %dataresults) {
    if ($dataresults{$attr}[1] eq "6") {
        $statuscritical = "1";
   	$statuscode="CRITICAL";
        $statusinfo .= ", " if ($statusinfo);
	$statusinfo .= "$attr=Non-Recoverable";
    }
    elsif ($dataresults{$attr}[1] eq "5") {
        $statuscritical="1";
	$statuscode="CRITICAL";
	$statusinfo .= ", " if ($statusinfo);
	$statusinfo .= "$attr=Critical";
    }
    elsif ($dataresults{$attr}[1] eq "4") {
        $statuswarning = "1";
	$statuscode="WARNING";
	$statusinfo .= ", " if ($statusinfo);
	$statusinfo .= "$attr=Non-Critical";
    }
    elsif ($dataresults{$attr}[1] eq "2") {
        $statusunknown = "1";
	$statuscode="UNKNOWN";
	$statusinfo .= ", " if ($statusinfo);
	$statusinfo .= "$attr=UKNOWN";
    }
    elsif ($dataresults{$attr}[1] eq "1") {
        $statusunknown = "1";
	$statuscode="UNKNOWN";
	$statusinfo .= ", " if ($statusinfo);
	$statusinfo .= "$attr=Other";
    }
    elsif ($dataresults{$attr}[1] eq "3") {
	$statuscode="OK";
    }
    else {
	$statusunknown = "1";
        $statuscode="UNKNOWN";
        $statusinfo .= ", " if ($statusinfo);
        $statusinfo .= "$attr=UKNOWN";
    }
    verb("$attr: statuscode = $statuscode");
}
$session->close;

$statuscode="OK";

if ($statuscritical eq '1'){
  $statuscode="CRITICAL";
}
elsif ($statuswarning eq '1'){
  $statuscode="WARNING";
}
elsif ($statusunknown eq '1'){
  $statuscode="UNKNOWN";
}

#printf("$statuscode:");
if ($statuscode ne 'OK'){
  printf("$statuscode:$statusinfo");
}
else {
  printf("$statuscode");
}
print "\n";

exit $ERRORS{$statuscode};
