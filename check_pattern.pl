#!/usr/bin/perl
#
# License: GPL
# Copyright (c) 2007 op5 AB
# Author: Peter Ostlin <peter@op5.se>
# (Based on the check_log2.pl plugin by Aaron Bostick)
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
use lib "/opt/plugins";
use utils qw($TIMEOUT %ERRORS &usage);
use Getopt::Long;

sub write_seek ();
sub print_help ();
my $log_file = '';
my @logfile;
my $seek_file;
my $num_tot = 0;
my $num_crit = 0;
my $num_warn = 0;
my $DEBUG = 0;
my @seek_pos;
my $perfdata = '';
my ($opt_h, $opt_V, $opt_v, $opt_a, $opt_f, $opt_s, $opt_b, $opt_e, $opt_w, $opt_c, $opt_l, $opt_n, $opt_W, $opt_C, $opt_t);
my ($line, $result, $row);
my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks);

my $PROGNAME = "check_pattern";
my $PROGVERSION = "1.1.1";

# $opt_w=0;
# $opt_c=0;

Getopt::Long::Configure("bundling");
$result=GetOptions(
	"h" => \$opt_h, "help" => \$opt_h,
	"V" => \$opt_V, "VERSION" => \$opt_V,
	"v" => \$opt_v, "verbose" => \$opt_v,
	"a" => \$opt_a, "all" => \$opt_a,
	"l" => \$opt_l, "logrow" => \$opt_l,
	"f=s" => \$opt_f, "logfile=s" => \$opt_f,
	"s=s" => \$opt_s, "seekfile=s" => \$opt_s,
	"b=s" => \$opt_b, "beginsearch=s" => \$opt_b,
	"e=s" => \$opt_e, "endsearch=s" => \$opt_e,
	"n=f" => \$opt_n, "numrows=f" => \$opt_n,
	"W=f" => \$opt_W, "WARN=f" => \$opt_W,
	"t=f" => \$opt_t, "timeout=f" => \$opt_t,
	"C=f" => \$opt_C, "CRIT=f" => \$opt_C,
	"w=f" => \$opt_w, "warning=f" => \$opt_w,
	"c=f" => \$opt_c, "critical=f" => \$opt_c);


if(! $result) {
	exit $ERRORS{'UNKNOWN'};
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


if ( $opt_h ) {
	print_help();
	exit $ERRORS{'OK'};
}

if ( $opt_v ){
	$DEBUG = 1;
}

($opt_f) || usage("Log file not specified.\n");

if(!-f $opt_f) {
	print("No messages logged in $opt_f\n");
	exit(0);
}


open(LOG_FILE, $opt_f) || die "Unable to open log file $opt_f: $!";

# $seek_file = $opt_s;
if ($opt_s) {
	$seek_file = $opt_s;
	if (open(SEEK_FILE, $seek_file)) {

		chomp(@seek_pos = <SEEK_FILE>);
		close(SEEK_FILE);
		#  If file is empty, no need to seek...
		if ($seek_pos[0] != 0) {

			# Compare seek position to actual file size.  If file size is smaller
			# then we just start from beginning (file was rotated or some such)
			($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat(LOG_FILE);
			if ($seek_pos[0] <= $size) {
				seek(LOG_FILE, $seek_pos[0], 0);
			}
		}
	}
}


@logfile = <LOG_FILE>;

my $max_rows = 0;
if ( $opt_n ) {
	$max_rows = $opt_n;
} else {
	$max_rows = scalar(@logfile);
}

while ( ( $line = pop(@logfile) ) &&  $max_rows > $num_tot ){
	$_ = $line;
#	print "1 ";
	if (/$opt_b\d+$opt_e/){
		$row = scalar(@logfile);
		$row += 1;
		$result = $line;
		$result =~ s/^.*$opt_b//;
#		print "res: '$result\n";
		if ($opt_e) {
			$result =~ s/$opt_e.*$//;
		} else {
			$result =~ s/[ \t]*$//;
		}
#		print "res: '$result\n";
		$result =~ s/\s+$//;
#		print "res: '$result\n";
		if( $result !~ /^\d+$/ ){
			print "The value found is not numeric\n";
			if ( $DEBUG ) {
				print "Value found: $result\n";
			}
			exit $ERRORS{'UNKNOWN'};
		}
		if ( defined($opt_w) && $opt_w <= $result ){
			$num_warn += 1;
		}

		if ( defined($opt_c) && $opt_c <= $result ){
			$num_crit += 1;
		}
		$num_tot += 1;
		$perfdata = "|val=$result;$opt_w;$opt_c";
		if($opt_l){
			$perfdata = "|$line";
		}

		if( (! $opt_a) && (! $opt_n) ) {
			if($num_crit){
				write_seek();
				print "CRITICAL - Last matching value = $result (row #$row) exceed $opt_c $perfdata\n";
				exit $ERRORS{'CRITICAL'};
			}
			if($num_warn){
				write_seek();
				print "WARNING - Last matching value = $result (row #$row) exceed $opt_w $perfdata\n";
				exit $ERRORS{'WARNING'};
			}
			write_seek();
			print "OK - Last matching value = $result (row #$row) $perfdata\n";
			exit $ERRORS{'OK'};

		}

	}
}
write_seek();


my $num_ok = $num_tot;
if ( $num_crit > $num_warn ) {
	$num_ok -= $num_crit;
} else {
	$num_ok -= $num_warn;
}

$perfdata = "|rows=$num_ok;$num_warn;$num_crit;$num_tot\n";


if ( $opt_C && $opt_C <= $num_crit) {
	print "CRITICAL - $num_crit of $num_tot matches exceed critical treshold $opt_c $perfdata";
	exit $ERRORS{'CRITICAL'};
}

if ( !$opt_C && $num_crit > 0 ){
	print "CRITICAL - $num_crit of $num_tot matches exceed critical treshold $opt_c $perfdata";
#	print "CRITICAL - $num_crit of $num_tot matches exceed critical treshold $opt_c\n";
	exit $ERRORS{'CRITICAL'};
}

if ( $opt_W && $opt_W <= $num_warn ) {
	print "WARNING - $num_warn of $num_tot matches exceed warning treshold $opt_w $perfdata";
	exit $ERRORS{'WARNING'};
}

if ( !$opt_W && $num_warn > 0 ){
	print "WARNING - $num_warn of $num_tot matches exceed warning treshold $opt_w $perfdata";
	exit $ERRORS{'WARNING'};
}

if ( $num_tot ) {
	print "OK - $num_ok of $num_tot matches is OK ($num_warn is warning and $num_crit is critical) $perfdata";
#	print "OK - All matching values ($num_tot) are below treshold(s)\n";
} else {
	print "OK - No matching pattern found \n";
}
exit $ERRORS{'OK'};




# Helpers
sub write_seek(){
#	print "about to write\n";
	if ( $opt_s) {
		open(SEEK_FILE, "> $seek_file") || die "Unable to open seek count file $seek_file: $!";
		print SEEK_FILE tell(LOG_FILE);
		close(SEEK_FILE);

	}
	close(LOG_FILE);
}

sub print_help(){
	print " $PROGNAME v$PROGVERSION\n";
	print "\n";
	print " $PROGNAME [-h | --help]\n";
	print " $PROGNAME [-V | --version]\n";
	print " $PROGNAME -f <logfile> -b <begin-pattern> -e <end-pattern> [-a]  \n";
	print "           [-w <warning>] [-c <critical>] [-s <seek-file>] [-v] [-l] \n";
	print "           [-W <warnrows> ] [-C <critrows>] [-n <num-matching>]\n";
	print "           [-t <timeout>]\n";
	print "   Where: \n";
	print "     -f <logfile> is the logfile to search. \n";
	print "     -b <begin-pattern> is the (regexp) string preceeding the searched value. \n";
	print "     -b <end-pattern> is the (regexp) string following the searched value. \n";
	print "     -a = search all matching rows in <logfile>. By default the plugin looks \n";
	print "          only at the last matching entry. \n";
	print "     -n <num-matching> search only until this number of matching rows is found.\n";
	print "     -l = Append the matching log row as performance data. By default the found \n";
	print "          value, warning and critical treshold forms the performance data. \n";
	print "     -w <warning> is the warning treshold that the found value is compared to. \n";
	print "          The plugin return warning if the treshold is exceeded. \n";
	print "     -c <critical> is the critical treshold that the found value is compared to. \n";
	print "          The plugin return critical if the treshold is exceeded. \n";
	print "     -s <seek-file> remembers the byte position of the last scan. \n";
	print "          If no seek-file is specified the entire log-file will be searched.\n";
	print "     -W <warnrows> is the number rows that should exceed warning treshold before\n";
	print "          returning warning state. NOTE: requires the -a option.\n";
	print "     -C <critrows> is the number rows that should exceed critical treshold before\n";
	print "          returning critical state. NOTE: requires the -a or -n option.\n";
	print "     -t <timeout> (sec) can be applied to all commands. Default timeout: $TIMEOUT\n";
	print "\n";

}
