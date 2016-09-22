#!/usr/bin/perl -w
#
# License: GPL
# Copyright (c) 2008 op5 AB
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
sub version();
sub trim($);
sub get_auth();
sub my_die($);

my %EXIT_CODE = (
	'OK', 0,
    'WARNING', 1,
    'CRITICAL', 2,
    'UNKNOWN', 3);


# Default values for resulting string and exit code
my $result_string="Unknown error";
my $perfdata = "";
my $exit_code = $EXIT_CODE{'UNKNOWN'};


my $PROGNAME = "check_sitescanner";
my $TIMEOUT = 10;
my $VERSION = "1.0.1";


my $WGET="/usr/bin/wget";
my ($opt_h, $opt_V, $opt_c, $opt_w, $opt_t, $res, $opt_H, $opt_U, $opt_P, $opt_S, $opt_u, $opt_a);



Getopt::Long::Configure("bundling");
$res=GetOptions(
    "h"   => \$opt_h, "help"       => \$opt_h,
	"H=s" => \$opt_H, "host=s"     => \$opt_H,
	"V"   => \$opt_V, "version"    => \$opt_V,
	"u=s" => \$opt_u, "url=s"      => \$opt_u,
	"U=s" => \$opt_U, "user=s"     => \$opt_U,
	"P=s" => \$opt_P, "password=s" => \$opt_P,
	"S=s" => \$opt_S, "sensor=s"   => \$opt_S,
	"a=s" => \$opt_a, "authfile=s" => \$opt_a,
    "t=f" => \$opt_t, "timeout=f"  => \$opt_t);


if ( ! $res ) {
    exit $EXIT_CODE{'UNKNOWN'};
}

# Set alarmclock
if($opt_t) {
    $TIMEOUT = $opt_t;
}
# Just in case of problems, let's not hang Nagios
$SIG{'ALRM'} = sub {
    print ("ERROR: $PROGNAME timed out after $TIMEOUT seconds\n");
    exit $EXIT_CODE{'UNKNOWN'};
};
alarm($TIMEOUT);

if($opt_h){
    help();
    exit $EXIT_CODE{'UNKNOWN'};
}
if($opt_V){
    version();
    exit $EXIT_CODE{'UNKNOWN'};
}

# Check that wget exist and is executable
if( ! -x $WGET){
    print "File '$WGET' do not exist or is not executable.\n";
    exit $EXIT_CODE{'UNKNOWN'};
}
# Check that we have hostname
if(!$opt_H){
	print "Missing hostname. Execute $PROGNAME --help for usage instructions\n";
	exit $EXIT_CODE{'UNKNOWN'};
}
# Check that we have url
if(!$opt_u){
	print "Missing URL. Execute $PROGNAME --help for usage instructions\n";
	exit $EXIT_CODE{'UNKNOWN'};
}

# If we have a authfile, use it.
if($opt_a){
	get_auth();
}

# Check that we have usename and password
if(!$opt_U || !$opt_P){
	print "Missing username and/or password. Execute $PROGNAME --help for usage instructions\n";
	exit $EXIT_CODE{'UNKNOWN'};
}

# Check that we have usename and password
if(!$opt_S){
	print "Missing sensor id. Execute $PROGNAME --help for usage instructions\n";
	exit $EXIT_CODE{'UNKNOWN'};
}

# Build the string wget needs to fetch data

my $wget_string = $opt_H . "/" . $opt_u . "?login=" . $opt_U . "&password=" . $opt_P . "&sensorid=" . $opt_S;

# Execute wget. This is where it all happens...
my $status_string = `$WGET -q -O - \"$wget_string\"`;

# Check that wget was successfull
if($? != 0){
    print "Error when executing supporting tool wget\n";
    exit $EXIT_CODE{'UNKNOWN'};
}


# Make array from wget result string
# [0] -> result string
# [1] -> perfdata
# [2] -> exit code
my @res_arr = split(/\|/, $status_string);

if(defined($res_arr[0])){
	$result_string = $res_arr[0];
}
if(defined($res_arr[1])){
	$res_arr[1]=trim($res_arr[1]);
	if($res_arr[1] =~ /^\d+$/) {
		$res_arr[1] = $res_arr[1] / 1000;
	}
	$perfdata = "|rta=$res_arr[1]";
}
# Set exit code (if numeric and between 0 and 3)
if(defined($res_arr[2])){
	$res_arr[2]=trim($res_arr[2]);
	if($res_arr[2] =~ /^\d+$/) {
		if($res_arr[2] >= 0 && $res_arr[2] <= 3){
			$exit_code = $res_arr[2];
		}
	}
}

# Print result and exit
print $result_string . $perfdata . "\n";
exit($exit_code);


####################################################
# Main code end here, only functions/helpers below #
####################################################

# Usage
sub help(){
	print "\n";
    print "$PROGNAME checks a Sitescanner sensor and reports back current status.\n\n";
    print "Usage:\n";
    print "   $PROGNAME -H <host> -u <url> -S <sensor_id> -t <timeout>\n";
	print "                     [-U <username> -P <password> | -a <authfile>]\n";
    print " Where:\n";
    print "  -H, --host\n";
	print "     The name of the host providing the simplified sensor status interface.\n";
	print "     FQDN or IP-address (For example: webservice.sitescanner.net)\n";
    print "  -u, -url\n";
	print "     Path to the getstatus script. IE the part after the FQDN \n";
	print "     (getstatus.asp in the url webservice.sitescanner.net/getstatus.asp)\n";
	print "  -S, --sensorid\n";
	print "     The sensor to fetch data for\n";
	print "  -U, --username\n";
	print "     The username.\n";
	print "  -P, --password\n";
	print "     The password\n";
	print "  -a, --authfile\n";
	print "     A file containing username/password. Used to hide credentials. Format:\n";
	print "     username=<username>\n";
	print "     password=<password>\n";
    print "  -t, --timeout\n";
	print "     The timeout (in seconds). Default timeout = " . $TIMEOUT . "s\n";
	print "\n";
	print "Example of how to test from commandline:\n";
	print "#> /opt/plugins/check_sitescanner -H webservice.sitescanner.net -u getstatus.asp -U myuser -P mypassword -S 12345\n";
	print "\n";
}

sub version(){
	print "$PROGNAME v$VERSION\n";
}
# Trim leading and trailing spaces from string
sub trim($) {
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}

# Parse authfile and set username/password
sub get_auth(){
	if($opt_a){
		if(! -e $opt_a){
			print "Auth-file '$opt_a' not found\n";
			exit $EXIT_CODE{"UNKNOWN"};
		}
		open (AUTH_FILE, $opt_a) || my_die "Unable to open auth file\n";
		while( <AUTH_FILE> ) {
			if(s/^[ \t]*username[ \t]*=//){
				$opt_U = trim($_);
			}
			if(s/^[ \t]*password[ \t]*=//){
				$opt_P = trim($_);
			}
		}
	}
}

# Custom 'die' function. Used to get nice output when failing to open files
sub my_die($) {
	my $error = shift;
	print $error;
	exit $EXIT_CODE{'UNKNOWN'};
}
