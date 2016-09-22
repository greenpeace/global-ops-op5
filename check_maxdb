#!/usr/bin/perl
#
# License: GPL
# Copyright (C) 2006 op5 AB
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

use lib "/opt/plugins/";
use Time::Local 'timelocal_nocheck';
use Getopt::Long;
use utils qw ($TIMEOUT %ERRORS &print_revision &support);
use Switch;
# $ENV{'PATH'} = '/home/peter/utv/sap';
$LINUX_PATH = '/home/peter/utv/sap';
$AIX_PATH = '/sapdb/programs/bin';
# $WIN_PATH = 'D:\sapdb\programs\pgm';
$WIN_PATH = 'D:\sapdb\programs\pgm';

$WARN_DEFAULT=0;
$CRIT_DEFAULT=0;
$DBMCLI = "dbmcli";


# Helpers
sub print_help ();
sub print_usage ();
sub print_rev ();
sub exec_cmd;


my ($opt_c, $opt_o, $opt_u, $opt_w, $opt_h, $opt_d, $opt_s, $opt_V, $opt_r, $opt_q, $opt_t);
my ($result, $message, $age, $size, $st);
my ($dbmcli_arg);

$PROGNAME="check_maxdb";
$PROGVERSION="1.2.0";


$opt_w = $WARN_DEFAULT;
$opt_c = $CRIT_DEFAULT;

Getopt::Long::Configure("bundling");
$res=GetOptions(
	"h"   => \$opt_h, "help"    => \$opt_h,
	"V"   => \$opt_V, "VERSION"    => \$opt_V,
	"o=s" => \$opt_o, "option=s"    => \$opt_o,
	"u=s" => \$opt_u, "auth=s"    => \$opt_u,
	"t=f" => \$opt_t, "timeout=f" => \$opt_t,
	"w=f" => \$opt_w, "warning=f" => \$opt_w,
	"c=f" => \$opt_c, "critical=f" => \$opt_c,
	"d=s" => \$opt_d, "database=s" => \$opt_d,
	"n=s" => \$opt_s, "db=s" => \$opt_s,
	"s=s" => \$opt_s, "server=s" => \$opt_s,
	"q=s" => \$opt_q, "query=s" => \$opt_q,
	"r=s" => \$opt_r, "result=s" => \$opt_r,
    "P=s" => \$opt_P, "PATH=s" => \$opt_P);

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

if ($opt_P) {
	$ENV{'PATH'} = "$ENV{'PATH'}:$opt_P";
} else {
	if ( $^O eq "aix") {
		$ENV{'PATH'} = "$ENV{'PATH'}:$AIX_PATH";
	} elsif ( $^O eq "linux" ) {
		$ENV{'PATH'} = "$ENV{'PATH'}:$LINUX_PATH";
	} else {
		$ENV{'PATH'} = "$ENV{'PATH'}:$WIN_PATH";
	}
}

# Check that all required parameters are present.
check_req_params();

# if($opt_c < $opt_w && $opt_c > 0 ){
#	printf "Critical treshold must be larger then warning treshold.\n";
#	exit $ERRORS{'UNKNOWN'};
# }



switch ($opt_o) {
	case "custom" {
		$_ = escape_string($opt_q);
		$grepstr = '^[ \t]*' . $_ . '[ \t]*=[ \t]';
		$val =  get_state_val($grepstr);
		if ( $val eq "" ){
			printf "UNKOWN - No match for string '$opt_q' not found\n";
			exit $ERRORS{"UNKNOWN"};
		}
		if ( $opt_c && $opt_c <= $val ) {
			printf "CRITICAL - $opt_q = $val\n";
			exit $ERRORS{"CRITICAL"};
		}
		if ( $opt_w && $opt_w <= $val ) {
			printf "WARNING - $opt_q = $val\n";
			exit $ERRORS{"WARNING"};
		}

		if ( $opt_r ) {
			if ( $val ne $opt_r ) {
				printf "CRITICAL - $opt_q = $val\n";
				exit $ERRORS{"CRITICAL"};
			}
		}
		printf "OK - $opt_q = $val\n";
		exit $ERRORS{"OK"};
	}
	case "logfill" {
		$grepstr = '^[ \t]*Log[ \t]*\(\%\)[ \t]*=[ \t]';
		$val =	get_state_val($grepstr);

		if ( $opt_c > 0 && $val >= $opt_c ) {
			printf "CRITICAL - Log is $val%% filled\n";
			exit $ERRORS{"CRITICAL"};
		}
		if ( $opt_w > 0 && $val >= $opt_w ) {
			printf "WARNING - Log is $val%% filled\n";
			exit $ERRORS{"WARNING"};
		}
		printf "OK - Log is $val%% filled\n";
		exit $ERRORS{"OK"};
	}
	case "datafill" {
		$grepstr = '^[ \t]*Data[ \t]*\(\%\)[ \t]*=[ \t]';
		$val =	get_state_val($grepstr);

		if ( $opt_c > 0 && $val >= $opt_c ) {
			printf "CRITICAL - Database is $val%% filled.\n";
			exit $ERRORS{"CRITICAL"};
		}
		if ( $opt_w > 0 && $val >= $opt_w ) {
			printf "WARNING - Database is $val%% filled.\n";
			exit $ERRORS{"WARNING"};
		}
		printf "OK - Database is $val%% filled\n";
		exit $ERRORS{"OK"};
	}
	case "databasefull" {
#		printf "autolog\n";
		$grepstr = '^[ \t]*Database[ \t]*Full[ \t]*=[ \t]*';
		$val =	get_state_val($grepstr);

		if ( $val eq "No" ) {
			printf "OK - Database is not full\n";
			exit $ERRORS{"OK"};
		} else {
			printf "CRITICAL - Database is full\n";
			exit $ERRORS{"CRITICAL"};
		}
	}
	case "logfull" {
#		printf "autolog\n";
		$grepstr = '^[ \t]*Log[ \t]*Full[ \t]*=[ \t]*';
		$val =	get_state_val($grepstr);
		if ( $val eq "No" ) {
			printf "OK - Log is not full\n";
			exit $ERRORS{"OK"};
		} else {
			printf "CRITICAL - Log is full\n";
			exit $ERRORS{"CRITICAL"};
		}
	}
	case "connect" {
#		printf "autolog\n";
		$grepstr = '^[ \t]*Connect[ \t]*Possible[ \t]*=[ \t]*';
		$val =	get_state_val($grepstr);
		if ( $val eq "Yes" ) {
			printf "OK - Connection is possible\n";
			exit $ERRORS{"OK"};
		} else {
			printf "CRITICAL - Connection not possible to Database!\n";
			exit $ERRORS{"CRITICAL"};
		}
	}
	case "autolog" {
#		printf "autolog\n";
		$grepstr = '^[ \t]*Autosave[ \t]*=[ \t]*';
		$val =	get_state_val($grepstr);

		if ( $val eq "On" ) {
			printf "OK - Autosave = On\n";
			exit $ERRORS{"OK"};
		} else {
			printf "CRITICAL - Autosave = $val\n";
			exit $ERRORS{"CRITICAL"};
		}
	}
	case "databackup" {
		@time = get_backup_status("DAT");
		$now = time;

		$warntime = get_epoch_date(@time[1],$opt_w);
		$crittime = get_epoch_date(@time[1],$opt_c);

#		$warntime = get_epoch_daysold($opt_w);
#		$crittime = get_epoch_daysold($opt_c);

#		$last = get_epoch_date(@time[1]);

#		print "warn: $warntime\n";
#		print "crit: $crittime\n";
#		print "now: $now\n";

		if ( $crittime < $now ) {
#		if ( $crittime < $last ) {
			print "CRITICAL - No Data backup since @time[1]\n";
			exit $ERRORS{"CRITICAL"};
		}
		if ( $warntime < $now ) {
#		if ( $warntime < $last ) {
			print "WARNING - No Data backup since @time[1]\n";
			exit $ERRORS{"WARNING"};
		}
		if ( @time[0] eq "0" ) {
			printf "OK - Last Data backup at @time[1] was sucessful, RC = @time[0]\n";
			exit $ERRORS{"OK"};
		} else {
			printf "CRITICAL - Last Data backup at @time[1] was not sucessful, RC = @time[0]\n";
			exit $ERRORS{"CRITICAL"};
		}

	}
	case "logbackup" {
#		printf "logbackup\n";
		@time = get_backup_status("LOG");
		$now = time;

		$warntime = get_epoch_date(@time[1],$opt_w);
		$crittime = get_epoch_date(@time[1],$opt_c);

		if ( $crittime < $now ) {
			print "CRITICAL - No Log backup since @time[1]\n";
			exit $ERRORS{"CRITICAL"};
		}
		if ( $warntime < $now ) {
			print "WARNING - No Log backup since @time[1]\n";
			exit $ERRORS{"WARNING"};
		}
		if ( @time[0] eq "0" ) {
			printf "OK - Last Log backup at @time[1] was sucessful, RC = @time[0]\n";
			exit $ERRORS{"OK"};
		} else {
			printf "CRITICAL - Last Log backup at @time[1] was not sucessful, RC = @time[0]\n";
			exit $ERRORS{"CRITICAL"};
		}
	}
	default {
		printf "Unknown option '$opt_o', terminating.\n";
		exit $ERRORS{"UNKNOWN"};
	}
}

exit(0);

sub get_epoch_date {
	$days = $_[1];
	split /[\- :]/, $_[0];

	if ($days > 0 ){
		return timelocal_nocheck @_[5],$_[4],@_[3],@_[2]+$days,@_[1]-1,@_[0];
	} else {
		return time;
	}
}

# Create a timestamp x days old.
# ($sec,$min,$hour,$mday,$mon,$year)
sub get_epoch_daysold {
	if ( $_[0] > 0 ){
		return timelocal_nocheck @_[5],$_[4],@_[3],@_[2]+$_[0],@_[1]-1,@_[0] ."\n" ;
	} else {
		return time;
	}
}


# Escape and return supplied string. Escapes (,) and %.
sub escape_string () {
	$_ = $_[0];
	s/ /\[ \\t\]\*/g;
	s/\(/\\\(/g;
	s/\)/\\\)/g;
	s/\%/\\\%/g;
	return $_;
}

# 'Generic' backup status check, Used for both Log and Data backup checks.
# Returns an array with return code in [0] and date in [1]
sub get_backup_status {
	$dbmcli_arg = "-d $opt_d -n $opt_s -u $opt_u backup_history_list -inverted -c RC,STOP -l $_[0]";
#	printf "$dbmcli_arg\n";
	@retarr = exec_cmd;
	$_ = @retarr[2];
	s/^[ \t]*//;
	s/\|[ \t\n]*$//;
	split /\|/;
	@time = @_;
#	split /[\- :]/, @time[1];

	return @time;
}

# Fetch a value from info STATE
sub get_state_val {
	$grepstr = $_[0];
	$dbmcli_arg = "-d $opt_d -n $opt_s -u $opt_u info STATE";
	@retarr = exec_cmd;
	@oo = grep {/$grepstr/} @retarr;
#	printf "0: @oo[0]\n";
	$_ = @oo[0];
	s/$grepstr//;
	s/\s+$//;
	return $_;
}


sub exec_cmd {
	my $cmd = "$DBMCLI $dbmcli_arg";
	if(!(@out = `$cmd`)){
		print "dbmcli not found. Check your environment\n";
		exit $ERRORS{'UNKNOWN'};
	}
	$_ = @out[0];
	s/^[ \t]*//;
	s/\s+$//;
#	printf "cmd: '$cmd'\n";
	if ( $_ ne "OK" ) {
		printf "UNKNOWN - Call to dbmcli failed | Errmsg: @out[1]\n";
		exit $ERRORS{"UNKNOWN"};
	}
	return @out;
}



# Strukturen för ett anrop mot MaxDB (eller SAPDB som den tidigare hette):
#
# dbmcli -d <SID> -n <server> -u <userid>,<pw> <command>
#
# <SID> är databasens namn
# <server> är serverns hostnamn eller ip-adress
# <userid> är userid - user,passwd
# <pw> är lösenord
# <command> det kommando vi vill att dbmcli skall utföra.


# Databasbackup -
# dbmcli -d <SID> -n <server> -u <userid>,<pw> backup_history_list -inverted -l DAT -c RC,STOP



# Logbackup
# dbmcli -d <SID> -n <server> -u <userid>,<pw> backup_history_list -inverted -l LOG -c RC,STOP
# Where
# -inverted (senaste backupen först),
# -l LOG (endast Logbackup)
# -c RC,STOP (sorterat på returkod och timestamp när backupen gick klart).

# Lots of checks...
# dbmcli -d <SID> -n <server> -u <userid>,<pw> info STATE
#
# example output (importatn stuff)



# Possible questions:

# check_maxdb -o logfill -w <warn%> -c <crit%> -d <SID> -n <server> -u <userid>,<pw>
# check_maxdb -o datafill -w <warn%> -c <crit%> -d <SID> -n <server> -u <userid>,<pw>
# check_maxdb -o autolog  -d <SID> -n <server> -u <userid>,<pw>
# check_maxdb -o databackup  -d <SID> -n <server> -u <userid>,<pw>
# check_maxdb -o logbackup -d <SID> -n <server> -u <userid>,<pw>


# Check if first row of dbmcli output contain OK.
# IE wheter command was succesfull or not.
sub check_command_status(){
	if (index($_[0], "OK") >= 0 ){
		return 1;
	} else {
		return 0;
	}
}


# Check that all required command line options have been supplied.
# If not, exit and tell user what's missing.
sub check_req_params() {
	if ( ! $opt_o) {
		print "No option specified. ";
		print_help();
		exit $ERRORS{"UNKOWN"};
	}
	if ( ! $opt_s) {
		print "No server specified. ";
		print_help();
		exit $ERRORS{"UNKOWN"};
	}
	if ( ! $opt_u) {
		print "No auth pair specified. ";
		print_help();
		exit $ERRORS{"UNKOWN"};
	}
	if ( ! $opt_d) {
		print "No database specified. ";
		print_help();
		exit $ERRORS{"UNKOWN"};
	}
}


sub print_usage () {
	print "Usage:\n";
	print "  $PROGNAME [-h | --help]\n";
	print "  $PROGNAME [-V | --version]\n";
	print "  $PROGNAME -o logfill -d <SID> -n <server> -u <user,passwd>\n";
	print "            [-w <warn%] [-c <crit%>] \n";
	print "      Check log fillrate in %. Return WARNING/CRITICAL if fillrate is more\n";
	print "      than <warn%>/<crit%>. <warn%> and <crit%> are optional.  \n";
	print "  $PROGNAME -o datafill -d <SID> -n <server> -u <user,passwd> \n";
	print "            [-w <warn%] [-c <crit%>] \n";
	print "      Check log fillrate in %. Return WARNING/CRITICAL if fillrate is more\n";
	print "      than <warn%>/<crit%>. <warn%> and <crit%> are optional.  \n";
	print "  $PROGNAME -o autolog -d <SID> -n <server> -u <user,passwd> \n";
	print "      Return CRITICAL if Autosave is not set to 'On'\n";
	print "  $PROGNAME -o databackup -d <SID> -n <server> -u <user,passwd> \n";
	print "            [-w <warn-days>] [-c <crit-days>] \n";
	print "      Check status of last data backup. Return CRITICAL if the latest backup\n";
	print "      failed. Returns WARNING/CRITICAL if backup is more than \n";
	print "      <warn-days>/<crit-days> old.\n";
	print "  $PROGNAME -o logbackup -d <SID> -n <server> -u <user,passwd> \n";
	print "      Check status of last data backup. Return CRITICAL if the latest backup\n";
	print "      failed. Return WARNING/CRITICAL if backup is more than \n";
	print "      <warn-days>/<crit-days> old.\n";
	print "  $PROGNAME -o custom -d <SID> -n <server> -u <user,passwd> -q <search-string>\n";
	print "            [ [-r <expected-result>] | [-w <warning>] [-c <critical>] ]\n";
	print "      Check custom field in the 'info STATE' result set. <string-to-match>\n";
	print "      should be the part to the left of the equal (=) sign. If the search\n";
	print "      string contains whitespaces it should be enclosed in \"\". Example: \n";
	print "      -q \"Kernel Trace\" returns: 'OK - Kernel Trace = Off'\n";
	print "      The optional <expected-result> matches agains the result, so:\n";
	print "      -q  \"Kernel Trace\" -r \"Off\" returns: 'OK - Kernel Trace = Off'\n";
	print "      And:\n";
	print "      -q  \"Kernel Trace\" -r \"On\" returns: 'CRITICAL - Kernel Trace = Off'\n";
	print "      The optional <warning> and <critical> matches agains numerical results\n";
	print "      and returns WARNING/CRITICAL if result is larger than the respective\n";
	print "      treshold. Example:\n";
	print "      -q \"Data Cache (%)\" returns 'OK - Data Cache (%) = 99'\n";
	print "      -q \"Data Cache (%)\" -w 80 returns 'WARNING - Data Cache (%) = 99'\n";
	print "      -q \"Data Cache (%)\" -w 80 -c 90 returns 'CRITICAL - Data Cache (%) = 99'\n";
	print "\n";
	print " Environment settings:\n";
	print "  -P <PATH>. The path to dbmcli. Only needed if not found in the environment.\n";
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
	print "$PROGNAME v.$PROGVERSION. ";
	if ( $^O eq "aix") {
		print "The AIX version\n";
	} elsif ( $^O eq "linux" ) {
		print "The Linux version\n";
	} else {
		print "The WIN version\n";
	}

}
