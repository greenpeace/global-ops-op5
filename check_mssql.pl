#!/usr/bin/perl
#
# License: GPL
# Copyright (c) 2005-2008 op5 AB
# Author: op5 dev team <op5-users@lists.op5.com>
#
# For direct contact with any of the op5 developers send a mail to
# op5-users@lists.op5.com
# Discussions are directed to the mailing list op5-users@op5.com,
# see http://lists.op5.com/mailman/listinfo/op5-users
#
# Rewritten in perl with some inspiration from check_mssql.sh.
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

require 5.004;
use POSIX;
# use strict;
use Getopt::Long;
use File::Temp qw/ :mktemp  /;
use vars qw($opt_h $hostname $verbose $PROGNAME $user $password $port $timeout $online $query $match_string $warning $critical $database
	$instance $tdsversion);
use lib "/opt/plugins";
use utils qw($TIMEOUT %ERRORS &print_revision &support);
use Nagios::Plugin::Range;

$PROGNAME = "check_mssql.pl";
$timeout = 10;
$tdsversion = "7.0";
$warning = 50;
$critical = 100;

sub print_help ();
sub nexit($$);
sub verify_threshold($);
sub trim($);

Getopt::Long::Configure('bundling');
GetOptions
     ("h"   => \$opt_h, "help"       => \$opt_h,
	  "H=s"   => \$hostname, "hostname=s" 	=> \$hostname,
	  "v"   => \$verbose, "verbose" 	=> \$verbose,
	  "U=s" => \$user, "user=s" => \$user,
	  "D=s" => \$database, "database=s" => \$database,
	  "I=s" => \$instance, "instance=s" => \$instance,
	  "V=s" => \$tdsversion, "tdsversion" => \$tdsversion,
	  "P=s" => \$password, "password=s" => \$password,
	  "p=i" => \$port, "port=i" => \$port,
	  "t=i" => \$timeout, "timeout=i" => \$timeout,
	  "o"   => \$online, "online" => \$online,
	  "Q=s" => \$query, "sqlquery" => \$query,
	  "S=s" => \$match_string, "string" => \$match_string,
	  "w=s" => \$warning, "warning=s" => \$warning,
	  "c=s" => \$critical, "critical=s" => \$critical);

# Just in case of problems, let's not hang Nagios
$SIG{'ALRM'} = sub {
	nexit("UNKNOWN", "Plugin timed out.");
};
alarm($timeout);

# Arguments..
if ($opt_h) {
	print_help();
	exit $ERRORS{'OK'};
}

if (! (defined($hostname) && defined($user) && defined($password))) {
	nexit("UNKNOWN", "Missing host, user or password");
}

if ((! (defined($instance))) && (! (defined($port)))) {
               $port = 1433;
}

if(defined($warning)){
	verify_threshold($warning);
	$warn_range = Nagios::Plugin::Range->parse_range_string($warning);
}
if(defined($critical)){
	verify_threshold($critical);
	$crit_range = Nagios::Plugin::Range->parse_range_string($critical);
}

my ($tmpfile, $tmpfilename) = mkstemp("/tmp/$hostname.XXXXX");

if (defined($query) && defined($online)) {
	nexit("UNKNOWN", "online and query cannot be used together.");
}

if (defined($query)) {
	if (defined($database)) {
		$query = "use $database; " . $query;
	}
} elsif (defined($online)) {
	if (! defined($database)) {
		nexit("UNKNOWN", "No database parameter supplied");
	}
	$query = 'use master; select databasepropertyex(\'' . $database . '\', \'Status\')';
} else {
	nexit("UNKNOWN", "online or query is required.");
}
$query .= "\ngo\n";

## Main code below ##

print $tmpfile $query;
close($tmpfile);
my($errorfile) = mktemp("/tmp/$hostname.err.XXXXXX");
my($resultfile) = mktemp("/tmp/$hostname.res.XXXXXX");

my $tsqlcmd = `which tsql 2>/dev/null`;
chomp($tsqlcmd);
if (! $tsqlcmd) {
	nexit("UNKNOWN", "Could not find tsql-executable.");
}

my($instfile, $instfilename) = mkstemp("/tmp/$hostname.inst.XXXXXX");
my $instStr = "[op5-testcase]\n";
$instStr .= "  host = $hostname\n";
$instStr .= "  port = $port\n";
if($instance){
	$instStr .= "  instance = $instance\n";
}
$instStr .= "  tds version = $tdsversion\n";
print $instfile $instStr;
close($instfile);
if($verbose){
	print "\nDEBUG:\n";
	print "tsqlcmd: $tsqlcmd -S op5-testcase -I $instfilename -U '$user' -P '$password' < $tmpfilename 2>$errorfile > $resultfile\n";
}
`$tsqlcmd -S op5-testcase -I $instfilename -U '$user' -P '$password' < $tmpfilename 2>$errorfile > $resultfile`;

my ($row, $fh, $i);
$i = 0;
open($fh, $errorfile) || nexit("UNKNOWN", "Could not open error file for reading.");
while ($row = <$fh>) {
	if ($row =~ "Login failed for user") {
		nexit("UNKNOWN", "Could not connect, login failed.");
	} elsif ($row =~ "There was a problem connecting to the server") {
		nexit("UNKNOWN", "Could not connect, incorrect server name or SQL service not running.");
	}
}
close($fh);
if ($i) {
	nexit("UNKNOWN", "Unknown error returned from server.");
}
open($fh, $resultfile) || nexit("UNKNOWN", "Could not open result file for reading.");
my (@rows);
while ($row = <$fh>) {
	if (($row !~ "^locale") && ($row !~ "^using") && ($row !~ "^[0-9]>")) {
		push(@rows, $row);
	}
}
close($fh);

if (defined($online)) {
	foreach $row (@rows) {
		if ($row =~ "ONLINE") {
		  nexit("OK", "Database $database is online. |online=1");
		}
	}
	nexit("CRITICAL", "Database $database is offline |online=0");
} elsif (defined($match_string)) {
	foreach $row (@rows) {
		$row = trim($row);
		if ($row =~ "$match_string") {
			nexit("OK", "The string $match_string was found in resultset. |match_found=1");
		}
	}
	nexit("CRITICAL", "The string $match_string was not found in resultset. |match_found=0");
} else {
	# Try to find a number in result
	foreach $row (@rows) {
		if ($row =~ /[^\d]*(\d+)[^\d]*/) {
			my $exit_code;
			if($crit_range->check_range($1)){
				$exit_code = "CRITICAL";
			} elsif($warn_range->check_range($1)){
				$exit_code = "WARNING";
			} else {
				$exit_code = "OK";
			}
			my $perf_data = sprintf("|nr_rows=%d;%d;%d", $1, $warning, $critical);
			nexit($exit_code, "Query returned $1 rows. $perf_data");
		}
	}
}
nexit("UNKNOWN", "Could not interpret server response.");

## Subs below ##

sub nexit ($$) {
	my ($exit_val, $status_text) = @_;
	if (defined ($tmpfilename)) {
		if($verbose){
			print "\nCommand file content:\n";
			open(TMPFILE, $tmpfilename);
			@lines = <TMPFILE>;
			close(INFO);
			print @lines;
		}
		unlink($tmpfilename);
	}
	if (defined ($resultfile)) {
		if($verbose){
			print "Result file content:\n";
			open(TMPFILE, $resultfile);
			@lines = <TMPFILE>;
			close(INFO);
		}
		print @lines;
		unlink($resultfile);
	}
	if (defined ($errorfile)) {
		if($verbose){
			print "\nError file content:\n";
			open(TMPFILE, $errorfile);
			@lines = <TMPFILE>;
			close(INFO);
			print @lines;
		}
		unlink($errorfile);
	}
	if (defined ($instfilename)) {
		if($verbose){
			print "\nInstance file content:\n";
			open(TMPFILE, $instfilename);
			@lines = <TMPFILE>;
			close(INFO);
			print @lines;
		}
	  unlink($instfilename);
	}
	print("$exit_val - $status_text\n");
	exit $ERRORS{$exit_val};
}

sub print_help () {
	print "Usage: check_mssql.pl -H <host> -U <user> -P <password> [-p <port>] [-t <timeout>] [-D <dbname>]\n";
	print "                      [-o] [-Q <sqlquery>] [-S <string> | [-w <warn_range> [-c <crit_range>]]\n";
	print "Options:\n";
	print "\t<host> = The address of the host running SQLServer\n";
	print "\t<user> = The user to log in as, if a domain is specified the name has to be embraced by \' signs\n";
	print "\t<password> = The user\'s password\n";
	print "\t<port> = The port on which the SQL Server is listening, default 1433\n";
	print "\t<timeout> = Timeout in seconds for plugin execution, default 10\n";
	print "\t<dbname> = The name of the database to use\n";
	print "\t-o or --online = Check if database is online (databasepropertyex('<dbname>', 'STATUS') equals ONLINE).\n";
	print "\t<sqlquery> = The SQL query to run on the server, the default is to check the number of logged in users\n";
	print "\t<string> = A string to look for in the result set\n";
	print "\t<warn_range> = The warning limit for the result of the query, default 50\n";
	print "\t<crit_range> = The critical limit for the result of the query, default 100\n";
	print "\t  Warning and critical threshold support ranges on the form <start>:<end> which\n";
	print "\t  defines the range that should _not_ trigger an alarm. A single numeric threshold\n";
	print "\t  is equal to a range 0 to the thresh. IE -w 50 is equal to -w 0:50 which means\n";
	print "\t  trigger alarm if returned value is outside range, IE larger then 50\n";
	print "Instead of the short argument names shown above the following can be used:\n";
	print "\t-H\t--hostname\n";
	print "\t-U\t--user\n";
	print "\t-P\t--password\n";
	print "\t-p\t--port\n";
	print "\t-t\t--timeout\n";
	print "\t-D\t--database\n";
	print "\t-o\t--online\n";
	print "\t-Q\t--sqlquery\n";
	print "\t-S\t--string\n";
	print "\t-w\t--warning\n";
	print "\t-c\t--critical\n";
	print "\n";
	print "Usage examples:\n";
	print "\n";
	print "To check that Northwind database is ONLINE:\n";
	print "check_mssql.sh -H localhost -U name -P pass -D Northwind -o\n";
	print "\n";
	print "Select number of messages from Northwind.messages, warn if > 10, crit if > 15\n";
	print "check_mssql.sh -H localhost -U name -P pass -D Northwind -Q \"select count(id) from messages\" -w 10 -c 15\n";
	print "\n";
}



sub verify_threshold($){
	my $thres = shift;

	if($thres =~ /^\d+\:?\d*$/ ) {
		return;
	}
	if($thres =~ /^\d*\:?\d+$/ ){
		return;
	}
	if($thres =~ /^\~[:]\d+$/ ){
		return;
	}
	nexit("UNKNOWN", "Failed to interpret threshold(s).");
}

# Trim leading and trailing spaces from string
sub trim($) {
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}
