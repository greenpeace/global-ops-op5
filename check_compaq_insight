#!/usr/bin/perl
#
# (c)2002 Michael Markstaller, Elaborated Networks GmbH
# send bug reports to <mm@elabnet.de>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty
# of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# you should have received a copy of the GNU General Public License
# along with this program (or with Nagios);  if not, write to the
# Free Software Foundation, Inc., 59 Temple Place - Suite 330,
# Boston, MA 02111-1307, USA
#
#
# Check Comapq Insight Management Agents Systems Status by SNMP
# based on the spong-plugin check_insight from:
#
# http://spong.sourceforge.net/downloads/plugins/spong-network/check_insight
#
#  I've been looking to check the status/health of Compaq Insight Agents on
#  servers and found a spong plugin
#  (http://spong.sourceforge.net/downloads/plugins/spong-network/check_insight)
#  which I've slightly changed to work with Nagios.
#  I have pretty no idea of perl at all, just wanted to make it work for
#  me, so please don't shoot me for this copy-paste-code. I've tested some
#  basic things, it seems to work at least to report a warning if smthg is
#  degraded and OK of course ;)
#  I'm also quite unsure if this is the right way to submit, so I'll just
#  try ;)
#  there're some "unknown" components on all servers I've checked so far,
#  if anybody has a documentation of what's exactly returned when getting
#  the OID 1.3.6.1.4.1.232.11.2.10.1.0 (CPQHOST_MIB isn't very descriptive)
#  I'd be happy to fix this.
#
#
# Usage:
# check_insight -H <host> -C community
#
#
# SHOULD check RAID, fan and power-supplies (according to users)
#

# use strict;
use Net::SNMP;
use Getopt::Long;
Getopt::Long::Configure('bundling');

## replace with utils.pm "any day now"
my %ERRORS = ('OK' => 0, 'WARNING' => 1, 'CRITICAL' => 2, 'UNKNOWN' => 3);

my $version = 0.01;
my $TIMEOUT = 15;
my %h;
my ($opt_V, $opt_h, $verbose, $opt_H, $opt_C);

#
#              get command line options the regular way
#
GetOptions(
	"V"   => \$opt_V, "version"       => \$opt_V,
	"h"   => \$opt_h, "help"          => \$opt_h,
	"v" => \$verbose, "verbose"       => \$verbose,
	"H=s" => \$opt_H, "hostname=s"    => \$opt_H,
	"C=s" => \$opt_C, "community=s"    => \$opt_C);

#
#              handle the verbose stuff first
#
if ($opt_V) {
	print "check_insight nagios plugin version $version\n";
	print "\n";
	print "The nagios plugins come with ABSOLUTELY NO WARRANTY.  You may redistribute\n";
	print "copies of the plugins under the terms of the GNU General Public License.\n";
	print "For more information about these matters, see the file named COPYING.\n";
	print "\n";
	print "(c)2002 Michael Markstaller, Elaborated Networks GmbH\n";
	print "\n";
	print "\n";
	exit $ERRORS{'UNKNOWN'};
}

if ($opt_h) {
	print_help();
	exit $ERRORS{'UNKNOWN'};
}

#
#              now get options the weired way and set the defaults
#              if nothing else is provided
#
$opt_H = shift unless ($opt_H);
print_usage() unless ($opt_H);

#
#              dont let us wait forever...
#
$SIG{'ALRM'} = sub {
	print ("ERROR: No response from server (alarm)\n");
	exit $ERRORS{"UNKNOWN"};
};
alarm($TIMEOUT);


#
#              now we set things up for the real work
#              and fire up the request
#

########################################################################
########
my ($host) = ($opt_H);
my ($color, $summary, $message ) = ( "green", "", "" );
($opt_C) || ($opt_C = shift) || ($opt_C = "public");
my ($community) = $opt_C;

# We use some look up tables for checking some config options.
my (@State) = ("Not Available", "Other", "OK", "Degraded", "Failed");

my (@MIBName) = ("", "Std", "Unknown", "RAID",
                 "Netware", "SCSI", "Health","Unknown",
                 "Store", "SM2", "Thresh", "OS", "UPS",
                 "Unknown", "IDE", "Clusters", "Fibre",
                 "MIB", "NIC");

# These are the positions within the table to actually look at.
my (@MIBs) = (1, 2, 3, 5, 6, 10, 11, 14, 18);

my ($oid) = "1.3.6.1.4.1.232.11.2.10.1.0";	# SysArray

# Open the connection.
my ($session, $error) =
  Net::SNMP->session(Hostname  => $host, Community => $community);

# If we can't open a connection, just return red straight away.
if (! defined $session) {
	print ("ERROR: Unable to contact server '$opt_H'\n");
	exit $ERRORS{"UNKNOWN"};
}


$session->translate;
my ($response) = $session->get_request($oid);

$session->close;

if (!defined $response) {
	# If there's no response, something screwy is going on, give up.
	$summary = $session->error;
	print ("ERROR: $summary\n");
	exit $ERRORS{"UNKNOWN"};
}

#
# we've got a response (of sorts)
#
#
# I'm not convinced that this is the easiest way to go about this, this is
# from some code which I've inherited and I've modified for use in here.
# Hi George!
#
%h = %$response;
my ($d) = $h{$oid};
my (@list) = ();

# Gobble the first two char's.
$d = substr $d,2;

while (length($d) > 0) {
	my ($v) = substr($d,0,2);
	$v = hex($v);
	$d = substr $d,2;
	push @list, $v;
}


# Value in $MIBs[1] is the overall status of the machine...
my ($cond) = $MIBs[1];
$message .= "Status: $State[$cond] ";

foreach my $v (@MIBs) {
	$cond = $list[($v*4)+1];  # A little bit of magic.

	# We only bother printing the status out if it's actually available,
	# as if it's N/A or Unknown then it's probably because the machine
	# isn't available.
	$message .= "$MIBName[$v]: $State[$cond] " if $cond > 1;
	next if $cond < 2;

	# What follows is some trickery to try and not to override a previous
	# message at the same or lower color.
	if ($cond == 4) {
		if ($color ne 'red') {
			$color = 'red';
			$summary = "$MIBName[$v] is failed";
		}
	} elsif ($cond == 3) {
		if ($color ne 'red') {
			$color = 'yellow';
			$summary = "$MIBName[$v] is degraded" if $summary eq "";
		}
	} elsif ($cond < 2) {
		if ($color eq 'green') {
			$color = 'yellow';
			$summary = "$MIBName[$v] is unknown ($cond)" if $summary eq "";
		}
	}
}


$summary = "Ok" if $summary eq "";

#  return ($color, $summary, $message);
if ($color eq 'red') {
	print ("$message\n");
	exit $ERRORS{"CRITICAL"};
}
if ($color eq 'yellow') {
	print ("$summary $message\n");
	exit $ERRORS{"WARNING"};
}
if ($color eq 'green') {
	print ("$message\n");
	exit $ERRORS{"OK"};
}


sub print_usage () {
	print "Usage: $0 -H <host> -C <community> \n";
}

sub print_help () {
	print "check_insight nagios plugin version $version\n";
	print "\n";
	print "The nagios plugins come with ABSOLUTELY NO WARRANTY.  You may redistribute\n";
	print "copies of the plugins under the terms of the GNU General Public License.\n";
	print "For more information about these matters, see the file named COPYING.\n";
	print "\n";
	print "Copyright(C) 2002 Michael Markstaller, Elaborated Networks GmbH\n";
	print "\n";
	print "\n";
	print "This plugin checks the Compaq Insight Management agents system\n";
	print "status via SNMP on the specified host.\n";
	print "\n";
	print "\n";
	print_usage();
	print "\n";
	print "Options:\n";
	print " -H, --hostname=ADDRESS\n";
	print "     host name argument for server.\n";
	print " -C, --community=STRING\n";
	print "     SNMP Read-community string.\n";
	print " -h, --help\n";
	print "     print detailed help screen.\n";
	print " -V, --version\n";
	print "     print version information.\n";
	print "\n";
	print "\n";
}
