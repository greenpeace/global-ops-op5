#!/usr/bin/perl -w
#    ---------------------------------------------------------------------------
#    Cisco IPSLA plugin for Nagios Copyright 2010 Lionel Cottin (cottin@free.fr)
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
my $release = "2010/02/25";
#
# This plugin checks for the status of IP SLA probes configured on Cisco routers.
#
# IP SLAs can be configured as follows on routers (tested on IOS 12.4T):
# 
#   ! Ping probe example
#   ! (target must be another Cisco box configured as IP SLA responder)
#   ip sla 1
#    icmp-jitter 10.10.10.10
#    tag PING
#    frequency 300
#    
#   ! Jitter probe example
#   ! (target must be another Cisco box configured as IP SLA responder)
#   ip sla 2
#    udp-jitter 10.10.10.10 5000
#    tag JITTER
#    frequency 300
#   
#   ! VoIP G729a probe example
#   ! (target must be another Cisco box configured as IP SLA responder)
#   ip sla 3
#    udp-jitter 10.10.10.10 5000 codec g729a
#    tag VOIP
#    frequency 300
#   
#   ! DNS probe example
#   ip sla 4
#    dns www.google.com name-server 8.8.8.8
#    tag DNS
#    frequency 300
#   
#   ! HTTP probe example
#   ip sla 5
#    http get http://www.google.com/ name-server 8.8.8.8 cache disable
#    tag HTTP
#    frequency 300
# 
#   Note:
#   You may also want to configure some thresholds to make the probe fail
#   when it takes too long for instance. This is quite important because this
#   Nagios plugin will not accept warning and critical boundaries. These should
#   be configured on the IP SLA itself.
#   This plugin only checks the return status of such IP SLAs and it succeeds
#   only when IP SLAs succeed on the remote router. In other words, this plugin
#   checks if the configured IP SLA is met or not.
#
# Next, this plugin has 2 modes:
#
# 1. Single SLA mode
# ------------------
#  In this mode you specify which IP SLA you want to check (identified by Tag). The plugin
#  will then connect to the router using SNMP (v2c for now), make sure that there's an IP SLA configured
#  that corresponds to the supplied Tag, retrieve some probe specific information and report its
#  status back to Nagios (including probe specific performance data).
# 
#  Pros & Cons:
#  	+ granular monitoring of IP SLAs
#  	+ probe specific status information & perf data
#  	- less scalable; possibly many IP SLA services per router
#  
#  Example 1:
#   $ ./check_cisco_ipsla.pl -H 10.10.10.10 -c public -i DNS
#   IP SLA 4 # DNS ( dns probe to www.google.com ) status: OK | RTT=41;Query=www.google.com
#  
#  Example 2:
#   $ ./check_cisco_ipsla.pl -H 10.10.10.10 -c public -i HTTP
#   IP SLA 5 # HTTP ( http probe to http://www.google.com/ ) status: OK | DNS=2;TCP=3;HTTP=4;Total=9;Query=http://www.google.com/
# 
# 
# 2. Multi SLA mode
# -----------------
#  In this mode you specify the keyword "ALL" as IP SLA tag (i.e. "-i ALL" on command line). The plugin
#  will then connect to the router using SNMP (v2c for now), list all configured IP SLAs, retrieve their status,
#  and report all that information back to Nagios. If only one IP SLA fails, the whole Nagios service will fail.
#  Also, the plugin will report the completion time of all IP SLAs configured in the performace data section.
#  In this mode the plugin generates a multi-line output.
#  
#  Pros & Cons:
#   	- no granular monitoring of IP SLAs
#   	- no probe specific status information & perf data
#   	+ scalable; only one IP SLA service per router
#  
#  Example 3:
#   $ ./check_cisco_ipsla.pl -H 10.10.10.10 -c public -i ALL
#   IP SLA status: OK | Total-Time=469
#   IP SLA 1 # PING_London ( icmp-jitter ) status: OK
#   IP SLA 2 # JITTER_Tokyo ( udp-jitter ) status: OK
#   IP SLA 3 # VOIP_NewYork ( udp-jitter g729a ) status: OK
#   IP SLA 4 # DNS_Paris ( dns ) status: OK
#   IP SLA 5 # HTTP_Google ( http ) status: OK | PING_London=18
#   JITTER_Tokyo=250
#   VOIP_NewYork=106
#   DNS_Paris=32
#   HTTP_Google=81
#
# Version 0.1:
#  New features:
#  - First public release
#  - Single SLA mode + Multi SLA mode
#  - Support for HTTP probe
#  - Support for DNS probe
#  - Support for VOIP/g729a probe
#  - Support for ICMP probe
#  - Support for Jitter probe
#  Todo list:
#  - P1:Add support for all remaining probe types
#  - P2:Better error reporting
#  - P2:Clean Perl programming
#  - P3:Evaluate perf data from plugin (warning+critical thresholds)
#  - P4:Dynamically set & run probes without prior router config
#  Known bugs:
#  - BUG0001: supplying a wrong SNMP community string makes the plugin always succeed!
#  - BUG0002: in multi SLA mode, an empty line is displayed after the 1st one
#  Resolved issues:
#

use Getopt::Std;
use Net::SNMP qw(:snmp);

#-------------------------------------------------------------------------------
#    Global variable declarations
#-------------------------------------------------------------------------------
my (
   $usage,              # Help message
   $hostname,           # Target router
   $community,          # SNMP community (v2c only)
   $base_oid,           # Base OID
   %rttSense,           # Hash of IP SLA states
   %httpSense,		# Hash of HTTP states
   %rttType,		# Hash of IP SLA types
   %rttCodec,		# Hash of IP SLA codecs (udp-jitter)
   %rtt_status,         # Hash of IP SLA statuses 
   $ipsla,		# IP SLA tag given in command line
   $state,		# Nagios status: 2=critical, 1=warning, 0=ok, -1=error
   $long,		# Message for $LONGSERVICEOUTPUT$
   $perf,		# Message for $SERVICEPERFDATA$
   $short,		# Message for $SERVICEOUTPUT$
   $fail,		# List of failed IP SLA probes, if any
   $total,		# Total execution time for IP SLA Probes
   $result,		# Temp variable to store SNMP results
   $message		# Final message to print out
);

#-------------------------------------------------------------------------------
#    Global variable initializations
#-------------------------------------------------------------------------------
$usage = <<"EOF";
usage:  $0 [-h] -H <hostname> -c <community> -i <ip sla tag> [-W <warning>] [-C <critical>]

Version: $version
Released on: $release

Nagios check for Cisco IP SLAs.
Checks for probe status and returns execution time
as perf data (multi-line output)

[-h]              :       Print this message
[-H] <router>     :       IP Address or Hostname of the router
[-c] <community>  :       SNMP Community String  (default = "public")
[-i] <IP SLA Tag> :       IP SLA tag as defined in the router config
			  (ALL = check all IP SLAs configured on the router)
[-d]		  :	  enable debug output
[-W] <warning>    :	  Warning value
[-C] <critical>   :	  Critical value
 
EOF

%rttSense = (
		"0"	=>	"Other",
		"1"	=>	"OK",
		"2"	=>	"Disconnected",
		"3"	=>	"Over Threshold",
		"4"	=>	"Time Out",
		"5"	=>	"Busy",
		"6"	=>	"Not Connected",
		"7"	=>	"Dropped",
		"8"	=>	"Sequence Error",
		"9"	=>	"Verify Error",
		"10"	=>	"Application Specific",
		"11"	=>	"DNS Server Time Out",
		"12"	=>	"TCP Connect Time Out",
		"13"	=>	"HTTP Transaction Time Out",
		"14"	=>	"DNS Query Error",
		"15"	=>	"HTTP Error",
		"16"	=>	"Error",
);
%rttType = (
		"1"	=>	"echo",
		"2"	=>	"pathEcho",
		"3"	=>	"fileIO",
		"4"	=>	"script",
		"5"	=>	"udpEcho",
		"6"	=>	"tcpConnect",
		"7"	=>	"http",
		"8"	=>	"dns",
		"9"	=>	"udp-jitter",
		"10"	=>	"dlsw",
		"11"	=>	"dhcp",
		"12"	=>	"ftp",
		"16"	=>	"icmp-jitter",
);
%rttCodec = (
		"0"	=>	"",
		"1"	=>	"g711ulaw ",
		"2"	=>	"g711alaw ",
		"3"	=>	"g729a ",
);

%httpSense	= (
		"0"	=>	"other",
		"1"	=>	"OK",
		"2"	=>	"disconnected",
		"3"	=>	"overThreshold",
		"4"	=>	"timeout",
		"5"	=>	"busy",
		"6"	=>	"notConnected",
		"7"	=>	"dropped",
		"8"	=>	"sequenceError",
		"9"	=>	"verifyError",
		"10"	=>	"applicationSpecific",
		"11"	=>	"dnsServerTimeout",
		"12"	=>	"tcpConnectTimeout",
		"13"	=>	"httpTransactionTimeout",
		"14"	=>	"dnsQueryError",
		"15"	=>	"httpError",
		"16"	=>	"error",
);
$state 					= 0;
$total					= 0;
$base_oid               		= 0;

# Base OIDs for bulk requests
my $rttMonLatestRttOperSense		  = "1.3.6.1.4.1.9.9.42.1.2.10.1.2";
my $rttMonCtrlAdminTag			  = "1.3.6.1.4.1.9.9.42.1.2.1.1.3";
my $rttMonLatestRttOperCompletionTime	  = "1.3.6.1.4.1.9.9.42.1.2.10.1.1";
my $rttMonCtrlAdminRttType		  = "1.3.6.1.4.1.9.9.42.1.2.1.1.4";
my $rttMonEchoAdminCodecType		  = "1.3.6.1.4.1.9.9.42.1.2.2.1.27";

# DNS probe OIDs
# Note: DNS RTT is available from rttMonLatestRttOperCompletionTime
my $rttMonEchoAdminTargetAddressString	  = "1.3.6.1.4.1.9.9.42.1.2.2.1.11.";	# DNS query
my $rttMonEchoAdminNameServer		  = "1.3.6.1.4.1.9.9.42.1.2.2.1.12.";	# DNS nameserver


# HTTP probe OIDs
my $rttMonEchoAdminURL	    		  = "1.3.6.1.4.1.9.9.42.1.2.2.1.15.";	# HTTP Target URL
my $rttMonLatestHTTPOperSense		  = "1.3.6.1.4.1.9.9.42.1.5.1.1.6.";	# HTTP sense code
my $rttMonLatestHTTPErrorSenseDescription = "1.3.6.1.4.1.9.9.42.1.5.1.1.7.";	# HTTP return code
my $rttMonLatestHTTPOperRTT               = "1.3.6.1.4.1.9.9.42.1.5.1.1.1.";	# HTTP_RTT
my $rttMonLatestHTTPOperDNSRTT            = "1.3.6.1.4.1.9.9.42.1.5.1.1.2.";	# HTTP_DNS_RTT
my $rttMonLatestHTTPOperTCPConnectRTT     = "1.3.6.1.4.1.9.9.42.1.5.1.1.3.";	# HTTP_TCP_RTT
my $rttMonLatestHTTPOperTransactionRTT    = "1.3.6.1.4.1.9.9.42.1.5.1.1.4.";	# HTTP_Trans_RTT

# VoIP codec OIDs
my $rttMonLatestJitterOperSense		  = "1.3.6.1.4.1.9.9.42.1.5.2.1.31.";   # Jitter RTT result
my $rttMonLatestJitterOperMOS		  = "1.3.6.1.4.1.9.9.42.1.5.2.1.42.";   # MOS value
my $rttMonLatestJitterOperICPIF		  = "1.3.6.1.4.1.9.9.42.1.5.2.1.43.";   # ICPIF value
my $rttMonEchoAdminTargetAddress	  = "1.3.6.1.4.1.9.9.42.1.2.2.1.2.";	# Target address

# Jitter OIDs
my $rttMonLatestJitterOperOWSumSD	  = "1.3.6.1.4.1.9.9.42.1.5.2.1.33.";	# Latency sum Src to Dst
my $rttMonLatestJitterOperOWMinSD	  = "1.3.6.1.4.1.9.9.42.1.5.2.1.35.";	# Min latency Src to Dst
my $rttMonLatestJitterOperOWMaxSD	  = "1.3.6.1.4.1.9.9.42.1.5.2.1.36.";	# Max latency Dst to Dst
my $rttMonLatestJitterOperOWSumDS	  = "1.3.6.1.4.1.9.9.42.1.5.2.1.37.";	# Latency sum Dst to Src
my $rttMonLatestJitterOperOWMinDS	  = "1.3.6.1.4.1.9.9.42.1.5.2.1.39.";	# Min latency Dst to Src
my $rttMonLatestJitterOperOWMaxDS	  = "1.3.6.1.4.1.9.9.42.1.5.2.1.40.";	# Max latency Dst to Src
my $rttMonLatestJitterOperNumOfOW	  = "1.3.6.1.4.1.9.9.42.1.5.2.1.41.";	# Successful One Way probes

#===============================================================================
#                              Input Phase
#===============================================================================
die $usage if (!getopts('hH:c:i:dW:C:') || $opt_h);
die $usage if (!$opt_H || !$opt_i || $opt_h);
$hostname = $opt_H;
$community = $opt_c || "public"; undef $opt_c; #use twice to remove Perl warning
$ipsla = $opt_i;
if($opt_d) {
  print "Target hostname: $hostname\n";
  print "SNMPv2 community: $community\n";
  print "IP SLA tag: $opt_i\n";
}

#-------------------------------------------------------------------------------
# Open an SNMPv2 session with the router
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
# Send a bulk request for the rttMonCtrlAdminTag table
#-------------------------------------------------------------------------------
$base_oid = $rttMonCtrlAdminTag;
$result = $session->get_bulk_request(
	-callback       => [\&table_cb, {}],
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
# Send a bulk request for the rttMonLatestRttOperSense table
#-------------------------------------------------------------------------------
$base_oid = $rttMonLatestRttOperSense;
$result = $session->get_bulk_request(
	-callback       => [\&table_cb, {}],
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
# Send a bulk request for the rttMonLatestRttOperCompletionTime table
#-------------------------------------------------------------------------------
$base_oid = $rttMonLatestRttOperCompletionTime;
$result = $session->get_bulk_request(
        -callback       => [\&table_cb, {}],
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
# Send a bulk request for the rttMonCtrlAdminRttType table
#-------------------------------------------------------------------------------
$base_oid = $rttMonCtrlAdminRttType;
$result = $session->get_bulk_request(
        -callback       => [\&table_cb, {}],
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
# Send a bulk request for the rttMonEchoAdminCodecType table
#-------------------------------------------------------------------------------
$base_oid = $rttMonEchoAdminCodecType;
$result = $session->get_bulk_request(
        -callback       => [\&table_cb, {}],
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

#===============================================================================
#                              Output Phase
#===============================================================================
if ($opt_i eq "ALL") {
  # Close SNMP session now as we don't need it anymore
  $session->close;
  #---------------------------------------------------------------
  # Check for all IP SLAs configured on the router
  # Get basic status info + execution time and report to Nagios
  #---------------------------------------------------------------
  my $ipslaCountTotal = 0;
  my $ipslaCountFail = 0;
  $long = '';
  $perf = '';
  $fail = '';
  for $index ( sort keys %rtt_status ) {
    $ipslaCountTotal++;
    if ( $rtt_status{$index}{status} != 1) {
      $state++;
      $ipslaCountFail++;
      $fail=$fail.$index."#".$rtt_status{$index}{adminTag}." ";	
    };
    $status         = $rtt_status{$index}{status};
    $adminTag       = $rtt_status{$index}{adminTag};
    $rttType        = $rtt_status{$index}{rttType};
    $codecType      = $rtt_status{$index}{codecType};
    $statusText     = $rtt_status{$index}{statusText};
    $completionTime = $rtt_status{$index}{completionTime};
    if($opt_d) {
      printf "Got this: IP SLA %s, status=%s, adminTag=%s, rttType=%s, codecType=%s, statusText=%s, completionTime=%s\n",
      $index,$status,$adminTag,$rttType,$codecType,$statusText,$completionTime;
    }
    $long = $long . "\nIP SLA $index # $adminTag ( $rttType $codecType) status: $statusText";
    $perf = $perf . "$adminTag=$completionTime\n";
    $total = $total + $rtt_status{$index}{completionTime};
  }
  $short = "IP SLA status ( $ipslaCountTotal IP SLA probes succeeded ): OK";
  my $result = 0;
  if ( $state > 0 ) {
    $short = "OK";
    if (defined($opt_W) && ($state > $opt_W)) {
      $short = "WARNING";
      $result = 1;
    }
    if (defined($opt_C) && ($state > $opt_C)) {
      $short = "CRITICAL";
      $result = 2;
    }
    $short = "IP SLA status ( $ipslaCountFail IP SLA probes have failed out of $ipslaCountTotal ): $short";
  }
  $message = "$short | Total-Time=$total\n$long | $perf";
  print $message;
  exit $result;
} else {
  #---------------------------------------------------------------
  # Check for one specific IP SLA configured on the router
  # Get some probe specific information and report to Nagios
  #---------------------------------------------------------------
  for $index ( sort keys %rtt_status ) {
    $status         = $rtt_status{$index}{status};
    $adminTag       = $rtt_status{$index}{adminTag};
    $rttType        = $rtt_status{$index}{rttType};
    $codecType      = $rtt_status{$index}{codecType};
    $statusText     = $rtt_status{$index}{statusText};
    $completionTime = $rtt_status{$index}{completionTime};
    $match          = 1;
    if($opt_d) {
      printf "Got this: IP SLA %s, status=%s, adminTag=%s, rttType=%s, codecType=%s, statusText=%s, completionTime=%s\n",
      $index,$status,$adminTag,$rttType,$codecType,$statusText,$completionTime;
    }
    if ( $adminTag eq $opt_i ) {
      $match = 0;
      if($opt_d) {
        print "Good, IP SLA Tag $adminTag is confiured on router\n";
      }
      if      ( $rttType eq "echo" ) {
	not_supported();
      } elsif ( $rttType eq "pathEcho" ) {
	not_supported();
      } elsif ( $rttType eq "fileIO" ) {
	not_supported();
      } elsif ( $rttType eq "script" ) {
	not_supported();
      } elsif ( $rttType eq "udpEcho" ) {
	not_supported();
      } elsif ( $rttType eq "tcpConnect" ) {
	not_supported();
      } elsif ( $rttType eq "http" ) {
	@oids = (
	  $rttMonEchoAdminURL.$index,
	  $rttMonLatestHTTPOperSense.$index,
          $rttMonLatestHTTPErrorSenseDescription.$index,
          $rttMonLatestHTTPOperRTT.$index,
          $rttMonLatestHTTPOperDNSRTT.$index,
          $rttMonLatestHTTPOperTCPConnectRTT.$index,
          $rttMonLatestHTTPOperTransactionRTT.$index
	);
	$result = $session->get_request(
                  -callback       => [\&get_http, {}],
                  -varbindlist    => \@oids
		);
	if (!defined($result)) {
	  printf("ERROR: %s.\n", $session->error);
	  $session->close;
	  exit (-1);
	}
	snmp_dispatcher();
	undef $result;
      } elsif ( $rttType eq "dns" ) {
	@oids = (
	  $rttMonEchoAdminTargetAddressString.$index,
	  $rttMonLatestRttOperCompletionTime.".".$index,
	  $rttMonLatestRttOperSense.".".$index,
	  $rttMonEchoAdminNameServer.$index
	);
        $result = $session->get_request(
                  -callback       => [\&get_dns, {}],
                  -varbindlist    => \@oids
                );
        if (!defined($result)) {
          printf("ERROR: %s.\n", $session->error);
          $session->close;
          exit (-1);
        }
        snmp_dispatcher();
        undef $result;
      } elsif ( $rttType eq "udp-jitter" ) {
	if ( $codecType eq "" ) {
	  @oids = (
	    $rttMonEchoAdminTargetAddress.$index,
	    $rttMonLatestJitterOperSense.$index,
	    $rttMonLatestJitterOperOWSumSD.$index,
	    $rttMonLatestJitterOperOWMinSD.$index,
	    $rttMonLatestJitterOperOWMaxSD.$index,
	    $rttMonLatestJitterOperOWSumDS.$index,
	    $rttMonLatestJitterOperOWMinDS.$index,
	    $rttMonLatestJitterOperOWMaxDS.$index,
	    $rttMonLatestJitterOperNumOfOW.$index
	  );
          $result = $session->get_request(
                    -callback       => [\&get_jitter, {}],
                    -varbindlist    => \@oids
                  );
          if (!defined($result)) {
            printf("ERROR: %s.\n", $session->error);
            $session->close;
            exit (-1);
          }
          snmp_dispatcher();
          undef $result;
	} elsif ( $codecType eq "g711ulaw " ) {
	  not_supported(); # same as g729a ??
	} elsif ( $codecType eq "g711alaw " ) {
	  not_supported(); # same as g729a ??
	} elsif ( $codecType eq "g729a " ) {
	  @oids = (
	    $rttMonLatestJitterOperSense.$index,
	    $rttMonLatestJitterOperMOS.$index,
	    $rttMonLatestJitterOperICPIF.$index,
	    $rttMonEchoAdminTargetAddress.$index
	  );
	  $result = $session->get_request(
                    -callback       => [\&get_voip, {}],
                    -varbindlist    => \@oids
                  );
          if (!defined($result)) {
            printf("ERROR: %s.\n", $session->error);
            $session->close;
            exit (-1);
          }
          snmp_dispatcher();
          undef $result;
	} else {
	  not_supported();
	}
      } elsif ( $rttType eq "dlsw" ) {
	not_supported();
      } elsif ( $rttType eq "dhcp" ) {
	not_supported();
      } elsif ( $rttType eq "ftp" ) {
	not_supported();
      } elsif ( $rttType eq "icmp-jitter" ) {
	@oids = (
	  $rttMonLatestRttOperSense.".".$index,
	  $rttMonEchoAdminTargetAddress.$index,
	  $rttMonLatestRttOperCompletionTime.".".$index
	);
	$result = $session->get_request(
	          -callback       => [\&get_icmp, {}],
	          -varbindlist    => \@oids
		);
	if (!defined($result)) {
          printf("ERROR: %s.\n", $session->error);
          $session->close;
          exit (-1);
        }
        snmp_dispatcher();
        undef $result;
      }
      $session->close;
      print $message;
      exit $state;
    }
  }
  print "IPSLA: No matching IP SLA found on router: UNKNOWN\n";
  exit 3;
}

#-------------------------------------------------------------------------------
# Subroutine to handle the SNMP responses.
#-------------------------------------------------------------------------------

# Jitter Probe
sub get_jitter
{
  my ($session, $table) = @_;
  my %snmpGet;
  if (!defined($session->var_bind_list)) {
    printf("ERROR: %s\n", $session->error);
  } else {
    foreach my $oid (keys(%{$session->var_bind_list})) {
      $snmpGet{$oid} = $session->var_bind_list->{$oid};
    }
  }
  if($opt_d) {
    print "OIDs Found:\n";
    foreach $k (sort keys %snmpGet) {
      print "$k => $snmpGet{$k}\n";
    }
  }
  my $res      = $snmpGet{$rttMonLatestJitterOperSense.$index};
  my $restxt   = $rttSense{$res};
  my $OWSumSD	= $snmpGet{$rttMonLatestJitterOperOWSumSD.$index};
  my $OWMinSD	= $snmpGet{$rttMonLatestJitterOperOWMinSD.$index};
  my $OWMaxSD   = $snmpGet{$rttMonLatestJitterOperOWMaxSD.$index};
  my $OWSumDS   = $snmpGet{$rttMonLatestJitterOperOWSumDS.$index};
  my $OWMinDS   = $snmpGet{$rttMonLatestJitterOperOWMinDS.$index};
  my $OWMaxDS   = $snmpGet{$rttMonLatestJitterOperOWMaxDS.$index};
  my $NumOfOW	= $snmpGet{$rttMonLatestJitterOperNumOfOW.$index};
  my $target   = $snmpGet{$rttMonEchoAdminTargetAddress.$index};
  $avgSD = sprintf("%.2f", $OWSumSD/$NumOfOW);
  $posSD = sprintf("%.2f", $OWMaxSD-$avgSD);
  $negSD = sprintf("%.2f", $OWMinSD-$avgSD);
  $avgDS = sprintf("%.2f", $OWSumDS/$NumOfOW);
  $posDS = sprintf("%.2f", $OWMaxDS-$avgDS);
  $negDS = sprintf("%.2f", $OWMinDS-$avgDS);
  $target =~ s/^0x//;
  $target = join '.', unpack "C*", pack "H*", $target;
  if ( $res == 1) {
    $state = 0;
  } else {
    $state = 2;
  }
  $short = "IP SLA $index # $adminTag ( Jitter probe to $target ) status: $restxt (avgSD=$avgSD avgDS=$avgDS +SD=$posSD -SD=$negSD +DS=$posDS -DS=$negDS)";
  $perf = "avgSD=$avgSD;avgDS=$avgDS;posSD=$posSD;negSD=$negSD;posDS=$posDS;negDS=$negDS";
  $message = $short." | ".$perf."\n";
}

# VOIP Probe
sub get_voip
{
  my ($session, $table) = @_;
  my %snmpGet;
  if (!defined($session->var_bind_list)) {
    printf("ERROR: %s\n", $session->error);
  } else {
    foreach my $oid (keys(%{$session->var_bind_list})) {
      $snmpGet{$oid} = $session->var_bind_list->{$oid};
    }
  }
  if($opt_d) {
    print "OIDs Found:\n";
    foreach $k (sort keys %snmpGet) {
      print "$k => $snmpGet{$k}\n";
    }
  }
  my $res      = $snmpGet{$rttMonLatestJitterOperSense.$index};
  my $restxt   = $rttSense{$res};
  my $mos      = $snmpGet{$rttMonLatestJitterOperMOS.$index};
  my $icpif    = $snmpGet{$rttMonLatestJitterOperICPIF.$index};
  my $target   = $snmpGet{$rttMonEchoAdminTargetAddress.$index};
  $mos = $mos/100;
  $target =~ s/^0x//;
  $target = join '.', unpack "C*", pack "H*", $target;
  if ( $res == 1) {
    $state = 0;
  } else {
    $state = 2;
  }
  $short = "IP SLA $index # $adminTag ( $codecType probe to $target ) status: $restxt (MOS=$mos ICPIF=$icpif)";
  $perf = "MOS=$mos;ICPIF=$icpif;Target=$target";
  $message = $short." | ".$perf."\n";
}

# ICMP Probe
sub get_icmp
{
  my ($session, $table) = @_;
  my %snmpGet;
  if (!defined($session->var_bind_list)) {
    printf("ERROR: %s\n", $session->error);
  } else {
    foreach my $oid (keys(%{$session->var_bind_list})) {
      $snmpGet{$oid} = $session->var_bind_list->{$oid};
    }
  }
  if($opt_d) {
    print "OIDs Found:\n";
    foreach $k (sort keys %snmpGet) {
      print "$k => $snmpGet{$k}\n";
    }
  }
  my $res      = $snmpGet{$rttMonLatestRttOperSense.".".$index};
  my $restxt   = $rttSense{$res};
  my $target   = $snmpGet{$rttMonEchoAdminTargetAddress.$index};
  my $totalrtt = $snmpGet{$rttMonLatestRttOperCompletionTime.".".$index};
  $target =~ s/^0x//;
  $target = join '.', unpack "C*", pack "H*", $target;
  if ( $res == 1) {
    $state = 0;
  } else {
    $state = 2;
  }
  $short = "IP SLA $index # $adminTag ( ICMP probe to $target ) status: $restxt (RTT=$totalrtt ms)";
  $perf = "RTT=$totalrtt";
  $message = $short." | ".$perf."\n";
}

# DNS Probe
sub get_dns
{
  my ($session, $table) = @_;
  my %snmpGet;
  if (!defined($session->var_bind_list)) {
    printf("ERROR: %s\n", $session->error);
  } else {
    foreach my $oid (keys(%{$session->var_bind_list})) {
      $snmpGet{$oid} = $session->var_bind_list->{$oid};
    }
  }
  if($opt_d) {
    print "OIDs Found:\n";
    foreach $k (sort keys %snmpGet) {
      print "$k => $snmpGet{$k}\n";
    }
  }
  my $res      = $snmpGet{$rttMonLatestRttOperSense.".".$index}; 
  my $restxt   = $rttSense{$res}; 
  my $dnsname  = $snmpGet{$rttMonEchoAdminTargetAddressString.$index};
  my $totalrtt = $snmpGet{$rttMonLatestRttOperCompletionTime.".".$index};
  my $dnsserver= $snmpGet{$rttMonEchoAdminNameServer.$index};
  $dnsserver =~ s/^0x//;
  $dnsserver = join '.', unpack "C*", pack "H*", $dnsserver;
  if ( $res == 1) {
    $state = 0;
  } else {
    $state = 2;
  }
  $short = "IP SLA $index # $adminTag ( Resolving $dnsname with DNS server  $dnsserver ) status: $restxt (RTT=$totalrtt ms)";
  $perf = "RTT=$totalrtt";
  $message = $short." | ".$perf."\n";
}

# HTTP probe
sub get_http
{
  my ($session, $table) = @_;
  my %snmpGet;
  if (!defined($session->var_bind_list)) {
    printf("ERROR: %s\n", $session->error);
  } else {
    foreach my $oid (keys(%{$session->var_bind_list})) {
      $snmpGet{$oid} = $session->var_bind_list->{$oid};
    }
  }
  if($opt_d) {
    print "OIDs Found:\n";
    foreach $k (sort keys %snmpGet) {
      print "$k => $snmpGet{$k}\n";
    }
  }
  my $url      = $snmpGet{$rttMonEchoAdminURL.$index};
  my $res      = $snmpGet{$rttMonLatestHTTPOperSense.$index};
  my $restxt   = $httpSense{$res};
  my $dnsrtt   = $snmpGet{$rttMonLatestHTTPOperDNSRTT.$index};
  my $tcprtt   = $snmpGet{$rttMonLatestHTTPOperTCPConnectRTT.$index};
  my $httprtt  = $snmpGet{$rttMonLatestHTTPOperTransactionRTT.$index};
  my $totalrtt = $snmpGet{$rttMonLatestHTTPOperRTT.$index};
  if ( $res == 1) {
    $state = 0;
  } else {
    $state = 2;
  }
  $short = "IP SLA $index # $adminTag ( $rttType probe of $url ) status: $restxt";
  $perf = "DNS=$dnsrtt;TCP=$tcprtt;HTTP=$httprtt;Total=$totalrtt";
  $message = $short." | ".$perf."\n";
}

sub table_cb 
{
  my ($session, $table) = @_;
  if (!defined($session->var_bind_list)) {
    printf("ERROR: %s\n", $session->error);
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
              -callback       => [\&table_cb, $table],
              -maxrepetitions => 10,
              -varbindlist    => [$next]
              );
    if (!defined($result)) {
      printf("ERROR: %s\n", $session->error);
    }
  } else {

    #-------------------------------------------------------
    # We are no longer in the table, so print the results.
    #-------------------------------------------------------
    my @ipsla;
    foreach my $oid (oid_lex_sort(keys(%{$table}))) {

      #-----------------------------------------------
      # Handle result from rttMonCtrlAdminTag walk
      #-----------------------------------------------
        if ($oid =~ /^$rttMonCtrlAdminTag.(\d+)$/) {
          my $rttIndex = $1;
          my $myrttMonCtrlAdminTag = $table->{$oid};
          if($opt_d) {
            print "GOT rttIndex $1 for $table->{$oid}\n";
          }
          $rtt_status{$rttIndex}{"adminTag"} = "$table->{$oid}";
          $rtt_status{$rttIndex}{"status"} = -1;

          #-----------------------------------------------
          # Handle result from rttMonLatestRttOperSense walk
          #-----------------------------------------------
        } elsif ($oid =~ /^$rttMonLatestRttOperSense.(\d+)$/) {
          if($opt_d) {
            print "setting rttMonLatestRttOperSense for $1 to $table->{$oid} ($rttSense{$table->{$oid}})\n";
          }
          my $rttIndex = $1;
          $rtt_status{$rttIndex}{"status"} = $table->{$oid};
          $rtt_status{$rttIndex}{"statusText"} = $rttSense{$table->{$oid}};

          #-----------------------------------------------
          # Handle result from rttMonCtrlAdminRttType walk
          #-----------------------------------------------
        } elsif ($oid =~ /^$rttMonCtrlAdminRttType.(\d+)$/) {
          if($opt_d) {
            print "setting rttMonCtrlAdminRttType for $1 to $table->{$oid} ($rttType{$table->{$oid}})\n";
          }
          my $rttIndex = $1;
          $rtt_status{$rttIndex}{"rttType"} = $rttType{$table->{$oid}};

          #-----------------------------------------------
          # Handle result from rttMonEchoAdminCodecType walk
          #-----------------------------------------------
        } elsif ($oid =~ /^$rttMonEchoAdminCodecType.(\d+)$/) {
          if($opt_d) {
            print "setting rttMonEchoAdminCodecType for $1 to $table->{$oid} ($rttCodec{$table->{$oid}})\n";
          }
          my $rttIndex = $1;
          $rtt_status{$rttIndex}{"codecType"} = $rttCodec{$table->{$oid}};

          #-----------------------------------------------
          # Handle result from rttMonLatestRttOperCompletionTime walk
          #-----------------------------------------------
        } elsif ($oid =~ /^$rttMonLatestRttOperCompletionTime.(\d+)$/) {
          if($opt_d) {
            print "setting rttMonLatestRttOperCompletionTime for $1 to $table->{$oid} ($table->{$oid} ms)\n";
          }
          my $rttIndex = $1;
          $rtt_status{$rttIndex}{"completionTime"} = "$table->{$oid}";
        }
      }
    }
  }
}

sub not_supported
{
  print "IPSLA: This probe ( $rttType $codecType ) is not supported yet: UNKNOWN\n";
  exit 3;
}
