#!/usr/bin/perl
#
# License: GPL
# Copyright (c) 2007-2009 op5 AB
# Author: Peter Ostlin <peter@op5.com>
# Altered by Christian Westergard, Carus Ab Ltd
# Locale issue fixed by Mattias Bergsten <mattias@westbahr.com>
# Performance data output added by Mattias Bergsten <mattias@westbahr.com>
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
package CheckOracle;

use lib "/opt/plugins/";
# use Time::Local 'timelocal_nocheck';
use Scalar::Util 'looks_like_number';
use Getopt::Long;
use utils qw ($TIMEOUT %ERRORS &print_revision &support);
use Switch;
use Nagios::Plugin::Threshold;

$WARN_DEFAULT=0;
$CRIT_DEFAULT=0;

# Helpers
sub print_help ();
sub print_usage ();
sub print_rev ();
sub exec_cmd;
sub trim ($);
sub exec_sql_cmd($);
sub check_tablespace();
sub check_extents();
sub check_extents_table();
sub check_backupmode();
sub check_datafile();
sub check_datafile_bytes;
sub check_datafiles();
sub check_numdatafiles();
sub check_cachehit();
sub check_locks();
sub check_broken();
sub check_fail();
sub check_deferror();
sub check_invalid();
sub check_query();
sub check_archiving();

sub range_compare_helper_outside;
sub range_compare_helper_inside;
sub check_float_thresholds;
sub check_prog_avail($);
sub format_multi;
sub my_die($);
sub get_auth();
our ($opt_c, $opt_t, $opt_e, $opt_l, $opt_d, $opt_u, $opt_p, $opt_w, $opt_h, $opt_V, $opt_o, $opt_a, $opt_v, $opt_s, $opt_r, $opt_T, $opt_f, $opt_H, $opt_R );
my ($result, $message, $age, $size, $st, $connect_string);
my ($dbmcli_arg);

my $sql_cmd = "";
my $null_dev;

# If Windows, use nul instead of /dev/null
if( $^O eq "MSWin32") {
	$null_dev = "nul";
} else {
	$null_dev = "/dev/null";
}

$DEBUG;

$PROGNAME="check_oracle";
$PROGVERSION="1.3.0";

@ERRORS_STR=('OK','WARNING','CRITICAL','UNKNOWN');

Getopt::Long::Configure("bundling");
$res=GetOptions(
	"h"   => \$opt_h, "help"    => \$opt_h,
	"V"   => \$opt_V, "VERSION"    => \$opt_V,
	"v"   => \$opt_v, "verbose" => \$opt_v,
	"o=s" => \$opt_o, "option=s"    => \$opt_o,
	"d=s" => \$opt_d, "db=s" => \$opt_d,
	"s=s" => \$opt_s, "string=s"    => \$opt_s,
	"t=s" => \$opt_t, "tns=s"    => \$opt_t,
	"a=s" => \$opt_a, "argument=s" => \$opt_a,
	"e=s" => \$opt_e, "argument=s" => \$opt_e,
	"r=s" => \$opt_r, "search=s" => \$opt_r,
	"l=s" => \$opt_l, "login=s"    => \$opt_l,
	"u=s" => \$opt_u, "user=s" => \$opt_u,
	"p=s" => \$opt_p, "passwd=s" => \$opt_p,
	"T=f" => \$opt_T, "timeout=f" => \$opt_T,
	"w=s" => \$opt_w, "warning=s" => \$opt_w,
	"c=s" => \$opt_c, "critical=s" => \$opt_c,
	"O=s" => \$opt_O, "ORACLE_HOME=s" => \$opt_O,
	"P=s" => \$opt_P, "PATH=s" => \$opt_P,
	"f=s" => \$opt_f, "authfile=s" => \$opt_f,
	"H=s" => \$opt_H, "host=s" => \$opt_H,
	"R=i" => \$opt_R, "port=i" => \$opt_R,
	"k=s" => \$opt_k, "kom=s" => \$opt_k);

if ( ! $res ) {
	exit $ERRORS{"UNKNOWN"};
}

# Set alarmclock
if($opt_T) {
	$TIMEOUT = $opt_T;
}
# Just in case of problems, let's not hang Nagios
$SIG{'ALRM'} = sub {
	print ("ERROR: $PROGNAME timed out, no response from database (alarm)\n");
	exit $ERRORS{"UNKNOWN"};
};
alarm($TIMEOUT);


if(defined($opt_R) and defined($opt_H)){
	$opt_H.=":".$opt_R;
}

if($opt_v){
	$DEBUG=TRUE;
}

if ($opt_V) {
	print_rev();
	exit $ERRORS{"OK"};
}
if ($opt_h) {
	print_usage();
	exit $ERRORS{"OK"};
}

# Set environment variables if provided
if($opt_O) {
	$ENV{'ORACLE_HOME'}=$opt_O;
}
if($opt_P) {
	$ENV{'PATH'}="$ENV{'PATH'}:$opt_P";
} else {
	if($opt_O) {
		$ENV{'PATH'}="$ENV{'PATH'}:$opt_O/bin";
	}
}

# Fetch username/password from file so that they do not show in 'ps' output.
get_auth();


if ($opt_o) {
	switch($opt_o) {
		case "TABLESPACE" {
			check_tablespace();
		}
		case "EXTENTS" {
			check_extents();
		}
		case "EXTENTS_TABLE" {
			check_extents_table();
		}
		case "BACKUPMODE" {
			check_backupmode();
		}
		case "DATAFILE" {
			check_datafile();
		}
		case "DATAFILE_BYTES" {
			check_datafile_bytes();
		}
		case "NUMDATAFILES" {
			check_numdatafiles();
		}
		case "CACHEHIT" {
			check_cachehit();
		}
		case "QUERY" {
			check_query();
		}
		case "ARCHIVING" {
			check_archiving();
		}
		case "LOCKS" {
			check_locks();
		}
		case "BROKEN" {
			check_broken();
		}
		case "FAIL" {
			check_fail();
		}
		case "DEFERROR" {
			check_deferror();
		}
		case "INVALID" {
			check_invalid();
		}
		default {
			print "no matching command\n";
			exit $ERRORS{'UNKNOWN'};
		}
	}
}

# Set NLS_LANG so no matter the server locale, we get the strings we're expecting
$ENV{'NLS_LANG'}="AMERICAN";

if($opt_t){
	my $cmd = "tnsping $opt_t";

	check_prog_avail("tnsping");
	@out = `$cmd`;
	$res = trim(@out[-1]);
	if( $res =~ m/^OK/){
		$res =~ s/^OK[ \t]*\(//;
		$res =~ s/\)$//;
		print "OK - responstime: $res from $opt_t\n";
		exit $ERRORS{'OK'};
	}
	if( $res =~ m/^TNS-/){
		print "WARNING - $res\n";
		exit $ERRORS{'WARNING'};
	}
	print "CRITICAL - No TNS listener on $opt_t\n";
	exit $ERRORS{'CRITICAL'};
}

if($opt_l){
	check_prog_avail("sqlplus");
	if(($opt_u && !$opt_p) || (!$opt_u && $opt_p)){
		print "Both username and password must be supplied\n";
		exit $ERRORS{'UNKNOWN'};
	}
	if($opt_H){
		$connect_string="$opt_H/$opt_l";
	} else {
		$connect_string="$opt_l";
	}
	my $cmd = "sqlplus dummy/user\@$connect_string < $null_dev";

	if($opt_u){
		$cmd = "sqlplus $opt_u/$opt_p\@$connect_string < $null_dev";
	}
	if($DEBUG){
		print "command to execute: '$cmd'\n";
	}

	@out = `$cmd 2>&1`;
	if($? != 0){
		print "Failed to execute sqlplus. @out";
		exit $ERRORS{'UNKOWN'};
	}

	if($DEBUG){
		print "sqlplus result: \n@out\n";
	}

	if($opt_u){
		if("@out" =~ m/Connected to/){
			print "OK - Login as user '$opt_u' successfull\n";
			exit $ERRORS{'OK'};
		}
		foreach(@out){
			if( m/^ORA-/ ){
				$errmsg = trim($_);
				print "CRITICAL - Login for user '$opt_u' failed - $errmsg\n";
				exit $ERRORS{'CRITICAL'};
			}
		}
		print "CRITICAL - Login for user '$opt_u' failed\n";
		exit $ERRORS{'CRITICAL'};
	} else {
		if ("@out" =~ m/ORA-01017/){
			print "OK - Dummy login connected\n";
			exit $ERRORS{'OK'};
		}
		foreach(@out){
			if( m/^ORA-01017/ ){
				$errmsg = trim($_);
				print "CRITICAL - Dummy login failed - $errmsg\n";
				exit $ERRORS{'CRITICAL'};
			}
		}
		print "CRITICAL - Dummy login failed\n";
		exit $ERRORS{'CRITICAL'};
	}
}

# Hidden option... only for use when plugins is used on local oracle server running linux
# Not shown in help text anymore.
if($opt_d){
	my $cmd = "ps -ef | grep -v grep | grep -c ora_pmon_$opt_d";
	@out = `$cmd`;
	$num_procs = trim(@out[0]);
	if($num_procs ge 1){
		print "$opt_d OK - $num_procs PMON process(es) running\n";
		exit $ERRORS{'OK'};
	} else {
		print "$opt_d CRITICAL - Database is down\n";
		exit $ERRORS{'CRITICAL'};
	}
}

print "Not enough arguments. Execute check_oracle --help for usage instructions\n";
exit $ERRORS{'UNKNOWN'};


#########
# Helpers
#########
sub check_cachehit(){
	$sql_cmd = "SELECT ROUND((1-(phy.value / (cur.value + con.value)))*100,2) FROM v\$sysstat cur, v\$sysstat con, v\$sysstat phy WHERE cur.name = 'db block gets' AND con.name = 'consistent gets' AND phy.name = 'physical reads';";

	#special case, cache hit ratio should be > threshold to not trigger warning/critical

	$opt_w = $opt_w . ":" if defined($opt_w) and not $opt_w =~ m/:$/;
	$opt_c = $opt_c . ":" if defined($opt_c) and not $opt_c =~ m/:$/;
	@res = exec_sql_cmd($sql_cmd);
	$result = trim(@res[0]);
	$status = check_float_thresholds($result);
	print "@ERRORS_STR[$status] - Cache hit ratio: $result%\n";
	exit $status;
}
sub check_numdatafiles(){
	$sql_cmd = "select count(file_id) from dba_data_files;";
	@res = exec_sql_cmd($sql_cmd);
	$result = trim(@res[0]);
	$status = check_float_thresholds($result);
	print "@ERRORS_STR[$status] - Total number of data files is $result\n";
	exit $status;
}
sub check_locks(){
	$sql_cmd = "select count(1) as antal from v\$session where nvl(lockwait,'UNKNOWN')<>'UNKNOWN';"; # What is $session supposed to be?
	@res = exec_sql_cmd($sql_cmd);
	$result = trim(@res[0]);
	$status = check_float_thresholds($result);
	print "@ERRORS_STR[$status] - Total number of locks is $result\n";
	exit $status;
}
sub check_broken(){
	$sql_cmd = "select count(1) as antal from sys.dba_jobs where broken = 'Y';";
	@res = exec_sql_cmd($sql_cmd);
	$result = trim(@res[0]);
	$status = check_float_thresholds($result);
	print "@ERRORS_STR[$status] - Total number of broken transactions is $result\n";
	exit $status;
}
sub check_fail(){
	$sql_cmd = "select count(1) as antal from sys.dba_jobs where failures <> 0;";
	@res = exec_sql_cmd($sql_cmd);
	$result = trim(@res[0]);
	$status = check_float_thresholds($result);
	print "@ERRORS_STR[$status] - Total number of failed transactions is $result\n";
	exit $status;
}
sub check_deferror(){
	$sql_cmd = "select count(1) as antal from deferror;";
	@res = exec_sql_cmd($sql_cmd);
	$result = trim(@res[0]);
	$status = check_float_thresholds($result);
	print "@ERRORS_STR[$status] - Total number of transactions in deferred error queue is $result\n";
	exit $status;
}
sub check_invalid(){
	$sql_cmd = "select count(1) as antal from sys.dba_objects where status='INVALID';";
	@res = exec_sql_cmd($sql_cmd);
	$result = trim(@res[0]);
	$status = check_float_thresholds($result);
	print "@ERRORS_STR[$status] - Total number of invalid transations is $result\n";
	exit $status;
}
sub check_query() {
	if(!$opt_a) {
		print "Option 'QUERY' requires -a <sql-query>\n";
		exit $ERRORS{"UNKNOWN"};
	}
	if($opt_s) {
		$outStr = $opt_s;
	} else {
		$outStr = "Query returned: ";
	}
	$sql_cmd = $opt_a . ";";
	@res = exec_sql_cmd($sql_cmd);
	$resStr = trim(@res[0]);

	if($opt_r){
		$numhits = 0;
		if(@res2 = grep(/$opt_r/,@res)){
			$numhits = scalar @res2;
			$status = check_float_thresholds($numhits);
		} else {
			$status = 2;
		}
		print "@ERRORS_STR[$status] - $outStr $numhits\n";
		exit $status;
	}
	if($opt_w || $opt_c) {
		$status = check_float_thresholds($resStr);
		if (looks_like_number($resStr)) {
			print "@ERRORS_STR[$status] - $outStr $resStr|result=$resStr;$opt_w;$opt_c\n";
		} else {
			print "@ERRORS_STR[$status] - $outStr $resStr\n";
		}

		exit $status;
	}
	print "QUERY option requires a search-string and/or numeric tresholds\n";
	exit {"UNKNOWN"};
}

sub check_archiving(){
	$sql_cmd = "select log_mode from v\$database;";
	@res = exec_sql_cmd($sql_cmd);
	$logmode = trim(@res[0]);
	if($logmode eq "ARCHIVELOG") {
		print "OK - Log mode is 'ARCHIVELOG'\n";
		exit $ERRORS{"OK"};
	} else {
		print "CRITICAL - Log mode is '$logmode'";
		exit $ERRORS{"CRITICAL"};
	}
}

sub check_datafile(){
	if($opt_a){
		$sql_cmd = "select round(((a.BYTES-b.BYTES)/a.BYTES)*100,2), a.FILE_NAME from ( select sum(BYTES) BYTES, FILE_NAME from dba_data_files where file_id=(select max(file_id) from dba_free_space where tablespace_name='$opt_a') group by FILE_NAME ) a, ( select sum(BYTES) BYTES from dba_free_space where file_id=(select max(file_id) from dba_free_space where tablespace_name='$opt_a') group by TABLESPACE_NAME ) b ;";
		@res = exec_sql_cmd($sql_cmd);
		$result = trim(@res[0]);
		$file = trim(@res[1]);
		@filearr = split("/", $file);
		$status = check_float_thresholds($result);
		print "@ERRORS_STR[$status] - Latest datafile (@filearr[$filearr-1]) for tablespace '$opt_a' is $result% full\n";
		exit $status;
	}
	print "Option DATAFILE requires a tablespace argument\n";
	exit $ERRORS{"UNKNOWN"};
}

sub check_extents(){
	if($opt_a){
		# Check single table_space
		$sql_cmd = "select TOTAL_EXTENTS from dba_free_space_coalesced where TABLESPACE_NAME like '$opt_a';";
		@res = exec_sql_cmd($sql_cmd);
		$result = trim(@res[0]);
		$status = check_float_thresholds($result);
		print "@ERRORS_STR[$status] - Tablespace '$opt_a' has $result extents left\n";
		exit $status;
	} else {
		# Check all tablespaces
		if($opt_c){
			$treshold = $opt_c;
		} elsif ($opt_w) {
			$treshold = $opt_w;
		} else {
			print "Option 'EXTENTS' requires a warning _or_ a critical treshold\n";
			exit $ERRORS{"UNKNOWN"};
		}
		$treshold_min = (split(":", $treshold))[0];
		$treshold_max = (split(":", $treshold))[1];
		if($treshold_min eq "" or $treshold_min eq "~")
		{
			undef $treshold_min;
		}
		if($treshold_max eq ""){undef $treshold_max;}
		my $sql_treshold = "";
		if(defined($treshold_min))
		{
			$sql_treshold .= "TOTAL_EXTENTS <= $treshold_min";
			if(defined($treshold_max)){$sql_treshold .= " and ";}
		}
		if(defined($treshold_max))
		{
			$sql_treshold .= "TOTAL_EXTENTS >= $treshold_max";
		}
		$sql_cmd = "select TABLESPACE_NAME from dba_free_space_coalesced where ".$sql_treshold.";";
		@res = exec_sql_cmd($sql_cmd);
		$num=@res;
		if(@res[0] eq ''){
			$num=0;
		}
		$result_str = format_multi(@res);
		if($num == 0){
			print "OK - All tablespaces have ".range_compare_helper_inside($treshold, "more than")." $treshold extents left\n";
			exit $ERRORS{"OK"}
		} elsif ($opt_c) {
			print "CRITICAL - $num tablespaces have ".range_compare_helper_outside($treshold, "less than")." $treshold extents left. ($result_str)\n";
			exit $ERRORS{"CRITICAL"};
		} elsif ($opt_w) {
			print "WARNING - $num tablespaces have ".range_compare_helper_outside($treshold, "less than")." $treshold extents left. ($result_str)\n";
			exit $ERRORS{"WARNING"};
		}

	}
	print "Unknown error\n";
	exit $ERRORS{"UNKNOWN"};
}

sub check_tablespace(){
	if($opt_a){
		$sql_cmd = "select round(((a.BYTES-b.BYTES)/a.BYTES)*100,2) from ( select sum(BYTES) BYTES from dba_data_files where TABLESPACE_NAME like '$opt_a' group by TABLESPACE_NAME ) a, ( select sum(BYTES) BYTES from dba_free_space where TABLESPACE_NAME like '$opt_a' group by TABLESPACE_NAME ) b;";
		@res = exec_sql_cmd($sql_cmd);
		$result = trim(@res[0]);
		$status = check_float_thresholds($result);
		print "@ERRORS_STR[$status] - Tablespace '$opt_a' is $result% full\n";
		exit $status;
	} elsif($opt_e){
		# Check all tablespaces except excluded
		if($opt_c){
			$treshold = $opt_c;
		} elsif ($opt_w) {
			$treshold = $opt_w;
		} else {
			print "Option 'TABLESPACE' requires a warning _or_ a critical treshold\n";
			exit $ERRORS{"UNKNOWN"};
		}
		$opt_e =~ s/,/','/g;
		$treshold_min = (split(":", $treshold))[0];
		$treshold_max = (split(":", $treshold))[1];
		if(!defined($treshold_max))
		{
			$treshold_max=$treshold_min;
			undef $treshold_min;
		}
		if($treshold_min eq "" or $treshold_min eq "~"){undef $treshold_min;}
		if($treshold_max eq ""){undef $treshold_max;}
		my $sql_treshold = "";
		if(defined($treshold_min))
		{

			$sql_treshold .= "((a.BYTES-b.BYTES)/a.BYTES*100) <= $treshold_min";
			if(defined($treshold_max)){$sql_treshold .= " or ";}
		}
		if(defined($treshold_max))
		{
			$sql_treshold .= "((a.BYTES-b.BYTES)/a.BYTES*100) >= $treshold_max";
		}
		$sql_cmd = "select a.TABLESPACE_NAME from ( select TABLESPACE_NAME, sum(BYTES) BYTES from dba_data_files where TABLESPACE_NAME not in ('$opt_e') group by TABLESPACE_NAME ) a, ( select TABLESPACE_NAME, sum(BYTES) BYTES from dba_free_space group by TABLESPACE_NAME ) b where a.TABLESPACE_NAME=b.TABLESPACE_NAME and ($sql_treshold) order by ((a.BYTES-b.BYTES)/a.BYTES) desc;";
		@res = exec_sql_cmd($sql_cmd);
		$num=@res;
		if(@res[0] eq ''){
			$num=0;
		}
		$result_str = format_multi(@res);
		if($num == 0){
			print "OK - All tablespaces use ".range_compare_helper_inside($treshold, "less than")." $treshold%\n";
			exit $ERRORS{"OK"}
		} elsif ($opt_c) {
			print "CRITICAL - $num tablespaces use ".range_compare_helper_outside($treshold, "more than")." $treshold% ($result_str)\n";
			exit $ERRORS{"CRITICAL"};
		} elsif ($opt_w) {
			print "WARNING - $num tablespaces use ".range_compare_helper_outside($treshold, "more than")." $treshold% ($result_str)\n";
			exit $ERRORS{"WARNING"};
		}
	} else {
		# Check all tablespaces
		if($opt_c){
			$treshold = $opt_c;
		} elsif ($opt_w) {
			$treshold = $opt_w;
		} else {
			print "Option 'TABLESPACE' requires a warning _or_ a critical treshold\n";
			exit $ERRORS{"UNKNOWN"};
		}
		$treshold_min = (split(":", $treshold))[0];
		$treshold_max = (split(":", $treshold))[1];
		if(!defined($treshold_max))
		{
			$treshold_max=$treshold_min;
			undef $treshold_min;
		}
		if($treshold_min eq "" or $treshold_min eq "~"){undef $treshold_min;}
		if($treshold_max eq ""){undef $treshold_max;}
		my $sql_treshold = "";
		if(defined($treshold_min))
		{

			$sql_treshold .= "((a.BYTES-b.BYTES)/a.BYTES*100) <= $treshold_min";
			if(defined($treshold_max)){$sql_treshold .= " or ";}
		}
		if(defined($treshold_max))
		{
			$sql_treshold .= "((a.BYTES-b.BYTES)/a.BYTES*100) >= $treshold_max";
		}
		$sql_cmd = "select a.TABLESPACE_NAME from ( select TABLESPACE_NAME, sum(BYTES) BYTES from dba_data_files group by TABLESPACE_NAME ) a, ( select TABLESPACE_NAME, sum(BYTES) BYTES from dba_free_space group by TABLESPACE_NAME ) b where a.TABLESPACE_NAME=b.TABLESPACE_NAME and ($sql_treshold) order by ((a.BYTES-b.BYTES)/a.BYTES) desc;";
		@res = exec_sql_cmd($sql_cmd);
		$num=@res;
		if(@res[0] eq ''){
			$num=0;
		}
		$result_str = format_multi(@res);
		if($num == 0){
			print "OK - All tablespaces use ".range_compare_helper_inside($treshold, "less than")." $treshold%\n";
			exit $ERRORS{"OK"}
		} elsif ($opt_c) {
			print "CRITICAL - $num tablespaces use ".range_compare_helper_outside($treshold, "more than")." $treshold% ($result_str)\n";
			exit $ERRORS{"CRITICAL"};
		} elsif ($opt_w) {
			print "WARNING - $num tablespaces use ".range_compare_helper_outside($treshold, "more than")." $treshold% ($result_str)\n";
			exit $ERRORS{"WARNING"};
		}
	}
	print "Unknown error\n";
	exit $ERRORS{"UNKNOWN"};
}

sub check_backupmode(){
	if($opt_a){
		# Check a particular tablespace
		$sql_cmd = "select a.TABLESPACE_NAME from (select FILE_ID, TABLESPACE_NAME from dba_data_files) a, (select FILE# from v\$backup where STATUS like 'ACTIVE') b WHERE a.FILE_ID = b.FILE# AND a.TABLESPACE_NAME = '$opt_a' GROUP BY a.TABLESPACE_NAME;";
		@res = exec_sql_cmd($sql_cmd);
		if(trim(@res[0]) eq $opt_a){
			print "CRITICAL - Tablespace '$opt_a' is in backupmode\n";
			exit $ERRORS{"CRITICAL"};
		} else {
			print "OK - Tablespace '$opt_a' is not in backupmode\n";
			exit $ERRORS{"OK"};
		}
	} else {
		# Check all tablespaces
		$sql_cmd = "select a.TABLESPACE_NAME from (select FILE_ID, TABLESPACE_NAME from dba_data_files) a, (select FILE# from v\$backup where STATUS like 'ACTIVE') b WHERE a.FILE_ID = b.FILE# GROUP BY a.TABLESPACE_NAME;";
		@res = exec_sql_cmd($sql_cmd);
		$num = @res;
		if(trim(@res[0]) eq ""){
			print "OK - No tablespaces in backupmode\n";
			exit $ERRORS{"OK"};
		} else {
			$resStr = format_multi(@res);
			print "CRITICAL - $num tablespaces are in backupmode ($resStr)\n";
			exit $ERRORS{"CRITICAL"};
		}
	}
}


sub check_datafile_bytes() {
	if($opt_a){
		$sql_cmd = "select (MAXBYTES - BYTES)/1024/1024, FILE_NAME FROM dba_data_files WHERE FILE_ID=(select max(file_id) from dba_data_files where tablespace_name='$opt_a');";
		@res = exec_sql_cmd($sql_cmd);
		$result = trim(@res[0]);
		$file = trim(@res[1]);
		@filearr = split("/", $file);
		$status = check_float_thresholds($result);
		print "@ERRORS_STR[$status] - Latest datafile (@filearr[$filearr-1]) for tablespace '$opt_a' has $result MB left\n";
		exit $status;
	}
	print "Option DATAFILE requires a tablespace argument\n";
	exit $ERRORS{"UNKNOWN"};
}

sub check_extents_table() {
	if($opt_a){
		# Check single table_space
		$sql_cmd = "select (max_extents - extents) from dba_segments where SEGMENT_NAME like '$opt_a';";
		@res = exec_sql_cmd($sql_cmd);
		$result = trim(@res[0]);
		$status = check_float_thresholds($result);
		print "@ERRORS_STR[$status] - Table '$opt_a' has $result extents left\n";
		exit $status;
	} else {
		# Check all tablespaces
		if($opt_c){
			$treshold = $opt_c;
		} elsif ($opt_w) {
			$treshold = $opt_w;
		} else {
			print "Option 'EXTENTS_TABLE' requires a warning _or_ a critical treshold\n";
			exit $ERRORS{"UNKNOWN"};
		}
		$treshold_min = (split(":", $treshold))[0];
		$treshold_max = (split(":", $treshold))[1];
		if($treshold_min eq "" or $treshold_min eq "~"){undef $treshold_min;}
		if($treshold_max eq ""){undef $treshold_max;}
		my $sql_treshold = "";
		if(defined($treshold_min))
		{

			$sql_treshold .= "(max_extents - extents) <= $treshold_min";
			if(defined($treshold_max)){$sql_treshold .= " or ";}
		}
		if(defined($treshold_max))
		{
			$sql_treshold .= "(max_extents - extents) >= $treshold_max";
		}
		$sql_cmd = "select SEGMENT_NAME from dba_segments where SEGMENT_TYPE like 'TABLE' AND $sql_treshold;";
		@res = exec_sql_cmd($sql_cmd);
		$num=@res;
		if(@res[0] eq ''){
			$num=0;
		}
		$result_str = format_multi(@res);
		if($num == 0){
			print "OK - All tables have ".range_compare_helper_inside($treshold, "more than")." $treshold extents left\n";
			exit $ERRORS{"OK"}
		} elsif ($opt_c) {
			print "CRITICAL - $num tables have ".range_compare_helper_outside($treshold, "less than")." $treshold extents left. ($result_str)\n";
			exit $ERRORS{"CRITICAL"};
		} elsif ($opt_w) {
			print "WARNING - $num tables have ".range_compare_helper_outside($treshold, "less than")." $treshold extents left. ($result_str)\n";
			exit $ERRORS{"WARNING"};
		}
	}
	print "Unknown error\n";
	exit $ERRORS{"UNKNOWN"};
}

# Adapt output if the threshold is a range, for which less than/greater than isn't valid, instead outside/inside will be used
sub range_compare_helper_outside {
	my ($range, $text)=@_;
	if(index($range, ":")>-1) {
		return "outside";
	} else {
		return $text;
	}
}

# Adapt output if the threshold is a range, for which less than/greater than isn't valid, instead outside/inside will be used
sub range_compare_helper_inside {
	my ($range, $text)=@_;
	if(index($range, ":")>-1) {
		return "within";
	} else {
		return $text;
	}
}

# Print usage information
sub print_usage () {
	print "\nThis plugin can be used to check the status of an Oracle server.\n";
	print "NOTE: to use this plugin you need to install Oracle Instant Client on the\n";
	print "server executing the plugin, normally the op5 Monitor Server.\n";
	print "Visit www.op5.com/support for instructions on how to setup Instant Client.\n\n";
	print "Usage:\n";
	print " $PROGNAME [-h | --help]\n";
	print "    Print this text and exit\n";
	print " $PROGNAME [-V | --version]\n";
	print "    Print version information\n";

	print " $PROGNAME -t <ORACLE_SID>\n";
	print "    tnsping the selected SID (Note: need tnsping executable) \n";
# Hidden option... only for use when plugins is used on local oracle server running linux
#    print " $PROGNAME -d <ORACLE_SID>\n";
#    print "    check that database is running\n";
	print " $PROGNAME -l <ORACLE_SID> -u <user> -p <passwd> \n";
	print "    Login to selected SID using supplied user/password. If no user/password\n";
	print "    attemt a 'dummy' login expecting a 'ORA-01017' login failed.\n";
	print " $PROGNAME -o CACHEHIT -l <SID> -u <user> -p <passwd> [-w <warn>][-c <crit>]\n";
	print "    Compute the cache hit ratio in %. Alert if less than <warn> <crit>.\n";
	print " $PROGNAME -o TABLESPACE -l <SID> -u <user> -p <passwd> [-a <tablespace>]\n";
	print "           [-w <warn>] [-c <crit>]\n";
	print "           [-e <tablespace>]\n";
	print "    Check tablespace usage. If -a <tablespace> a particular tablespace is\n";
	print "    checked. If -e then all tablespaces are checked except the specified one.\n";
	print "    Multiple tablespaces can be used with -e. Separate them with , (comma).\n";
	print "    If no <tablespace> is supplied all tablespaces are checked\n";
	print "    and a list of all that exceed warning or critical treshold are presented.\n";
	print " $PROGNAME -o DATAFILE -l <SID> -u <user> -p <password> -a <tablespace_name>\n";
	print "           [-w <warn>] [-c <crit>]\n";
	print "    Check datafile usage on the last file corresponding to the tablespace\n";
	print " $PROGNAME -o DATAFILE_BYTES -l <SID> -u <user> -p <password> -a <tablespace_name>\n";
	print "           [-w <warn>] [-c <crit>]\n";
	print "    Check how much space, in MB, is left on the last file corresponding to\n";
	print "    the tablespace\n";
	print " $PROGNAME -o NUMDATAFILES -l <SID> -u <user> -p <password> \n";
	print "           [-w <warn>] [-c <crit>]\n";
	print "    Check the total number of datafiles\n";
	print " $PROGNAME -o EXTENTS -l <SID> -u <user> -p <password> [-a <tablespace>]\n";
	print "           [-w <warn>] [-c <crit>]\n";
	print "    Check available extents. If -a <tablespace> a particular tablespace is\n";
	print "    checked. If no <tablespace> is supplied all tablespaces are checked and\n";
	print "    a list of all that exceed warning or critical treshold are presented.\n";
	print " $PROGNAME -o EXTENTS_TABLE -l <SID> -u <user> -p <password> [-a <table>]\n";
	print "    Same as above except per table instead of per tablespace.\n";
	print " $PROGNAME -o ARCHIVING -l <SID> -u <user> -p <password>\n";
	print "    Check that log archiving is enabled\n";
	print " $PROGNAME -o BACKUPMODE -l <SID> -u <user> -p <password> [-a <tablespace>]\n";
	print "    Check if in backupmode. If -a <tablespace> a particular tablespace is\n";
	print "    checked. If no tablespace_name is supplied all tablespaces are checked\n";
	print "    and a list of all that are in backupmode are presented.\n";
	print " $PROGNAME -o QUERY -l <SID> -u <user> -p <password> -a <query> \n";
	print "           [-s <output-string>] [-r <search-string>] [-w <warn>] [-c <crit>]\n";
	print "    Execute a user defined query and prosess the result, if:\n";
	print "    -r <search-string> is specified the number of string matches is returned.\n";
	print "    -w <warn> and/or -c <crit> can be used on the number of matches\n";
	print "    If no -r <search-string> is supplied the query should return a numeric\n";
	print "    result which is compared to -w <warn> and -c <crit>\n";
	print "    The -s <output-string> option replaces the default plugin output\n";
	print "    (Query returned:) with this custom string\n";
	print " $PROGNAME -o LOCKS -l <SID> -u <user> -p <password> [-w <warn>] [-c <crit>]\n";
	print "    Check the number of locks\n";
	print " $PROGNAME -o BROKEN -l <SID> -u <user> -p <password> [-w <warn>] [-c <crit>]\n";
	print "    Check the number of broken transactions\n";
	print " $PROGNAME -o FAIL -l <SID> -u <user> -p <password> [-w <warn>] [-c <crit>]\n";
	print "    Check the number of failed transactions\n";
	print " $PROGNAME -o DEFERROR -l <SID> -u <user> -p <password> [-w <warn>] [-c <crit>]\n";
	print "    Check the number of transactions in the deferred error queue\n";
	print " $PROGNAME -o INVALID -l <SID> -u <user> -p <password> [-w <warn>] [-c <crit>]\n";
	print "    Check the number of invalid transactions\n";
	print "\n";
	print " Other options:\n";
	print "  -f <auth-file> can be used instead of -u <username> -p <password>. If both\n";
	print "    options are used the <auth-file> will override -u/-p. The <authfile> should\n";
	print "    be a textfile (readable by the nrpe-user) containing two rows. File format:\n";
	print "    username=<username>\n";
	print "    password=<password>\n";
	print " Environment settings:\n";
	print "  -O <ORACLE_HOME> can be added to all commands. Needed if the environment\n";
	print "    of the user (normaly the nrpe user) do not include ORACLE_HOME\n";
	print "  -P <PATH>. The path to sqlplus if not in the users PATH. \n";
	print "    If this option is not supplied but -O <ORACLE_HOME> is, 'ORACLE_HOME/bin'\n";
	print "    will be added to the PATH.\n";
	print "\n";
	print "  -H <hostname> may be added to all commands. This disables the use of .ora file\n";
	print "  for configuration\n";
	print "  -R <port> may be used to specify a custom port number. The default is 1521.\n";
	print "  -v can be added to all commands making the output more verbose. NOTE: this is\n";
	print "  only commandline debugging, it will not work together with op5 monitor\n";
	print "  -T <timeout> (sec) can be applied to all commands. Default timout: $TIMEOUT\n";
	print "\n";
	print " Examples:\n";
	print "  To check the cache hit ratio, warn if less the 80%, critical if less the 60%\n";
	print "   check_oracle.pl -H <host> -l <SID>  -u <user> -p <pwd> -o CACHEHIT -w 80 -c 60\n";
	print "  To check the number of datafiles using a custom query:\n";
	print "   check_oracle.pl -H <host> -l <SID> -u <user> -p <pwd> -o QUERY -a \"SELECT \n";
	print "   COUNT(file_id) FROM dba_data_files\" -s \"The number of datafiles is:\" -c <criticalrange> -w <warningrange>\n";
	print "\n";
}

sub print_help () {
	print "Execute '$PROGNAME --help' for usage instructions.\n";
}

sub print_rev(){
	print "$PROGNAME v.$PROGVERSION. \n";

}

sub check_prog_avail($){
	my $prog = shift;
	if( $^O eq "MSWin32") {
		my @dirList = split /;/, $ENV{PATH};
		my $testPath;
		foreach $dir (@dirList) {
			if ( -f "$dir\\$prog\.exe" ) {
				return 1;
			}
		}
		print "$prog not found. Edit your envionment\n";
		exit $ERRORS{'UNKNOWN'};
	} else {
		$out = `which $prog 2> /dev/null 1>/dev/null`;
		$prog_exist=$?;
		if ($prog_exist) {
			print "$prog not found (or not executable by current user). Edit your envionment.\n";
			exit $ERRORS{'UNKNOWN'};
		}
		return 1;
	}

}

# Creates a limited lentgh string from supplied array
sub format_multi{
	my $resStr = "";
	$resStr .= trim(shift(@_));
	while($s = shift(@_) ){
		if(length $resStr > 40){
			$resStr .= ",...";
			last;
		}
		$resStr .= ", " . trim($s);
	}
	return $resStr;
}

# Compare a float to supplied warning/critical tresholds
sub check_float_thresholds {
	my $res = shift;
	$res = trim($res);
	# we don't know the locale used by the data source,
	# so we need to make sure that the decimal separator
	# used is '.'.
	$res =~ s/,/./;
	if($DEBUG){
		print "Comparing value '$res' to tresholds\n";
	}
	if (!looks_like_number $res) {
		print "Non-numeric result: $res\n";
		exit $ERRORS{"UNKNOWN"};
	}
	my $p = Nagios::Plugin::Threshold->new();
	$p->set_thresholds(warning => $opt_w, critical => $opt_c);
	return $p->get_status($res);
}

sub exec_sql_cmd($) {
	my $sqlStr = shift;
	check_prog_avail("sqlplus");
	if(!$opt_u || !$opt_p){
		print "Missing username or password argument\n";
		exit $ERRORS{"UNKNOWN"};
	}
	if(!$opt_l){
		print "Missing SID argument\n";
		exit $ERRORS{"UNKNOWN"};
	}
	if($DEBUG){
		$_ = $sqlStr;
		$_ =~ s/\\//g;
		print "SQLQUERY:\n$_\n";
	}
	if($opt_H){
		$connect_string = "$opt_H/$opt_l";
	} else {
		$connect_string = "$opt_l";
	}
	use IPC::Open2;
	local (*Reader, *Writer);
	$pid = open2(\*Reader, \*Writer, "sqlplus -s $opt_u/$opt_p\@$connect_string 2>&1");
	$exists = kill 0, $pid;
	if(!$exists) {
		print "Failed to execute sqlplus.";
		exit $ERRORS{"UNKNOWN"};
	}

	# Checking if child process allredy exited, if so there is an error that we should report
	use POSIX ":sys_wait_h";
	$exec_fail = waitpid($pid, WNOHANG);
	if ( !$exec_fail ) {
		$res = print Writer "SET ECHO OFF NEWP 0 SPA 0 PAGES 0 FEED OFF HEAD OFF TRIMS ON\n";
		print Writer $sqlStr;
		print Writer "\n";
		print Writer "exit\n";
		close Writer; # have to close Writer before read

	}
	# have to read and print one line at a time
	while (<Reader>) {
		push (@output,$_);
	}

	close Reader;
	waitpid($pid, 0);
	if($DEBUG) {
		print "Query returned: ";
		if (scalar(@output) == 1){
			print trim @output[0];
			print "\n";
		} else {
			print "@output\n";
		}
	}

	if( $exec_fail != 0 ){
		$errmsg = trim @output[0];
		print "SQLPLUS reports an error: '$errmsg'\n";
		exit $ERRORS{"UNKNOWN"};
	}
	if(trim(@output[0]) eq "ERROR:"){
		$errmsg = trim @output[1];
		print "SQLPLUS reports an error: '$errmsg'\n";
		exit $ERRORS{"UNKNOWN"};
	}
	return @output;
}


# Strip leading/trailing whitespaces and trailing newline from string
sub trim($){
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}

sub my_die($) {
	my $error = shift;
	print $error;
	exit $ERRORS{'UNKNOWN'};
}


sub get_auth(){
	if($opt_f){
		if(! -e $opt_f){
			print "Auth-file '$opt_f' not found\n";
			exit $ERRORS{"UNKNOWN"};
		}
		open (AUTH_FILE, $opt_f) || my_die "Unable to open auth file\n";
		while( <AUTH_FILE> ) {
			if(s/^[ \t]*username[ \t]*=//){
				$opt_u = trim($_);
			}
			if(s/^[ \t]*password[ \t]*=//){
				$opt_p = trim($_);
			}
		}
	}
}

