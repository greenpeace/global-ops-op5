#!/usr/bin/perl
#
# License: GPL
# Copyright (c) 2006 op5 AB
# Author: Peter Ostlin <peter.ostlin@op5.com>
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

use lib "/opt/plugins/";
use Getopt::Long;
use utils qw ($TIMEOUT %ERRORS &print_revision &support);
use Switch;

$LINUX_PATH = '/home/peter/utv/sap';
$AIX_PATH = '/usr/bin';

$w = "w";


# tresholds
$warn_1 = 0;
$warn_5 = 0;
$warn_15 = 0;
$crit_1 = 0;
$crit_5 = 0;
$crit_15 = 0;

# Helpers
sub print_help ();
sub print_usage ();
sub print_rev ();
# sub exec_cmd;


my ($opt_c, $opt_w, $opt_h, $opt_V, $opt_t);

$PROGNAME="check_load_by_w";
$PROGVERSION="1.1.0";


$opt_w = $WARN_DEFAULT;
$opt_c = $CRIT_DEFAULT;

Getopt::Long::Configure("bundling");
$res=GetOptions(
	"h"   => \$opt_h, "help"    => \$opt_h,
	"V"   => \$opt_V, "VERSION"    => \$opt_V,
	"t=f" => \$opt_t, "timeout=f" => \$opt_t,
	"w=s" => \$opt_w, "warning=s" => \$opt_w,
	"c=s" => \$opt_c, "critical=s" => \$opt_c);

if ( ! $res ) {
	exit $ERRORS{"UNKNOWN"};
}

# Set alarmclock
if($opt_t) {
	$TIMEOUT = $opt_t;
}
# Just in case of problems, let's not hang Nagios
$SIG{'ALRM'} = sub {
	print ("ERROR: $PROGNAME timed out (alarm)\n");
	exit $ERRORS{"UNKNOWN"};
};
alarm($TIMEOUT);


if ($opt_V) {
	print_rev();
	exit $ERRORS{"OK"};
}
if ($opt_h) {
	print_usage();
	exit $ERRORS{"OK"};
}

if ( $^O eq "aix") {
	$ENV{'PATH'} = $AIX_PATH;
} else {
	$ENV{'PATH'} = $LINUX_PATH;
}


if ($opt_w) {
#	@critical_treshold = split(/\,/, $opt_c);
	($warn_1, $warn_5, $warn_15) = split(/\,/, $opt_w);

	unless ($warn_1 =~ /^\d*\.?\d+$/ &&
		$warn_5 =~ /^\d*\.?\d+$/ &&
		$warn_15 =~ /^\d*\.?\d+$/) {
		print "Warning treshold should be numeric\n";
		exit $ERRORS{"UNKNOWN"};
	}
}

if ($opt_c) {
#	@critical_treshold = split(/\,/, $opt_c);
	($crit_1,$crit_5,$crit_15) = split(/\,/, $opt_c);

	unless ($crit_1 =~ /^\d*\.?\d+$/ &&
		$crit_5 =~ /^\d*\.?\d+$/ &&
		$crit_15 =~ /^\d*\.?\d+$/) {
		print "Critical treshold should be numeric\n";
		exit $ERRORS{"UNKNOWN"};
	}
}



$cmd = "$w";
# $cmd = "iostat.pl";
if(!(@out = `$cmd 2>/dev/null`)) {
	    print "Failed to execute '$cmd'\n";
	    exit $ERRORS{"UNKOWN"};
	}

# print "out: @out";
$_ = @out[0];

# s/.*load average: // ;
if(!(s/.*load average: // )){
	print "Failed to parse output from '$cmd'\n";
	exit $ERRORS{"UNKNOWN"};
}

chomp($_);

split /\, /;

$val_1 = @_[0];
$val_5 = @_[1];
$val_15 = @_[2];

$exit_state = "OK";

if ($warn_1 > 0  && ($val_1 >= $warn_1 || $val_5 >= $warn_5 || $val_15 >= $warn_15)){
	$exit_state = "WARNING";
}

if ($crit_1 > 0 && ($val_1 >= $crit_1 || $val_5 >= $crit_5 || $val_15 >= $crit_15)){
	$exit_state = "CRITICAL";
}

print "$exit_state - load average: $val_1, $val_5, $val_15|load1=$val_1;$warn_1;$crit_1; load_5=$val_5;$warn_5;$crit_5; load15=$val_15;$warn_15;$crit_15; \n";
exit $ERRORS{$exit_state};




sub print_usage () {
	print "Usage:\n";
	print "  $PROGNAME [-h | --help]\n";
	print "  $PROGNAME [-V | --version]\n";

	print "  $PROGNAME -w, --warning=WLOAD1,WLOAD5,WLOAD15\n";
	print "     Exit with WARNING status if load average exceeds WLOADn\n";
	print "  $PROGNAME -c, --critical=CLOAD1,CLOAD5,CLOAD15\n";
	print "    Exit with CRITICAL status if load average exceed CLOADn\n\n";
	print "\n";
	print "  Global options:\n";
	print "      -t <timeout> (sec) can be applied to all commands. Default timeout: $TIMEOUT\n";
	print "";

}

sub print_help () {
	print "Execute '$PROGNAME --help' for usage instructions.\n";
#	print_usage();
}

sub print_rev(){
	print "$PROGNAME v.$PROGVERSION\n";
}
