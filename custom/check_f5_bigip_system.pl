#!/usr/bin/perl -w
#    ---------------------------------------------------------------------------
#    F5 probe for System healthcheck Copyright 2010 Lionel Cottin (cottin@free.fr)
#    ---------------------------------------------------------------------------
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#    ---------------------------------------------------------------------------
#
my $version = "0.1";
my $release = "2010/06/18";

#
# Interesting MIB entries
# -----------------------
my $sysGlobalHostCpuUsageRatio5m = ".1.3.6.1.4.1.3375.2.1.1.2.20.37"; # table of % used cpu
#my $sysGeneralHwNumber = ".1.3.6.1.4.1.3375.2.1.3.3.2"; # ex: 1600
my $sysName = "1.3.6.1.2.1.1.5";
my $sysGeneralChassisSerialNum = ".1.3.6.1.4.1.3375.2.1.3.3.3";
my $sysChassisTempTemperature = ".1.3.6.1.4.1.3375.2.1.3.2.3.2.1.2"; # table of temp in C
my $sysChassisPowerSupplyStatus = ".1.3.6.1.4.1.3375.2.1.3.2.2.2.1.2"; # table of PSU bad(0) good(1) notpresent(2)
my $sysChassisFanStatus = ".1.3.6.1.4.1.3375.2.1.3.2.1.2.1.2"; # Table of Fan status bad(0) good(1) notpresent(2)


use Getopt::Std;
use Net::SNMP qw(:snmp);

#-------------------------------------------------------------------------------
#    Global variable declarations
#-------------------------------------------------------------------------------
my %bigip_status = ( "0" => "Bad", "1" => "Good", "2" => "Not-Present" );
my @str = ("OK", "WARNING", "CRITICAL", "UNKNOWN"); # Nagios status strings
my (
   $usage,              # Help message
   $hostname,           # Target router
   $community,          # SNMP community (v2c only)
   $base_oid,           # Base OID
   $state,		# Nagios status: 3=unknown, 2=critical, 1=warning, 0=ok, -1=error
   $short,		# Message for $SERVICEOUTPUT$
   $result,		# Temp variable to store SNMP results
   $message,		# Final message to print out
   %bigip,		# BigIP hash for all status information
   @oids,
   $cpu,
   $sys,
   $hot
);


#-------------------------------------------------------------------------------
#    Global variable initializations
#-------------------------------------------------------------------------------
$usage = <<"EOF";
usage:  $0 [-h] -H <hostname> -C <community> -w <warning> -c <critical>

Version: $version
Released on: $release

Nagios check for F5 BigIP System health using SNMP version 2c

[-h]                  : Print this message
[-H] <hostname>       : IP Address or Hostname
[-C] <community>      : SNMP Community String  (default = "public")
[-w] <cpu>,<temp>     : Warning levels  for cpu and temperature in Celsius
[-c] <cpu>,<temp>     : Critical levels for cpu and temperature in Celsius
[-d]		      : enable debug output
 
EOF

$state = 0; # Assume OK nagios status by default
$bigip{"fan"} = 0; # Assume Good Fan status by default
$bigip{"psu"} = 0; # Assume Good Psu status by default
$bigip{"cpu"} = 0; # Assume Good Cpu status by default
$bigip{"tmp"} = 0; # Assume Good Temperature status by default

#-------------------------------------------------------------------------------
#                              Input Phase
#-------------------------------------------------------------------------------
die $usage if (!getopts('hH:C:w:c:d') || $opt_h);
die $usage if (!$opt_H || !$opt_C || !$opt_c || !$opt_w || $opt_h);
$hostname = $opt_H;
$community = $opt_C || "public"; undef $opt_C; #use twice to remove Perl warning
my @crit = split (/,/,$opt_c);
my @warn = split (/,/,$opt_w);

if($opt_d) {
  print "Target hostname  : $hostname\n";
  print "SNMPv2 community : $community\n";
  print "Warning levels   : $warn[0] \%cpu , $warn[1] degrees celsius\n";
  print "Critical levels  : $crit[0] \%cpu , $crit[1] degrees celsius\n";
}

#-------------------------------------------------------------------------------
# Open an SNMPv2 session with the remote agent
#-------------------------------------------------------------------------------
my ($session, $error) = Net::SNMP->session(
	-version     => 'snmpv2c',
	-nonblocking => 1,
	-timeout     => 2,
    	-hostname    => $hostname,
    	-community   => $community
);

if (!defined($session)) {
  printf("ERROR: %s.\n", $error);
  exit (-1);
}

#-------------------------------------------------------------------------------
# Get Platform name, CPU usage and Chassis temperature
#-------------------------------------------------------------------------------
#@oids = ( $sysGlobalHostCpuUsageRatio5m.".0", $sysGeneralHwNumber.".0", $sysChassisTempTemperature.".1" );
#Editing OID as sysGeneralHwNumber has been deprecated.
@oids = ( $sysGlobalHostCpuUsageRatio5m.".0", $sysGeneralChassisSerialNum.".0", $sysChassisTempTemperature.".1" );

$result = $session->get_request(
	  -varbindlist	=> \@oids,
	  -callback	=> [\&cb_get, {}],
	);
if (!defined($result)) {
  printf("ERROR: %s.\n", $session->error);
  $session->close;
  exit (-1);
}
snmp_dispatcher();
undef $result;

#-------------------------------------------------------------------------------
# Get Fan Status
#-------------------------------------------------------------------------------
$base_oid = $sysChassisFanStatus;
$result = $session->get_bulk_request(
        -callback       => [\&cb_bulk, {}],
        -maxrepetitions => 20,
        -varbindlist => [$base_oid]
);
if (!defined($result)) {
  printf("ERROR: %s.\n", $session->error);
  $session->close;
  exit (-1);
}
snmp_dispatcher();
undef $result;

#-------------------------------------------------------------------------------
# Get Power Supply
#-------------------------------------------------------------------------------
$base_oid = $sysChassisPowerSupplyStatus;
$result = $session->get_bulk_request(
        -callback       => [\&cb_bulk, {}],
        -maxrepetitions => 20,
        -varbindlist => [$base_oid]
);
if (!defined($result)) {
  printf("ERROR: %s.\n", $session->error);
  $session->close;
  exit (-1);
}
snmp_dispatcher();
undef $result;


#-------------------------------------------------------------------------------
# Process results
#-------------------------------------------------------------------------------

# Raise to warning level if any warning level is found
$state = 1 if ($bigip{"cpu"} > $warn[0] );
$state = 1 if ($bigip{"tmp"} > $warn[1] );

# Raise to critical level if any critical level is found
$state = 2 if ($bigip{"cpu"} > $crit[0] );
$state = 2 if ($bigip{"tmp"} > $crit[1] );
$state = 2 if ($bigip{"fan"} eq 0 );
$state = 2 if ($bigip{"psu"} eq 0 );

$message = "Big-IP $bigip{\"sys\"} status (Cpu=$bigip{\"cpu\"}\% Temperature=$bigip{\"tmp\"}degrees-C $short): $str[$state]";
$perf = "cpu=$bigip{\"cpu\"}% temperature=$bigip{\"tmp\"}";
print "$message | $perf\n";
exit $state;

#-------------------------------------------------------------------------------
# Subroutines
#-------------------------------------------------------------------------------
sub cb_bulk
{
  my ($session, $table) = @_;
  if (!defined($session->var_bind_list)) {
    printf("ERROR: %s\n", $session->error);
    exit -1;
  } else {
    #---------------------------------------------------------------
    # Loop through each of the OIDs in the response and assign
    # the key/value pairs to the anonymous hash that is passed
    # to the callback.  Make sure that we are still in the table
    # before assigning the key/values.
    #---------------------------------------------------------------
    my $next;
    foreach my $oid (oid_lex_sort(keys(%{$session->var_bind_list}))) {
      if (!oid_base_match($base_oid, $oid)) {
        $next = undef;
        last;   
      }      
      $next = $oid;
      $table->{$oid} = $session->var_bind_list->{$oid};
    } 
    #---------------------------------------------------------------
    # If $next is defined we need to send another request
    # to get more of the table.
    #---------------------------------------------------------------
    if (defined($next)) {
      $result = $session->get_bulk_request(
                -callback       => [\&get_bulk, $table],
                -maxrepetitions => 10,
                -varbindlist    => [$next]
                );
      if (!defined($result)) {
        printf("ERROR: %s\n", $session->error);
        exit -1;
      } 
    } else {
      #-------------------------------------------------------
      # We are no longer in the table, so print the results.
      #-------------------------------------------------------
      foreach my $oid (oid_lex_sort(keys(%{$table}))) {
        #-----------------------------------------------
        # Handle result from sysChassisFanStatus walk
        #-----------------------------------------------
        if ($oid =~ /^$sysChassisFanStatus.(\d+)$/) {
          my $index = $1;
          if($opt_d) {
            print "Fan $1: $bigip_status{$table->{$oid}}\n";
          }
	$bigip{"fan"} = $table->{$oid};
	$short = $short . " Fan$1:$bigip_status{$table->{$oid}}";
        #-----------------------------------------------
        # Handle result from sysChassisPowerSupplyStatus walk
        #-----------------------------------------------
        } elsif ($oid =~ /^$sysChassisPowerSupplyStatus.(\d+)$/) {
          my $index = $1;
          if($opt_d) {
            print "Psu $1: $bigip_status{$table->{$oid}}\n";
          }
	$bigip{"psu"} = $table->{$oid};
	$short = $short . " Psu$1:$bigip_status{$table->{$oid}}";
        }
      }
    }
  }
}

sub cb_get
{
  my ($session) = @_;
  my $result = $session->var_bind_list();
  if (!defined $result) {
     printf "ERROR: Get request failed for host '%s': %s.\n",
            $session->hostname(), $session->error();
     exit -1;
  }
  $bigip{"cpu"} = $result->{$oids[0]};
  $bigip{"sys"} = $result->{$oids[1]};
  $bigip{"tmp"} = $result->{$oids[2]};
}
