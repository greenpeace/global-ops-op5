#!/usr/bin/perl
#
# Title: check_cmc
# Nagios plugin to monitor RITTAL-CMC-TC using SNMP
#
# License: GPL
# Copyright (c) 2007-2009 op5 AB
# Author: Per Asberg <per.asberg@op5.com>,
#         Henrik Nilsson <henrik30000@gmail.com>
#
# For direct contact with any of the op5 developers send a mail to
# dev@op5.com
# Discussions are directed to the mailing list op5-users@op5.com,
# see http://lists.op5.com/mailman/listinfo/op5-users
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#
# Description:
#
# The purpose of this plugin is to monitor Rittal-CMC-TC via SNMP and it is intended to be used as a Nagios plugin <http://www.nagios.org/>
# through OP5 Monitor <http://www.op5.se>.
# Since it is possible to attach a wide variety of probes of different kind to the CMC as well as several units, possibly making the system
# quite complex, this plugin is trying to deal with this complexity.
# In most Nagios plugins the warn/crit levels are usually seen as "sequential" when monitoring processes that could be described as
# "less is better" (CPU load, Ping, etc...). When monitoring temperature or voltage the situation is, of course,
# somewhat different. To deal with these differences, the need for "ranges" has emerged.
#
# Threshold and ranges:
# (See <http://nagiosplug.sourceforge.net/developer-guidelines.html#THRESHOLDFORMAT>).
# A range is defined as a start and end point (inclusive) on a numeric scale (possibly negative or positive infinity).
# A threshold is a range with an alert level (either warning or critical). Use the set_thresholds(thresholds *, char *, char *) function to set the thresholds.
# The theory is that the plugin will do some sort of check which returns back a numerical value, or metric, which is then compared to the warning and critical
# thresholds. Use the get_status(double, thresholds *) function to compare the value against the thresholds.
#
# The generalized format for ranges:
# [@]start:end
#
#   + Start â‰¤ end
#   + Start and ":" is not required if start=0
#   + If range is of format "start:" and end is not specified, assume end is infinity
#   + To specify negative infinity, use "~"
#   + Alert is raised if metric is outside start and end range (inclusive of endpoints)
#   + If range starts with "@", then alert if inside this range (inclusive of endpoints)
#
#
# Switches:
# :-? [--usage]		Print usage information
# :-h [--help]      Print detailed help screen
# :-V [--version]   Print version information
# :-w [--warning]   Warning level 	(INTEGER:INTEGER)
# : 				Minimum and maximum number of allowable result, outside of which a
# : 				warning will be generated. If omitted, no warning is generated.
# :-c [--critical]  Critical level 	(INTEGER:INTEGER)
# : 				Minimum and maximum number of the generated result, outside of
# : 				which a critical will be generated.
# :-H [--hostname]  Name or IP address of host to check
# :-C [--community] Community name for the host's SNMP agent (implies v1 protocol)
# :-t [--timeout]   Timeout for SNMP in seconds (Default: 5)
# :-u [--unit]      Unit to monitor (int)
# :-p [--probe]     Probe to check (int)
# :-T [--type]      Type of probe to check (access|temperature|voltage|...)
# :-s [--status]	Print status for all attached devices
# :-v [--verbose]   Print extra debugging information
#
# Examples:
# To check the CMC against it's internal settings (cmcTcStatus), i.e. monitor everything connected.
# : $> check_cmc.pl -H 192.168.1.47 -C public
# : $> OK: All systems OK.
#
# To monitor probe 1 on unit 1, CRITICAL if value < 10 or > 55,  WARNING if value < 20 or > 45
# : $> check_cmc.pl -H 192.168.1.47 -C public -u 1 -p 1 -c 10:55
#
# To check all probes of type 'access' (case insensitive) attached to unit 1
# : $> check_cmc.pl -H 192.168.1.47 -C public -u 1 -T access
#
# To check all probes of type access attached as probe 2 on any unit
# : $> check_cmc.pl -H 192.168.1.47 -C public -p 2 -T access
#
# If both -T and -p switches has been set, the plugin checks if the probe id and type matches, if not, a status
# UNKNOWN is returned.
# If no warn/crit levels are defined, it will check if the CMC has been configured with
# unit<n>SensorSetHigh, unit<n>SensorSetLow and unit<n>SensorSetWarn and react according to
# these values. This means that if we are monitoring a temperature probe and it has been set with
# unit<n>SensorSetHigh=65, unit<n>SensorSetLow=10 and unit<n>SensorSetWarn=55 it will issue
# WARNING if temperature reaches above 55 and CRITICAL if temperature drops below 10 or above 65.
# This way the CMC may be configured internally and the plugin reacts to these settings.
# If, on the other hand, unit<n>SensorSet<...> values has not been set, it will act against the unit<n>SensorStatus
# which will respond with...
# : 	1 - notAvail
# : 	2 - lost
# : 	3 - changed
# : 	4 - ok
# : 	5 - off
# : 	6 - on
# : 	7 - warning
# : 	8 - tooLow
# : 	9 - tooHigh
# ..where values >= 8 will be interpreted as CRITICAL and 4 as OK, the others will render a WARNING state.
#
# Requirements:
# The following external packages are required:
#	+ strict
#	+ warnings
#	+ Net::SNMP
#	+ Nagios::Plugin
#	+ utils
#

##############################################################################
# prologue
use strict;
use warnings;
use Net::SNMP;
use Nagios::Plugin ;

use vars qw($VERSION $PROGNAME $verbose $timeout $result);
'$Revision: 1.1 $' =~ /^.*(\d+.\d+) \$$/;

# var: $VERSION
# Version of plugin
$VERSION = $1;

# get the base name of this script
use File::Basename;
$PROGNAME = basename($0);

##############################################################################
# define and get the command line options.

# Var: $p
# : usage 	=> str
# : version => str
# : blurb 	=> str
# Instantiate Nagios::Plugin object (the 'usage' parameter is mandatory)
my $p = Nagios::Plugin->new(
	usage => "Usage: %s [ -v|--verbose ] -H --Hostname <host> -C <snmp_community> [-u|--unit <unit>] [-p|--probe <probe>] [-T|--type <Type of probe>] [-t|--timeout <timeout>] [-V] [ -w|--warning=<warning threshold> ] [ -c|--critical=<critical threshold> ] [-s|--status status]\n\n",
	version => $VERSION,
	blurb => '    -------------------------------------------
    Nagios plugin to monitor Rittal CMC by SNMP
    (c)2007-2009 Per Asberg, Henrik Nilsson
    www.op5.se
    -------------------------------------------',

	extra => "

Examples:
To check the CMC against it's internal settings (cmcTcStatus), i.e. monitor everything connected.
: \$> check_cmc.pl -H 192.168.1.47 -C public
: OK: All systems OK.

To monitor probe 1 on unit 1, CRITICAL if value < 10 or > 55,  WARNING if value < 20 or > 45
: \$> check_cmc.pl -H 192.168.1.47 -C public -u 1 -p 1 -c 10:55

To check all probes of type 'access' (case insensitive) attached to unit 1
: \$> check_cmc.pl -H 192.168.1.47 -C public -u 1 -T access

To check all probes of type access attached as probe 2 on any unit
: \$> check_cmc.pl -H 192.168.1.47 -C public -p 2 -T access

THRESHOLDs for -w and -c are specified 'min:max' or 'min:' or ':max'
(or 'max'). If specified '\@min:max', a warning status will be generated
if the count *is* inside the specified range.

If both -T and -p switches has been set, the plugin checks if the probe id and type matches, if not, a status UNKNOWN is returned.
If no warn/crit levels are defined, it will check if the CMC has been configured with unit<n>SensorSetHigh, unit<n>SensorSetLow and unit<n>SensorSetWarn and react according to these values. This means that if we are monitoring a temperature probe and it has been set with unit<n>SensorSetHigh=65, unit<n>SensorSetLow=10 and unit<n>SensorSetWarn=55 it will issue WARNING if temperature reaches above 55 and CRITICAL if temperature drops below 10 or above 65.
This way the CMC may be configured internally and the plugin reacts to these settings.
If, on the other hand, unit<n>SensorSet<...> values has not been set, it will act against the unit<n>SensorStatus
which will respond with...
:     1 - notAvail
:     2 - lost
:     3 - changed
:     4 - ok
:     5 - off
:     6 - on
:     7 - warning
:     8 - tooLow
:     9 - tooHigh
where values >= 8 will be interpreted as CRITICAL and 4 as OK, the others will render a WARNING state."
);

#  Examples
#
#  $PROGNAME -w 10 -c 18 Returns a warning
#  if the result is greater than 10,
#  or a critical error
#  if it is greater than 18.
#
#  $PROGNAME -w 10: -c 4: Returns a warning
#  if the result is less than 10,
#  or a critical error
#  if it is less than 4.

# Define and document the valid command line options
# usage, help, version, timeout and verbose are defined by default.
$p->add_arg(
	spec => 'warning|w=s',

	help =>
qq{-w, --warning=INTEGER:INTEGER
   Minimum and maximum number of allowable result, outside of which a
   warning will be generated.  If omitted, no warning is generated.},
);

$p->add_arg(
	spec => 'critical|c=s',
	help =>
qq{-c, --critical=INTEGER:INTEGER
   Minimum and maximum number of the generated result, outside of
   which a critical will be generated. },
);

$p->add_arg(
	spec => 'hostname|H=s',
	help =>
qq{-H, --hostname=STRING
   Name or IP address of host to check. },
);

$p->add_arg(
	spec => 'community|C=s',
	help =>
qq{-C, --community=STRING
   Community name for the host's SNMP agent (implies v1 protocol). },
);

$p->add_arg(
	spec => 'type|T=s',
	help =>
qq{-T, --type=STRING
   Type of probe to be checked (access/temperature/voltage) - case insensitive. },
);

$p->add_arg(
	spec => 'unit|u=s',
	help =>
qq{-u, --unit=INTEGER
   Unit to be checked. },
);

$p->add_arg(
	spec => 'probe|p=s',
	help =>
qq{-p, --probe=INTEGER
   Probe to check (int). },
);

$p->add_arg(
	spec => 'status|s',
	help =>
qq{-s, --status
   Print status for all attached devices. },
);

# var: %ERRORS
# Constants for return values
#
# : 0 - OK
# : 1 - WARNING
# : 2 - CRITICAL
# : 3 - UNKNOWN
# : 4 - DEPENDENT
my %ERRORS=('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);

# var: $session
# SNMP session object handle
my $session 				= undef;

my $error 					= undef;
my $result 					= undef;

# var: $mib_oid
# OID for CMC status (cmcTcMibCondition)
my $mib_oid					= "1.3.6.1.4.1.2606.4.1.3.0";

my $mib_status				= undef;

# var: $mibReturnCode
# Returncode (status) from CMC when nothing else set to monitor
my $mibReturnCode			= undef;

# var: $base_oid
# Base OID, all OIDs will be concatenated from this base
my $base_oid				= "1.3.6.1.4.1.2606.4.2.";

# var: $oid_nrOfUnits
# OID to get nr of attached units
my $oid_nrOfUnits 			= $base_oid . "2.0";

# var: $nrOfUnits
# Holds the number of discovered units
my $nrOfUnits				= 0;

# var: $sensorTypeInt_oid
# OID part for unit<n>SensorType.
# Gets concatenated to $base_oid
my $sensorTypeInt_oid		= ".5.2.1.2.";

# var: $sensorTypeTxt_oid
# OID part for given type of sensor (by user)
my $sensorTypeTxt_oid		= ".5.2.1.3.";

# var: $sensorStatusTxt_oid
# OID part for unitSensorStatus
my $sensorStatusTxt_oid		= ".5.2.1.4.";

# var: $sensorValue_oid
# OID part for value of sensor
my $sensorValue_oid			= ".5.2.1.5.";

# var: $sensorSetHigh_oid
# OID part for high value limit
my $sensorSetHigh_oid		= ".5.2.1.6.";

# var: $sensorSetLow_oid
# OID part for high value limit
my $sensorSetLow_oid		= ".5.2.1.7.";

# var: $sensorSetWarn_oid
# OID part for high value limit
my $sensorSetWarn_oid		= ".5.2.1.8.";

# var: $isStatusOK
# Global flag if anomaly detected anywhere
my $isStatusOK				= 1;

# var: $o_help
# All o_ variables are fetched from input, ie called upon execution
my $o_help					= undef;					# want some help?
my $o_host					= undef;					# hostname
my $o_community				= undef;					# community
my $o_crit					= undef;					# critical limit
my $o_warn					= undef;					# warning limit
my $o_timeout				= undef;					# SNMP timeout
my $o_unit					= undef;					# Unit to check (int)
my $o_probe					= undef;					# Probe to check (int)
my $o_type					= undef;					# type of probe to check (access|temperature|voltage)
my $o_typeInt				= undef;					# Integer in MIB for requested sensortype
my $o_get_all				= undef;					# print status for all attached units and sensors
my $o_version				= undef;					# Display version for plugin?
my $o_verb					= undef;					# Hold verbose output
my $o_status				= undef;					# Should we display status of attached devices?
my $probeValue				= undef;					# value of probe

# var: %unitSensorStatus
# Translate sensorStatus to readable string
#
# : 1 - notAvail 	(warn)
# : 2 - lost		(warn)
# : 3 - changed		(warn)
# : 4 - ok			(ok)
# : 5 - off			(warn)
# : 6 - on			(warn)
# : 7 - warning		(warn)
# : 8 - tooLow		(crit)
# : 9 - tooHigh		(crit)
my %unitSensorStatus 		= qw(
	1  notAvail
	2  lost
	3  changed
	4  ok
	5  off
	6  on
	7  warning
	8  tooLow
	9  tooHigh
);

# var: %unitStatus
# cmcUnit<n>Status
# Translate Unitstatus (int) to readable string
#
# : 1 - ok			(OK)
# : 2 - error		(CRIT)
# : 3 - changed		(WARN)
# : 4 - quit		(WARN)
# : 5 - timeout		(WARN)
# : 6 - detected	(WARN)
# : 7 - notAvail	(CRIT)
# : 8 - lowPower	(CRIT)
my %unitStatus = qw(
	1 ok
	2 error
	3 changed
	4 quit
	5 timeout
	6 detected
	7 notAvail
	8 lowPower
);

# var: %mibCondition
# Translate cmcMibCondition (int) to string
#
# : 1 - other
# : 2 - OK
# : 3 - a minor problem, warning condition (yellow LED on CMC)
# : 4 - a major problem (red LED on CMC)
# : 5 -  configuration of sensor units changed or
# :	 unit detected (red/yellow/green LED on CMC)"
my %mibCondition = qw(
	1 other
	2 ok
	3 degraded
	4 failed
	5 configChanged
);

# unitSensorType
my @unitSensorType = (
	"",			# 0
	"notavail",
	"failure",
	"overflow",
	"access",
	"vibration",
	"motion",
	"smoke",
	"airflow",
	"type6",
	"temperature",		# 10
	"current4to20",
	"humidity",
	"userno",
	"usernc",
	"lock",
	"unlock",
	"voltok",
	"voltage",
	"fanok",
	"readerkeypad",		# 20
	"dutypwm",
	"fanstatus",
	"leakage",
	"warningrtt",
	"alarmrtt",
	"filterrtt",
	"heatflowrct",
	"alarmrct",
	"warningrct",
	"currentpsm",		# 30
	"statuspsm",
	"positionpsm",
	"airflap",
	"acoustic",
	"detacfault",
	"detacfirstalarm",
	"detacmainalarm",
	"SPACING",
	"SPACING",
	"rpm11lcp",		# 40
	"rpm12lcp",
	"rpm21lcp",
	"rpm22lcp",
	"rpm31lcp",
	"rpm32lcp",
	"rpm41lcp",
	"rpm42lcp",
	"airtemp11lcp",
	"airtemp12lcp",
	"airtemp21lcp",		# 50
	"airtemp22lcp",
	"airtemp31lcp",
	"airtemp32lcp",
	"airtemp41lcp",
	"airtemp42lcp",
	"temp1lcp",
	"temp2lcp",
	"waterintemp",
	"waterouttemp",
	"waterflow",		# 60
	"fanspeed",
	"valve",
	"statuslcp",
	"waterdelta",
	"valveactual",
	"contrtemp2",
	"condensateduration",
	"contensatecycles",
	"SPACING",
	"SPACING",		# 70
	"SPACING",
	"totalkwhpsm",
	"totalkwpsm",
	"frequencypsm",
	"voltagepsm",
	"voltstatuspsm",
	"amperepsm",
	"ampstatuspsm",
	"kwpsm",
	"kwhpsm",		# 80
	"kwhtemppsm",
	"SPACING",
	"SPACING",
	"SPACING",
	"SPACING",
	"SPACING",
	"SPACING",
	"SPACING",
	"SPACING",
	"SPACING",		# 90
	"SPACING",
	"SPACING",
	"SPACING",
	"SPACING",
	"SPACING",
	"SPACING",
	"SPACING",
	"SPACING",
	"SPACING",
	"temperaturewl",	# 100
	"temperature1wl",
	"humiditywl",
	"accesswl",
	"usernowl",
	"userncwl",
	"analogwl"
);

##############################################################################
############################## Functions #####################################
##############################################################################
# Function: verb
# For verbose output
sub verb { my $t=shift; print "--- ".$t,"\n" if $p->opts->verbose; }

#
#	Function:	doperfdata
#	Set performance depending on the type of probes we are checking
#
sub doperfdata {
	my $unitid = shift;
	if(!defined($unitid)){ $unitid=1; } # Not sure if this makes sense..  but why would we always want unit 1?
	my $sensorid = shift;
	if(!defined($sensorid)){ $sensorid=1; }
	# sensorValue_oid=5.2.sensor(1).5
	if (lc($p->opts->type) eq 'temperature' or lc($p->opts->type) eq 'temperaturewl' or lc($p->opts->type) eq 'temperature1wl'){
		my $value = getValue($base_oid.(2+$unitid).".5.2.".$sensorid.".5.1");
		$p->add_perfdata( label => "temp", value => $value, uom => " Celsius", threshold => 0, min => 0, max => 100 );
	}
	if (lc($p->opts->type) eq 'humidity' or lc($p->opts->type) eq 'humiditywl' or lc($p->opts->type) eq 'humidity1wl'){
		my $value = getValue($base_oid.(2+$unitid).".5.2.".$sensorid.".5.1");
		$p->add_perfdata( label => "humidity", value => $value, uom => "%", threshold => 0, min => 0, max => 100 );
	}
	if (lc($p->opts->type) eq 'leakage'){
		my $value = getValue($base_oid.(2+$unitid).".5.2.".$sensorid.".5.1");
		$p->add_perfdata( label => "leakage", value => $value, uom => " m³", threshold => 0, min => 0 );
	}
	if (lc($p->opts->type) eq 'voltage'){
		my $value = getValue($base_oid.(2+$unitid).".5.2.".$sensorid.".5", 1);
		$p->add_perfdata( label => "voltage", value => $value, uom => " Volts", threshold => 0 );
	}
}

#
#	Function:	isnotnum
#	Return true if arg is not a number
#
sub isnotnum
{
  my $num = shift;
  if (!$num){return 0;}
  if ( $num =~ /^-?(\d+\.?\d*)|(^\.\d+)$/ ) { return 0 ;}
  return 1;
}

#
#	Function:	getValue
#	Get a value by using OID.
#	Generic function to wrap calls to Net::SNMP
#
sub getValue
{
	my @caller=caller;
	verb("getValue called from $caller[1]:$caller[2]");
	my $result = $session->get_request($_[0]);
	if (!defined( $result ) ){
		$p->nagios_exit(CRITICAL, "Request error: ".$session->error."(".$_[0]."), $!");
	}
	return $result->{$_[0]};
}

#
#	Function:	getMibStatus
#	Get value of cmcTcMibCondition
#
sub getMibStatus
{
	return getValue($mib_oid);
}

#
#	Function: translateMibStatus
#	Translate mib statuscode (int) t string
#
# : 1 - other
# : 2 - OK
# : 3 - a minor problem, warning condition (yellow LED on CMC)
# : 4 - a major problem (red LED on CMC)
# : 5 - configuration of sensor units changed or
# : 	unit detected (red/yellow/green LED on CMC)"
#
sub translateMibStatus
{
	return $mibCondition{$_[0]};
}

#
# Function: getMibStatuscode
# Takes the statuscode from CMC and returns the
# appropriate statuscode to be issued
# : 2 - OK
# : 3 - WARNING
# : 4 - CRITICAL
# : 5 - WARNING
# : >5 - WARNING
#
sub getMibStatuscode
{
	my $val = $_[0];
	SWITCH: {
		if ( $val<=2 ) { return "OK";}
		if ( $val==3 ) { return "WARNING";}
		if ( $val==4 ) { return "CRITICAL";}
		if ( $val==5 ) { return "WARNING";}
		if ( $val>5 )  { return "WARNING";}
	}
}

#
# Function: getUnitStatusCode
# Will return exitcode depending on state from unit
# : 1 - OK (ok)
# : 2 - CRITICAL (error)
# : 3 - WARNING  (changed)
# : 4 - WARNING  (quit)
# : 5 - WARNING  (timeout)
# : 6 - WARNING  (detected)
# : 7 - CRITICAL (notAvail)
# : 8 - CRITICAL (lowPower)
#
sub getUnitStatusCode
{
	my $val = $_[0];
	SWITCH: {
		if ( $val==1 ) {return "OK";}
		if ( $val==2 ) {return "CRITICAL";}
		if ( $val==3 ) {return "WARNING";}
		if ( $val==4 ) {return "WARNING";}
		if ( $val==5 ) {return "WARNING";}
		if ( $val==6 ) {return "WARNING";}
		if ( $val==7 ) {return "CRITICAL";}
		if ( $val==8 ) {return "CRITICAL";}
	}
}

#
#	Function:	translateSensorType
#	Translate sensorType (int) to string
#
sub translateSensorType
{
	my $value = getValue($_[0]);
	return lc($unitSensorType[$value]);
}

#
#	Function: 	getSensorTypeFromString
#	Get sensorType (int) from string
#	Like translateSensorType but the other way around...
#
sub getSensorTypeFromString
{
	my $index = 0;
	for ($index = 0; $index < $#unitSensorType; $index++){
		if ($unitSensorType[$index] eq $_[0]){
			return $index;
		}
	}
	return 0;
}

#
#	Function:	translateUnitStatus
#	Convert unit status (int) to string
#
sub translateUnitStatus
{
	return $unitStatus{$_[0]};
}

#
#	Function: 	countUnits
#	Returns nr of connected units
#	Uses getValue
#
sub countUnits
 {
	return getValue($_[0]);
 }

#
#	Function: 	countSensors
#	Returns nr of connected sensors to a unit
#	Uses getValue
#
sub countSensors
{
	return getValue($_[0]);
}

#
# Function: 	getSensortype
# Returns the type of connected probe/sensor
# Uses getValue()
#
# : "Type of sensor which is connected to sensor unit <n> to sensor"
# : 1 - notAvail
# : 2 - failure
# : 3 - overflow
# : 4 - access
# : 5 - vibration
# : 6 - motion
# : 7 - smoke
# : 8 - airFlow
# : 9 - type6
# : 10 - temperature
# : 11 - current4to20
# : 12 - humidity
# : 13 - userNO
# : 14 - userNC
# : 15 - lock
# : 16 - unlock
# : 17 - voltOK
# : 18 - voltage
# : 19 - fanOK
# : 20 - readerKeypad
# : 21 - dutyPWM
# : 22 - fanStatus
# : 23 - leakage
# : 24 - warningRTT
# : 25 - alarmRTT
# : 26 - filterRTT
# : 27 - heatflowRCT
# : 28 - alarmRCT
# : 29 - warningRCT
# : 30 - currentPSM
# : 31 - statusPSM
# : 32 - positionPSM
sub getSensortype
{
	return getValue($_[0]);
}

#
# Function: 	getSensortypeTxt
# Returns the type of connected probe/sensor.
# This text is editable in the CMC.
# Uses getValue()
#
sub getSensortypeTxt
{
	return getValue($_[0]);
}

#
#	Function:	translateStatus
#	Convert unitSensorStatus (int) to readable string
#
sub translateStatus
{
	my $value = getValue($_[0]);
	return $unitSensorStatus{$value};
}

#
# Function: sTrim
# Remove leading and trailing whitespace.
# Used when displaying type of sensor set by user in unit
#
sub sTrim
{
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}

#
# Function: getProbeStatusCode
# Takes the statuscode from a probe and returns the
# appropriate statuscode to be issued
#
# : 1 - WARNING
# : 2 - WARNING
# : 3 - WARNING
# : 4 - OK
# : 5 - WARNING
# : 6 - WARNING
# : 7 - WARNING
# : 8 - CRITICAL
# : 9 - CRITICAL
#
sub getProbeStatusCode
{
	my $val = $_[0];
	SWITCH: {
		if ( $val==1 ) { return "WARNING";}
		if ( $val==2 ) { return "WARNING";}
		if ( $val==3 ) { return "WARNING";}
		if ( $val==4 ) { return "OK";}
		if ( $val==5 ) { return "WARNING";}
		if ( $val==6 ) { return "WARNING";}
		if ( $val==7 ) { return "WARNING";}
		if ( $val==8 ) { return "CRITICAL";}
		if ( $val==9 ) { return "CRITICAL";}
	}
}

#
# Function: checkProbeStatus
# Check the status for a probe on a unit. Returns probeValue
# Input: oid for CMC + unit
# Input: oid part for sensorValue
# Input: probe id
sub checkProbeStatus
{
	#my $tmp_oid = $_[0];
	my ($tmp_oid, $sensorValue_oid, $o_probe) = @_;
	# get value for probe
	verb("Checking for probeValue on probe $o_probe");
	my $probeValue = getValue($tmp_oid.$sensorValue_oid.$o_probe);
	return $probeValue
}

# Function: getProbeSetValues
# Check for internally set values in CMC
# Returns comma separated list
sub getProbeSetValues
{
	# input values
	my ($tmp_oid, $sensorSetHigh_oid, $o_probe, $sensorStatusTxt_oid) = @_;

	my $probeSetHigh 	= undef;
	my $probeSetLow 	= undef;
	my $probeSetWarn 	= undef;

	$probeSetHigh 	= getValue($tmp_oid.$sensorSetHigh_oid.$o_probe);
	$probeSetLow 	= getValue($tmp_oid.$sensorSetLow_oid.$o_probe);
	$probeSetWarn 	= getValue($tmp_oid.$sensorSetWarn_oid.$o_probe);
	verb("Found: probeSetHigh=$probeSetHigh, probeSetLow=$probeSetLow, probeSetWarn=$probeSetWarn");

	$probeSetHigh	= $probeSetHigh!=0 ? $probeSetHigh : 0;
	$probeSetLow	= $probeSetLow!=0 ? $probeSetLow : 0;
	$probeSetWarn	= $probeSetWarn!=0 ? $probeSetWarn : 0;

	if ( !$probeSetHigh && !$probeSetLow && !$probeSetWarn ){
		# all probeSet values==0 which should indicate that they aren't used
		verb("All probeSet-values seems to be 0 which should indicate that they aren't used");
		return 0;
	} else {
		return $probeSetWarn.",".$probeSetLow.",".$probeSetHigh;
	}
}

# Function: checkProbesForUnit
# Loop through all probes for a unit
# translateStatus( $base_oid . $sensor_id . $sensorStatusTxt_oid . $a)
sub checkProbesForUnit
{
	my ($base_oid, $unit_id, $sensorTypeInt_oid, $sensorStatusTxt_oid, $probe_to_match, $probeType_to_match) = @_;
	$probeType_to_match		= lc($probeType_to_match);
	my $foundProbe 			= 0;
	my $foundProbeType		= 0;
	my @_sensorStatus 		= ();
	my $in_unit				= $unit_id;
	$unit_id 				= $unit_id + 2; # set unit_id to match internal id with OID
	my $nrOfSensors 		= countSensors($base_oid.$unit_id.".5.1.0"); # Nr of sensors connected to unit
	verb("Starting loop through unit $in_unit to check status of attached probes");
	verb("Unit $in_unit has $nrOfSensors attached probes");
	for (my $a=1;$a<=$nrOfSensors;$a++){ # Check status for each connected sensor for unit
		if ( defined($probe_to_match) && $probe_to_match ){
			if ( $a eq $probe_to_match ){
				verb("Found a probe matching -p ($probe_to_match)");
				$foundProbe ++;
				my $sensorType = translateSensorType($base_oid . $unit_id . $sensorTypeInt_oid . $a);
				if ( defined ($probeType_to_match) && $probeType_to_match && $sensorType eq $probeType_to_match ){
					verb("Found probe matching -T ($probeType_to_match)");
					my $probeStatus 		= checkProbeStatus($base_oid . $unit_id, $sensorValue_oid, $probe_to_match);
					my $probeStatusValue 	= getProbeStatusCode(getValue( $base_oid . $unit_id . $sensorStatusTxt_oid . $a));
					push(@_sensorStatus, $probeStatus.",".$probeStatusValue.",".$a);
					$foundProbeType ++;
				} else {
					# check status of probe
					my $probeStatus 		= checkProbeStatus($base_oid . $unit_id, $sensorValue_oid, $probe_to_match);
					my $probeStatusValue 	= getProbeStatusCode(getValue( $base_oid . $unit_id . $sensorStatusTxt_oid . $a));
					push(@_sensorStatus, $probeStatus.",".$probeStatusValue.",".$a);
				}
			}
		} elsif ( defined ($probeType_to_match) ){
			my $sensorType = translateSensorType($base_oid . $unit_id . $sensorTypeInt_oid . $a);
			if ( $probeType_to_match && $sensorType eq $probeType_to_match ){
				verb("Found probe matching -T ($probeType_to_match)");
				# getValue($base_oid.$unitInt . $sensorStatusTxt_oid . $p->opts->probe);
				my $probeStatus 		= checkProbeStatus($base_oid . $unit_id, $sensorValue_oid, $a);
				my $probeStatusValue 	= getProbeStatusCode(getValue( $base_oid . $unit_id . $sensorStatusTxt_oid . $a));
				push(@_sensorStatus, $probeStatus.",".$probeStatusValue.",".$a) ;
				$foundProbeType ++;
			} else {
				my $probeStatus 		= checkProbeStatus($base_oid . $unit_id, $sensorValue_oid, $a);
				my $probeStatusValue 	= getProbeStatusCode(getValue( $base_oid . $unit_id . $sensorStatusTxt_oid . $a));
				push(@_sensorStatus, $probeStatus.",".$probeStatusValue.",".$a) ;
				$foundProbe ++;
			}
		} else {
			my $probeStatus 		= checkProbeStatus($base_oid . $unit_id, $sensorValue_oid, $a);
			my $probeStatusValue 	= getProbeStatusCode(getValue( $base_oid . $unit_id . $sensorStatusTxt_oid . $a));
			push(@_sensorStatus, $probeStatus.",".$probeStatusValue.",".$a) ;
			$foundProbe ++;
		}
	} # end for
	my %returnStatus 		= (
		'status' 	=> "@_sensorStatus",
		'probes'	=> $foundProbe,
		'types'		=> $foundProbeType
	);
	return %returnStatus;
}

# Function: validateProbeStatus
# Input: array containing values (value and status) from a list of probes.
# Decide return status depending on set or defined warn/crit level(s).
sub validateProbeStatus
{
	my ($_values) 		= @_;
	my $isCrit 			= 0;
	my $isWarn 			= 0;
	my @aValues 		= split(/ /,$_values);
	my $probeSetWarn 	= undef;
	my $probeSetLow 	= undef;
	my $probeSetHigh 	= undef;
	my $probeSetValues	= undef;
	my $retval 		= undef;
	# Loop through collected sensorStatus messages and decide what to return
	for (my $a=0 ; $a < @aValues ; $a++){
		my @values 	= split(/,/,$aValues[$a]);
		my $val 	= $values[0];				# value from probe
		my $status	= sTrim( uc($values[1]) ); 	# status from probe, OK, WARNING, CRITICAL
		my $probe 	= $values[2];				# id of probe
		if ( defined($p->opts->warning) || defined($p->opts->critical) ){
			my $warn_level = undef;
			if ( defined($p->opts->warning) ) {
				$warn_level = $p->opts->warning;
				verb("Setting warn level");
				$p->set_thresholds(warning=>$warn_level);
			}

			my $crit_level = undef;
			if ( defined($p->opts->critical) ) {
				$crit_level = $p->opts->critical;
				verb("Setting critical level(s)");
				$p->set_thresholds(critical=>$crit_level);
			}

			$retval = 0;
			if ( !defined($warn_level) && !defined($crit_level) ){
				if ($status =~ m/CRITICAL/)	{ $retval = 2;}
				if ($status =~ m/WARNING/)	{ $retval = 1;}
			} else {
				$retval = $p->check_threshold(check=>$val, warning=>$p->opts->warning, critical=>$p->opts->critical);
			}
			if ( $retval eq 2 ){
				$isCrit++;
			} elsif ( $retval eq 1 ){
				$isWarn++;
			}
		} elsif ( defined($p->opts->unit) ){
			verb("No warn/crit values set");
			my $crit_warn = checkProbeLimits($val, $base_oid, $p->opts->unit, $probe, $sensorSetHigh_oid, $sensorStatusTxt_oid);
			my @setValues = split(/,/,$crit_warn);
			$isWarn += $setValues[0];
			$isCrit += $setValues[1];
		} else {
			verb("No warn/crit values set");
			verb("Unable to check against probeSetValues since no unit defined");
			if ($status =~ m/CRITICAL/)	{ $isCrit++;}
			if ($status =~ m/WARNING/)	{ $isWarn++;}
		}
	} # end for
	verb("Found $isCrit with CRITICAL status and $isWarn with WARNINIG");
	if( $p->all_perfoutput() eq "" ){ # If we already have performance data from elsewhere it is probably more detailed than this
		$p->add_perfdata(label => "'ok probes'", value => @aValues-$isCrit-$isWarn, uom => "probes", threshold => $p->threshold());
	}
	if ( $isCrit!=0 ){
		$p->nagios_exit(CRITICAL, "$isCrit probe(s) returned CRITICAL state");
	} elsif ( $isWarn!=0 ){
		$p->nagios_exit(WARNING, "$isWarn probe(s) returned WARNING state");
	}
	verb("No crit/warn issued");
	$p->nagios_exit(OK, " All is OK");

}

# Function: checkProbeLimits
# Check value against warn/crit or limits defined in CMC
# Returns warn.",".crit".
# Does NOT return statuscode - only nr of warn/crit
sub checkProbeLimits
{
	my ($value, $base_oid, $in_sensor_id, $probe, $sensorSetHigh_oid, $sensorStatusTxt_oid) = @_;
	my $isCrit 			= 0;
	my $isWarn 			= 0;
	my $probeSetWarn 	= undef;
	my $probeSetLow 	= undef;
	my $probeSetHigh 	= undef;
	my $sensor_id		= $in_sensor_id + 2;

	if ( !defined($p->opts->warning) || !defined($p->opts->critical) ){
		verb("Since either warn or crit (or both) are not set, we check for values in CMC");

		my $probeSetValues	= undef;

		verb("Checking for internally defined probeSetValues in CMC for probe $probe on unit $in_sensor_id");
		$probeSetValues 	= getProbeSetValues($base_oid.$sensor_id, $sensorSetHigh_oid, $probe, $sensorStatusTxt_oid),;

		# probeSetvalues separated with , or 0
		if ( $probeSetValues =~ m/,/ ) { # seems to be set with 1 or more values

			verb("Found 1 or more warn/crit levels defined in CMC");

			my @setValues 		= undef;
			@setValues 			= split(/,/, $probeSetValues);

			if (@setValues==3){
				my $probeSetWarn 	= $setValues[0];
				my $probeSetLow 	= $setValues[1];
				my $probeSetHigh 	= $setValues[2];

				verb("Found warn=$probeSetWarn, low=$probeSetLow, high=$probeSetHigh");
			}
		} else {
			verb("Found no warn/crit values in CMC and -w and/or -c is missing");
		}

	}

	my $warn_level = undef;
	if ( defined($p->opts->warning) ) {
		$warn_level = $p->opts->warning;
	} elsif ( defined($probeSetWarn) ){
		verb("Setting warn level to internally defined probeSetWarn=$probeSetWarn");
		my $warn_level = $probeSetWarn;
	}

	if ( defined($warn_level) ){
		verb("Setting warn level");
		$p->set_thresholds(warning=>$warn_level);
	}

	my $crit_level = undef;
	if ( defined($p->opts->critical) ) {
		$crit_level = $p->opts->critical;
	} elsif ( defined($probeSetLow) && defined($probeSetHigh) ){ # both crit levels defined
		verb("Setting crit levels to internally defined probeSetLow=$probeSetLow, probeSetHigh=$probeSetHigh");
		$crit_level = $probeSetLow.":".$probeSetHigh;
	} elsif ( defined($probeSetLow) ){ # only probeSetLow defined
		verb("Setting crit to probeSetLow defined in CMC");
		$crit_level = $probeSetLow;
	} elsif ( defined($probeSetHigh) ){
		verb("Setting crit to probeSetHigh defined in CMC");
		$crit_level = $probeSetHigh;
	}

	# check if crit levels
	if ( defined($crit_level) ){
		verb("Setting critical level(s)");
		$p->set_thresholds(critical=>$crit_level);
	} else {
		# No probeSetValues for crit and no -c => use status for probe
		# if we got this far we have nothing to act against - check status flag (0/1) for probe
		my $probeStatusValue 	= getValue($base_oid.$sensor_id . $sensorStatusTxt_oid . $probe);
		my $probeReturnStatus 	= getProbeStatusCode($probeStatusValue);
		verb("Probe returns $probeStatusValue which is considered $probeReturnStatus in CMC");
		if ( $probeReturnStatus !~ m/OK/ ){
			if ($probeReturnStatus =~ m/CRITICAL/)	{ $isCrit++;}
			if ($probeReturnStatus =~ m/WARNING/)	{ $isWarn++;}
			verb("Probe status not OK!");
		}
	}

	if ( !defined($p->opts->warning) || !defined($p->opts->critical) ){
		my $retval = $p->check_threshold(check=>$value, warning=>$p->opts->warning, critical=>$p->opts->critical);
		if ( $retval eq 2 ){
			$isCrit++;
		} elsif ( $retval eq 1 ){
			$isWarn++;
		}
	}
	return $isWarn.",".$isCrit;
}
##############################################################################
#################################### Main ####################################
##############################################################################
# Parse arguments and process standard ones (e.g. usage, help, version)
$p->getopts;

### Validate input

# Check certain type of probe?
if ( defined( $p->opts->type )){
	# Convert to lowercase
	$o_type = lc($p->opts->type);

	# can we find int for type in MIB?
	$o_typeInt = getSensorTypeFromString($o_type);
	if ( $o_typeInt==0 ){
		$p->nagios_die("Unable to find probe of type '$o_type'");
	}
}

if ( defined( $p->opts->probe ) ){
	if ( isnotnum($p->opts->probe) ){
		verb("Probe -p ".$p->opts->probe." is not numeric ");
		$p->nagios_die("Probe has to be numeric and > 0");
	}
}

if ( defined( $p->opts->unit ) ){
	if ( isnotnum($p->opts->unit) ){
		verb("Unit -u ".$p->opts->unit." is not numeric ");
		$p->nagios_die("Unit has to be numeric and > 0");
	}
}

# requires a hostname and a community string as its arguments
($session,$error) = Net::SNMP->session(Hostname 	=> $p->opts->hostname,
                                       Community 	=> $p->opts->community,
                                       Timeout 		=> $p->opts->timeout);

if (!$session){
	verb("Unable to connect to CMC or unable to find anything.");
	$p->nagios_die("Session error: $error");
}

$nrOfUnits = countUnits($oid_nrOfUnits);

if ($p->opts->status){ ## Print status information?

	# Check status of CMC
	verb("Checking status of CMC.");

	$mib_status = getMibStatus();
	print "=========================\nCMC status: ".translateMibStatus($mib_status)."\n=========================\n";

	verb("Checking status of CMC.");
	verb("Found $nrOfUnits attached units");

	verb("Starting loop through available units");
	for (my $i=1;$i<=$nrOfUnits;$i++){ ## loop through connected units
		my $sensor_id 	= $i + 2;

		# Print id of current Unit
		print "-------------------------\n  Unit ".$i.":\n";

		# check config
		my $unitStatus = getValue($base_oid.$sensor_id.".4.0");
		print "  Unit status: ". translateUnitStatus($unitStatus)."\n";
		print "-------------------------\n";
		printf ("%33s %6s %11s \n", "Type", "Value", "Status");

		my $nrOfSensors = countSensors($base_oid.$sensor_id.".5.1.0"); # Nr of sensors connected to unit nr $i
		for (my $a=1;$a<=$nrOfSensors;$a++){ # Check status for each connected sensor for each unit
			my $oid 	= $base_oid . $sensor_id . $sensorValue_oid . $a;
			# 3.5.2.1.2.1
			# translateSensorType
			my $sensorType = translateSensorType($base_oid . $sensor_id . $sensorTypeInt_oid . $a);
			# Print status for each sensor on each unit
			if ($p->opts->verbose){
				my $sensorTypeInt = getValue($base_oid . $sensor_id . $sensorTypeInt_oid . $a);
				printf ("%33s %3d %10s \n", sTrim( getSensortypeTxt($base_oid . $sensor_id . $sensorTypeTxt_oid . $a) )." (" . $sensorType .", ".$sensorTypeInt.")", getValue($oid), translateStatus( $base_oid . $sensor_id . $sensorStatusTxt_oid . $a) );
			}else{
				printf ("%33s %3d %10s \n", sTrim( getSensortypeTxt($base_oid . $sensor_id . $sensorTypeTxt_oid . $a) )." (" . $sensorType .")", getValue($oid), translateStatus( $base_oid . $sensor_id . $sensorStatusTxt_oid . $a) );
			}
		}
	}
}else { ## Only report errors

	$p->set_thresholds(warning=>$p->opts->warning, critical=>$p->opts->critical);

	# check if unit is out of range
	if ( $p->opts->unit){
		verb("Check if unit ".$p->opts->unit." exists");
		if ( $p->opts->unit > $nrOfUnits ){
			$p->nagios_die("Unit ".$p->opts->unit." doesn't seem to exist");
		}
	}

	# what to check?
	# Unit Type probe?
	if ( defined($p->opts->unit) && $p->opts->unit && defined( $p->opts->probe ) && $p->opts->probe && defined( $o_typeInt ) && $o_typeInt!=0){
		verb("Starting check of unit ".$p->opts->unit.", probe ".$p->opts->probe." (stated type: ".$p->opts->type.")");
		# all values are set - check if o_probe is of type o_typeInt
		my $unitInt = $p->opts->unit + 2;

		# Does probe exist?
		verb("Checking if probe exists");
		my $nrOfSensors = countSensors($base_oid.$unitInt.".5.1.0"); # Nr of sensors connected to unit nr $i
		if ( $p->opts->probe > $nrOfSensors ){
			$p->nagios_die("Probe ".$p->opts->probe." does not seem to exist on unit ".$p->opts->unit." ");
		}

		my $tmp_sensorTypeOID = $base_oid.$unitInt.$sensorTypeInt_oid.$p->opts->probe;
		my $requested_probe = getValue($tmp_sensorTypeOID);
		verb("Check if stated probe matches probe id");
		if ($requested_probe!=$o_typeInt){
			$p->nagios_die("The requested type of probe (".$p->opts->type.") does not match -p option (".$p->opts->probe.") which is of type '".translateSensorType($tmp_sensorTypeOID)."' on unit ".$p->opts->unit);
		}

		#### Check status of probe?

		# OID for probe on requested unit
		my $unitProbeOID = $base_oid.$unitInt.$sensorValue_oid.$p->opts->probe;
		verb("Checking status of probe");
		$result 		= checkProbeStatus($base_oid.$unitInt, $sensorValue_oid, $p->opts->probe);
		my $crit_warn 	= checkProbeLimits($result, $base_oid, $p->opts->unit, $p->opts->probe, $sensorSetHigh_oid, $sensorStatusTxt_oid);
		my @setValues 	= split(/,/,$crit_warn);
		my $isWarn 		= $setValues[0];
		my $isCrit 		= $setValues[1];
		if ( $isCrit!=0 ){
			$p->nagios_exit(CRITICAL, "Probe returned CRITICAL state");
		} elsif ( $isWarn!=0 ){
			$p->nagios_exit(WARNING, "Probe returned WARNING state");
		}

	} elsif ( defined($p->opts->unit) && defined($p->opts->probe) ){ # if unit type probe
		# check probe on unit
		verb("Checking probe ".$p->opts->probe." on unit ".$p->opts->unit);
		my $unitInt = $p->opts->unit + 2;

		# Does probe exist?
		my $nrOfSensors = countSensors($base_oid.$unitInt.".5.1.0"); # Nr of sensors connected to unit nr $i
		verb("Checking if probe ".$p->opts->probe." exists on unit ".$p->opts->unit);
		if ( $p->opts->probe > $nrOfSensors ){
			verb("Unknown probe on unit ".$p->opts->unit);
			$p->nagios_die("Probe ".$p->opts->probe." does not seem to exist on unit ".$p->opts->unit);
		}

		# Check status of probe on unit
		verb("Checking status of probe ".$p->opts->probe);
		my $probeStatus 	= getValue($base_oid.$unitInt.$sensorValue_oid.$p->opts->probe);
		$result 			= checkProbeStatus($base_oid.$unitInt, $sensorValue_oid, $p->opts->probe);
		verb("Probe status: ".$result);
			my $crit_warn = checkProbeLimits($probeStatus, $base_oid, $p->opts->unit, $p->opts->probe, $sensorSetHigh_oid, $sensorStatusTxt_oid);
		my @setValues = split(/,/,$crit_warn);
		my $isWarn = $setValues[0];
		my $isCrit = $setValues[1];
		if ( $isCrit!=0 ){
			$p->nagios_exit(CRITICAL, "Probe returned CRITICAL state");
		} elsif ( $isWarn!=0 ){
			$p->nagios_exit(WARNING, "Probe returned WARNING state");
		}
	} elsif ( defined( $o_typeInt ) && defined( $p->opts->unit ) && $p->opts->unit!=0 ){

		# check all probes of type $o_typeInt on $o_unit
		verb("Checking all probes of type '".$p->opts->type."' on unit ".$p->opts->unit);
		my $foundProbeType		= 0;
		my @sensorStatus 		= ();
		my $sensor_id = $p->opts->unit + 2;

		my %probeStatus 	= checkProbesForUnit($base_oid, $p->opts->unit, $sensorTypeInt_oid, $sensorStatusTxt_oid, undef, $p->opts->type);
		push(@sensorStatus, $probeStatus{'status'});
		$foundProbeType 	+= $probeStatus{'types'};
		if ( $foundProbeType==0 ){
			verb("Failed to find any probe matching -T (".$p->opts->type.")");
			$p->nagios_die("Unable to find any probes matching -T (".$p->opts->type.") on any attached unit");
		} else {
			# found one or more probes of type o_type
			verb("Retrieved status message(s) from $foundProbeType probes");
			verb("Trying to find if any of the found status messages where CRITICAL or WARNING");
			validateProbeStatus(@sensorStatus);
		}
	} elsif ( defined( $o_typeInt ) && $o_typeInt!=0 && defined( $p->opts->probe ) ){ # Specified probe ID and type
		#verb ("probe and type?");
		verb("Checking if probe exists on any unit");

		# Loop through all available units
		verb("Found $nrOfUnits attached units");

		my $foundProbe 		= 0;
		my $foundProbeType	= 0;
		my @sensorStatus 	= ();
		verb("Starting loop through available units");
		for (my $i=1;$i<=$nrOfUnits;$i++){ ## loop through connected units
			# check all probes attached to unit
			my %probeStatus = checkProbesForUnit($base_oid, $i, $sensorTypeInt_oid, $sensorStatusTxt_oid, $p->opts->probe, $p->opts->type);
			push(@sensorStatus, $probeStatus{'status'});
			$foundProbe 	+= $probeStatus{'probes'};
			if($probeStatus{'probes'})
			{ # Looping through, adding multiple perfdata might be bad
				doperfdata($i, $p->opts->probe);
			}
			$foundProbeType += $probeStatus{'types'};
		}

		if ($foundProbe==0){
			verb("Failed to find any probes matching -p (".$p->opts->probe.")");
			$p->nagios_die("Unable to find any probes matching -p (".$p->opts->probe.") on any attached unit");
		} elsif ( $foundProbeType==0 ){
			verb("Failed to find any probe matching -T ((".$p->opts->type."))");
			$p->nagios_die("Unable to find any probes matching -T (".$p->opts->type.") on any attached unit");
		} else {
			# found one or more probes of type o_type
			verb("Retrieved status message(s) from $foundProbe probes");
			verb("Trying to find if any of the found status messages where CRITICAL or WARNING");
			validateProbeStatus(@sensorStatus);
		}
	} elsif ( defined( $o_typeInt ) ){ # Probes of specified type on all units
		verb("Trying to find status of all attached probes of type '".$p->opts->type."' on all units ($nrOfUnits) ");

		my $foundProbeType		= 0;
		my @sensorStatus 		= ();

		verb("Starting loop through available units");
		for (my $i=1;$i<=$nrOfUnits;$i++){ ## loop through connected units
			my %probeStatus 	= checkProbesForUnit($base_oid, $i, $sensorTypeInt_oid, $sensorStatusTxt_oid, undef, $p->opts->type);
			push(@sensorStatus, $probeStatus{'status'});
			$foundProbeType 	+= $probeStatus{'types'};
		}

		doperfdata();

		if ( $foundProbeType==0 ){
			verb("Failed to find any probe matching -T (".$p->opts->type.")");
			$p->nagios_die("Unable to find any probes matching -T (".$p->opts->type.") on any attached unit");
		} else {
			# found one or more probes of type o_type
			verb("Retrieved status message(s) from $foundProbeType probes");
			verb("Trying to find if any of the found status messages were CRITICAL or WARNING");
			validateProbeStatus(@sensorStatus);
		}
	} elsif ( defined($p->opts->probe) ){ # Specified probe ID on each unit
		verb("Only probe is set");
		# $result = checkProbeStatus($base_oid.$unitInt, $sensorValue_oid, $p->opts->probe);
		verb("Trying to find status of all attached probes with id '".$p->opts->probe."' on all units ($nrOfUnits) ");

		my $foundProbes			= 0;
		my @sensorStatus 		= ();

		verb("Starting loop through available units");
		for (my $i=1;$i<=$nrOfUnits;$i++){ ## loop through connected units
			my %probeStatus 	= checkProbesForUnit($base_oid, $i, $sensorTypeInt_oid, $sensorStatusTxt_oid, $p->opts->probe, undef);
			push(@sensorStatus, $probeStatus{'status'});
			$foundProbes 		+= $probeStatus{'probes'};
		}
		if ( $foundProbes==0 ){
			verb("Failed to find any probe matching -p (".$p->opts->probe.")");
			$p->nagios_die("Unable to find any probes matching -p (".$p->opts->probe.") on any attached unit");
		} else {
			# found one or more probes
			verb("Retrieved status message(s) from $foundProbes probes");
			verb("Trying to find if any of the found status messages where CRITICAL or WARNING");
			validateProbeStatus(@sensorStatus);
		}
	} elsif ( defined($p->opts->unit) ){ # checking a specific unit by ID
		# Check status of unit
		verb("Checking status of unit ".$p->opts->unit);
		my $unitInt 	= $p->opts->unit + 2;
		my $unitStatus 	= getValue($base_oid.$unitInt.".4.0");
			# is the statuscode returned from the unit considered to be ok/warn/crit?
		my $unitReturnStatus = getUnitStatusCode( $unitStatus );
		verb("Unit ".$p->opts->unit." returned status $unitReturnStatus ($unitStatus)");
		if ( $unitReturnStatus !~ m/OK/){
			$p->nagios_exit($unitReturnStatus, " Unit ".$p->opts->unit." returned status $unitStatus (".translateUnitStatus($unitStatus).")");
		}

		# Check ALL probes attatched to unit
		my $foundProbes			= 0;
		my @sensorStatus 		= ();
		my %probeStatus 	= checkProbesForUnit($base_oid, $p->opts->unit, $sensorTypeInt_oid, $sensorStatusTxt_oid, undef, undef);
		push(@sensorStatus, $probeStatus{'status'});
		$foundProbes 		+= $probeStatus{'probes'};
		if ( $foundProbes==0 ){
			verb("Failed to find any probe un unit (".$p->opts->unit.")");
			$p->nagios_die("Unable to find any probes on unit (".$p->opts->unit.")");
		} else {
			# found one or more probes
			verb("Retrieved status message(s) from $foundProbes probes");
			verb("Trying to find if any of the found status messages where CRITICAL or WARNING");
			validateProbeStatus(@sensorStatus);
		}
	} else {
		# Since we got this far, nothing is set to check so let's check the
		# overall status of the CMC
		verb("Checking status of CMC");
		$mib_status 	= getMibStatus();
		$mibReturnCode 	= getMibStatuscode($mib_status);
		verb("CMC returned status $mibReturnCode ($mib_status)");

		if ($mibReturnCode !~ m/OK/){
			verb("CMC does not seem to be OK");
			$p->nagios_exit(CRITICAL, " CMC returned status $mib_status ($mibReturnCode)");
		} else {
			$p->nagios_exit(OK, " CMC returned status $mib_status ($mibReturnCode)");
		}
	} # end if unit/CMC by ID
} # end if not printing status info

$session->close;

# TASK Enable perfdata

# Return status
if ( defined($result) ){
	if( $p->all_perfoutput() eq "" ){ # If we already have performance data from elsewhere it is probably more detailed than this
		$p->set_thresholds(warning => $p->opts->warning, critical => $p->opts->critical);
		$p->add_perfdata(label => "value", value => $result, uom => "", threshold => $p->threshold());
	}
	$p->nagios_exit(
		 return_code => $p->check_threshold(check=>$result, warning=>$p->opts->warning, critical=>$p->opts->critical),
		 message => " Return value is $result"
	);
}
