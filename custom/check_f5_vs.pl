#!/usr/bin/perl -w
#    ---------------------------------------------------------------------------
#    F5 probe for Virtual Server Copyright 2010 Lionel Cottin (cottin@free.fr)
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

# ltmVirtualServName OBJECT-TYPE
#        SYNTAX LongDisplayString
#        MAX-ACCESS read-only
#        STATUS current
#        DESCRIPTION
#                "The name of a virtual server."
#        ::= { ltmVirtualServEntry 1 }
my $ltmVirtualServName  = ".1.3.6.1.4.1.3375.2.2.10.1.2.1.1";

# ltmVirtualServEnabled OBJECT-TYPE 
#        SYNTAX INTEGER {
#                false(0),
#                true(1)
#        }       
#        MAX-ACCESS read-write
#        STATUS current
#        DESCRIPTION
#                "The state indicating whether the specified virtual server is enabled or not."
#        ::= { ltmVirtualServEntry 9 }
my $ltmVirtualServEnabled = ".1.3.6.1.4.1.3375.2.2.10.1.2.1.9";

# ltmVsStatusAvailState OBJECT-TYPE
#        SYNTAX INTEGER {
#                none(0),
#                green(1),
#                yellow(2),
#                red(3),
#                blue(4),
#                gray(5)
#        }
#        MAX-ACCESS read-only
#        STATUS current
#        DESCRIPTION 
#                "The availability of the specified virtual server indicated in color.
#                none - error;
#                green - available in some capacity;
#                yellow - not currently available;
#                red - not available;
#                blue - availability is unknown;
#                gray - unlicensed."
#        ::= { ltmVsStatusEntry 2 }
my $ltmVsStatusAvailState = ".1.3.6.1.4.1.3375.2.2.10.13.2.1.2";

# ltmVirtualServStatClientCurConns OBJECT-TYPE
#        SYNTAX Counter64
#        MAX-ACCESS read-only
#        STATUS current
#        DESCRIPTION
#                "The current connections from client-side to the specified virtual server."
#        ::= { ltmVirtualServStatEntry 12 }
my $ltmVirtualServStatClientCurConns = ".1.3.6.1.4.1.3375.2.2.10.2.3.1.12";

use Getopt::Std;
use Net::SNMP qw(:snmp);

#-------------------------------------------------------------------------------
#    Global variable declarations
#-------------------------------------------------------------------------------

my @str = ("OK", "WARNING", "CRITICAL", "UNKNOWN"); # Nagios status strings
my (
   $usage,              # Help message
   $hostname,           # Target router
   $community,          # SNMP community (v2c only)
   $base_oid,           # Base OID
   $state,              # Nagios status: 3=unknown, 2=critical, 1=warning, 0=ok, -1=error
   $short,              # Message for $SERVICEOUTPUT$
   $result,             # Temp variable to store SNMP results
   $vs_idx,             # Virtual Server Index
   $vs_name,            # Virtual Server name in ASCII form
   $vs_oid,             # Virtual Server name in DECIMAL form
   $vs_state,           # Virtual Server state
   $vs_enabled,         # Virtual Server enabled ?
   %vs                  # Virtual Servers hash
                        #  $vs->{index}->{"name"}       # String
                        #  $vs->{index}->{"oid"}        # String
                        #  $vs->{index}->{"enabled"}    # Boolean
                        #  $vs->{index}->{"state"}      # Integer
                        #  $vs->{index}->{"conns"}      # Integer
);


#-------------------------------------------------------------------------------
#    Global variable initializations
#-------------------------------------------------------------------------------
$usage = <<"EOF";
usage:  $0 [-h] -H <hostname> -C <community> [-V <Virtual Server Name>]

Version: $version
Released on: $release

Nagios check for F5 LTM Virtual servers using SNMP version 2c

[-h]                  : Print this message
[-H] <hostname>       : IP Address or Hostname
[-C] <community>      : SNMP Community String  (default = "public")
[-V] <virtual server> : Virtual Server name or "ANY" to check them all
[-d]                  : enable debug output
 
EOF

$state          = 3; # status UNKNOWN by default

#-------------------------------------------------------------------------------
#                              Input Phase
#-------------------------------------------------------------------------------
die $usage if (!getopts('hH:C:V:d') || $opt_h);
die $usage if (!$opt_H || !$opt_C || !$opt_V || $opt_h);
$hostname = $opt_H;
$community = $opt_C || "public"; undef $opt_C; #use twice to remove Perl warning
$vs_name = $opt_V;
if($opt_d) {
  print "Target hostname  : $hostname\n";
  print "SNMPv2 community : $community\n";
  print "Virtual Server   : $vs_name\n";
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
# Retrieve the list of virtual servers names
#-------------------------------------------------------------------------------
$base_oid = $ltmVirtualServName;
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
# Retrieve the list of virtual servers enable states
#-------------------------------------------------------------------------------
$base_oid = $ltmVirtualServEnabled;
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
# Retrieve the list of virtual servers availability status
#-------------------------------------------------------------------------------
$base_oid = $ltmVsStatusAvailState;
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
# Retrieve the list of virtual servers client connections
#-------------------------------------------------------------------------------
$base_oid = $ltmVirtualServStatClientCurConns;
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
#                              Output Phase
#-------------------------------------------------------------------------------
my $conns = 0;
my ($w,$c,$o) = ("","","");
for my $i ( keys %vs ) {
  # Don't validate server name if ANY is given in cmd line
  if ( $vs_name eq "ANY" ) {
    if ( $vs{$i}{"enabled"} == 1 ) {
      $conns = $conns + $vs{$i}{"conns"};
      if ($vs{$i}{"state"} =~ m/(1)/ ) {
        $o = $o . " " . $vs{$i}{"name"};
      }
      if ($vs{$i}{"state"} =~ m/(0|2|3)/ ) {
        $c = $c . " " . $vs{$i}{"name"};
      }
      if ($vs{$i}{"state"} =~ m/(4|5)/ ) {
        $w = $w . " " . $vs{$i}{"name"};
      }
    }
  # Validate server name before assessing the status
  } elsif ( $vs{$i}{"name"} eq $vs_name ) {
    if ( $vs{$i}{"enabled"} == 1 ) {
      $conns = $conns + $vs{$i}{"conns"};
      if ($vs{$i}{"state"} =~ m/(1)/ ) {
        $o = $o . " " . $vs{$i}{"name"};
      }
      if ($vs{$i}{"state"} =~ m/(0|2|3)/ ) {
        $c = $c . " " . $vs{$i}{"name"};
      }
      if ($vs{$i}{"state"} =~ m/(4|5)/ ) {
        $w = $w . " " . $vs{$i}{"name"};
      }
    }
  }
}
$state = 0 if $o =~ m/.+/;
$state = 1 if $w =~ m/.+/;
$state = 2 if $c =~ m/.+/;
if ($state == 3) {
  $short = "$str[$state]: Virtual Servers status ($vs_name) could not be determined";
} elsif ($state == 2) {
  $short = "$str[$state]: Virtual Servers ($c) are DOWN";  
} elsif ($state == 1) {
  $short = "$str[$state]: Virtual Servers ($w) may be DOWN";
} else {
  $short = "$str[$state]: Virtual Servers ($vs_name) are UP";
}
print "$short | clients=$conns\n";
exit $state;

#-------------------------------------------------------------------------------
# Subroutine to handle the SNMP responses.
#-------------------------------------------------------------------------------
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
      #---------------------------------------------------------------
      # Processing results now
      #---------------------------------------------------------------
      foreach my $oid (oid_lex_sort(keys(%{$table}))) {
        # Process: ltmVirtualServName
        #-------------------------------------------------------------
        if ($oid =~ /^$ltmVirtualServName.(\d+).(.*)$/) {
          $vs_idx = $1;
          $vs_oid = $2;
          $vs{"$vs_idx"}{"name"} = $table->{$oid};
          $vs{"$vs_idx"}{"oid"}  = $vs_oid;
          print "Base OID: ltmVirtualServName\n\tVS IDX : $vs_idx\n" if $opt_d;
          print "\tVS OID : $vs{\"$vs_idx\"}{\"oid\"}\n" if $opt_d;
          print "\tVS NAME : $vs{\"$vs_idx\"}{\"name\"}\n" if $opt_d;
        }
        # Process: ltmVirtualServEnabled
        #-------------------------------------------------------------
        if ($oid =~ /^$ltmVirtualServEnabled.(\d+).(.*)$/) {
          #$vs_oid = join '.', unpack 'C*', $table->{$oid};
          $vs_idx = $1;
          $vs_oid = $2;
          $vs{"$vs_idx"}{"enabled"} = $table->{$oid};
          print "Base OID: ltmVirtualServEnabled\n\tVS IDX : $vs_idx\n" if $opt_d;
          print "\tVS OID : $vs{\"$vs_idx\"}{\"oid\"}\n" if $opt_d;
          print "\tENABLED: $vs{\"$vs_idx\"}{\"enabled\"}\n" if $opt_d;
        }
        # Process: ltmVsStatusAvailState
        #-------------------------------------------------------------
        if ($oid =~ /^$ltmVsStatusAvailState.(\d+).(.*)$/) {
          #$vs_oid = join '.', unpack 'C*', $table->{$oid};
          $vs_idx = $1;
          $vs_oid = $2;
          $vs{"$vs_idx"}{"state"} = $table->{$oid};
          print "Base OID: ltmVsStatusAvailState\n\tVS IDX : $vs_idx\n" if $opt_d;
          print "\tVS OID : $vs{\"$vs_idx\"}{\"oid\"}\n" if $opt_d;
          print "\tSTATE  : $vs{\"$vs_idx\"}{\"state\"}\n" if $opt_d;
        }
        # Process: ltmVirtualServStatClientCurConns
        #-------------------------------------------------------------
        if ($oid =~ /^$ltmVirtualServStatClientCurConns.(\d+).(.*)$/) {
          #$vs_oid = join '.', unpack 'C*', $table->{$oid};
          $vs_idx = $1;
          $vs_oid = $2;
          $vs{"$vs_idx"}{"conns"} = $table->{$oid};
          print "Base OID: ltmVirtualServStatClientCurConns\n\tVS IDX : $vs_idx\n" if $opt_d;
          print "\tVS OID : $vs{\"$vs_idx\"}{\"oid\"}\n" if $opt_d;
          print "\tCONNS  : $vs{\"$vs_idx\"}{\"conns\"}\n" if $opt_d;
        }
      }
    }
  }
}
