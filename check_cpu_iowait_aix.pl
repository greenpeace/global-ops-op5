#!/usr/bin/perl
#  
# Nagios check_cpu_iowait_aix plugin
#
# License: GPL
# Copyright (c) 2006 op5 AB
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
# 

use lib "/opt/plugins/";
use Getopt::Long;
use utils qw ($TIMEOUT %ERRORS &print_revision &support);
use Switch;

$PROGNAME="check_cpu_iostat_aix";
$PROGVERSION="1.1.0";

$LINUX_PATH = '/home/peter/utv/sap';
$AIX_PATH = '/usr/bin';

$iostat = "iostat";

# Helpers
sub find_iowait;
sub print_help ();
sub print_usage ();
sub print_rev ();


my ($opt_c, $opt_w, $opt_h, $opt_V, $opt_t);

Getopt::Long::Configure("bundling");
$res=GetOptions(
	"h"   => \$opt_h, "help"    => \$opt_h,
	"V"   => \$opt_V, "VERSION"    => \$opt_V,
	"t=f" => \$opt_t, "timeout=f" => \$opt_t,
	"w=f" => \$opt_w, "warning=f" => \$opt_w,
	"c=f" => \$opt_c, "critical=f" => \$opt_c);

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
} elsif ( $^O eq "linux" ) {
	$ENV{'PATH'} = $LINUX_PATH;
} else {
	$ENV{'PATH'} = $WIN_PATH;
}

$cmd = "$iostat";
# $cmd = "w";
if(!(@out = `$cmd 2>/dev/null`)) {	
	print "Failed to execute '$cmd'\n";
	exit $ERRORS{"UNKOWN"};
}


$theres = find_iowait(@out);

if($theres == -1){
	print "Failed to parse output from '$cmd'\n";
	exit $ERRORS{"UNKNOWN"};
}

if($opt_c && $theres > $opt_c){
	print "CRITICAL - iowait = $theres%\n";
	exit $ERRORS{"CRITICAL"};
}	
if($opt_w && $theres > $opt_w){
	print "WARNING - iowait = $theres%\n";
	exit $ERRORS{"WARNING"};
}	

print "OK - iowait = $theres%\n";
exit $ERRORS{"OK"};


sub find_iowait{
	$i=0;
	while($row = shift(@_) ){
		$offset = index($row, "% iowait" );
		if($offset != -1){
			$_ = substr(@out[$i+1],$offset);
			s/^\s+//; 
			s/\s+$//;
			@vars = split(/ /);
			return @vars[0];
		}
		$i++;
	}
	return -1;
}

exit 0;


sub print_usage () {
	print "Usage:\n";
	print "  $PROGNAME [-h | --help]\n";
	print "  $PROGNAME [-V | --version]\n";
	print "  $PROGNAME [-w <warn>] [-c <crit>] [-t <timeout>]\n";
	print "    Exit with WARNING/CRITICAL if iowait exceeds tresholds\n";
	print "    warning and critical tresholds are optional\n";
	print "  Default timeout: $TIMEOUT\n";
}

sub print_help () {
	print "Execute '$PROGNAME --help' for usage instructions.\n";
#	print_usage();
}

sub print_rev(){
	print "$PROGNAME v.$PROGVERSION\n";
}



