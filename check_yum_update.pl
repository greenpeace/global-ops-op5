#!/usr/bin/perl -w
#
# License: GPL
# Copyright (c) 2007 op5 AB
# Author: Peter Ostlin <peter@op5.com>
#
# For direct contact with any of the op5 developers send a mail to
# op5-users@lists.op5.com
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

use strict;
use Getopt::Long;
sub help();
my $PROGNAME = "check_yum_update";
my $TIMEOUT = 30;
my %EXIT_CODE = (
    'OK', 0,
    'WARNING', 1,
    'CRITICAL', 2,
    'UNKNOWN', 3);

my $YUM_BINARY="/usr/bin/yum";
my ($opt_h, $opt_c, $opt_w, $opt_t, $res);

# Default exit status when updates are available
my $prefered_exit_status=$EXIT_CODE{'WARNING'};

Getopt::Long::Configure("bundling");
$res=GetOptions(
    "h"   => \$opt_h, "help"      => \$opt_h,
    "w"   => \$opt_w, "warning"   => \$opt_w,
    "c"   => \$opt_c, "critical"  => \$opt_c,
    "t=f" => \$opt_t, "timeout=f" => \$opt_t);


if ( ! $res ) {
    exit $EXIT_CODE{'UNKNOWN'};
}

# Set alarmclock
if($opt_t) {
    $TIMEOUT = $opt_t;
}
# Just in case of problems, let's not hang Nagios
$SIG{'ALRM'} = sub {
    print ("ERROR: $PROGNAME timed out, no response from repositories (alarm)\n");
    exit $EXIT_CODE{'UNKNOWN'};
};
alarm($TIMEOUT);

if($opt_h){
    help();
    exit $EXIT_CODE{'UNKNOWN'};
}

if($opt_w){
    $prefered_exit_status = $EXIT_CODE{'WARNING'};
}
if($opt_c){
    $prefered_exit_status = $EXIT_CODE{'CRITICAL'};
}


# Check that yum exist and is executable
if( ! -x $YUM_BINARY){
    print "File '$YUM_BINARY' do not exist or is not executable.\n";
    exit $EXIT_CODE{'UNKNOWN'};
}

$ENV{PATH} = "/usr/bin";
my @updates = `$YUM_BINARY check-update -d 0 -e 0`;

my $retval = ($? >> 8);

if($retval == 0){
    print "Your system is fully updated\n";
    exit $EXIT_CODE{'OK'};
}
my $numupdates=0;
my $pkgavail;
# my $perfdata="";
if($retval == 100){
    foreach(@updates){
	if ($_ !~ /^[ \t\n]*$/){
	    $numupdates++;
	    my @pkginfo;
	    @pkginfo = split(/ /, $_);
	    $pkgavail .= $pkginfo[0] . ", ";
	}
    }
    if(length($pkgavail) > 65 ) {
	$pkgavail = substr($pkgavail, 0, 60);
	$pkgavail =~ s/[^ ]*$//;
	$pkgavail = $pkgavail . "...";
    }
    print "There are $numupdates updates available for your system |Avaialble packages: $pkgavail\n";
    exit ($prefered_exit_status);
}

print "Unknown problem";
exit $EXIT_CODE{'UNKNOWN'};


sub help(){
    print "$PROGNAME checks for available updates using yum.\n\n";
    print "Usage:\n";
    print "   check_yum_update [-w] [-c] [-t <timeout>]\n";
    print " Where:\n";
    print "  -w set exit status to WARNING if updates are available (default)\n";
    print "  -c set exit status to CRITICAL if updates are available\n";
    print "  -t <timeout> set the timeout (in seconds). Default timeout = " . $TIMEOUT . "s\n";
}
