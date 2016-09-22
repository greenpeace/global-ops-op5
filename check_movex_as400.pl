#!/usr/bin/perl
#
# License: GPL
# Copyright (c) 2007 op5 AB
# Author: Peter Ostlin <peter@op5.com
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
use warnings;
# use lib "/usr/lib/perl5/site_perl/5.8.3/i386-linux-thread-multi/";

# use lib "/root/movex/";
use lib "/opt/plugins/";
# use Net::Telnet;
# use Net::Telnet::Options;
use Time::Local 'timelocal_nocheck';
use Term::VT102;
use Expect;
use IO::Stty;
use Getopt::Long;
use utils qw ($TIMEOUT %ERRORS &print_revision &support);
use Switch;

# Helpers
sub trim($);
sub reader();
sub print_log ($);
sub print_help ();
sub print_usage ();
sub print_rev ();
sub my_die($);
sub get_timestamp($);
sub timeToSec($);
sub timeFormat($);
sub timesDiff($$$);
sub secToHuman($);
sub check_LINK_TIME_DIFF();
sub check_ODS_TIME_DIFF();
sub check_ODS_STATUS();
sub check_INACT_OBJS();
sub login();
sub logoff();
sub test(); # just for testing.
# Global vars
my $PROGNAME    = "check_movex_os400";
my $PROGVERSION = "0.0.1";
my $LOGFILE = "/tmp/mylog.txt";
my $SCREENDUMP = "/tmp/screen.out";
my $DEFAULTPORT = 23;
my $DEBUG = 1;
my $command_timeout = 5;
my $ODSDEFAULTSTATUS = "NORMAL";
my $error_msg;
my $USDATE = 1; # If date: mm-dd-yy set to 0 if yy-mm-dd

my $vt;
my $spawn;
my $i;
my $mystr;
# TMP variables
my $res; # result
my @resArr; # The return array holding all telnet output
my $F12 = chr(27) .chr(91) .chr(50) .chr(52) .chr(126); # F12 = Cancel, takes you back to main menu
my $F5 = chr(27) .chr(91) .chr(49) .chr(53) .chr(126); # F5 = Refresh on many screens
my $PGDWN = chr(27) . chr(91) . chr(54) . chr(126);  # PGDWN key
my $SIGNOFF = "signoff endcnn(*yes)\r\n";

my ($opt_h, $opt_V, $opt_t, $opt_v, $opt_H, $opt_p, $opt_o, $opt_u, $opt_P, $opt_w, $opt_c, $opt_l, $opt_e);


# Fetch the commandline arguments
Getopt::Long::Configure("bundling");
$res=GetOptions(
            "h"   => \$opt_h, "help"       => \$opt_h,
            "V"   => \$opt_V, "VERSION"    => \$opt_V,
            "t=f" => \$opt_t, "timeout=f"  => \$opt_t,
            "v"   => \$opt_v, "verbose"    => \$opt_v,
            "H=s" => \$opt_H, "host"       => \$opt_H,
            "l=s" => \$opt_l, "link"       => \$opt_l,
            "e=s" => \$opt_e, "expect"     => \$opt_e,
            "w=s" => \$opt_w, "warning"    => \$opt_w,
            "c=s" => \$opt_c, "critical"   => \$opt_c,
            "p=s" => \$opt_p, "password"   => \$opt_p,
            "u=s" => \$opt_u, "user"       => \$opt_u,
            "P=f" => \$opt_P, "port"       => \$opt_P,
            "o=s" => \$opt_o, "option"     => \$opt_o);

# ..and bail if it fails.
if ( ! $res ) {
    print "Error when parsing arguments\n";
    exit $ERRORS{"UNKNOWN"};
}

# Set alarmclock
if($opt_t) {
    $TIMEOUT = $opt_t;
}
# Just in case of problems, let's not hang Nagios
$SIG{'ALRM'} = sub {
    logoff();
    print ("ERROR: $PROGNAME timed out after $TIMEOUT seconds\n");
    exit $ERRORS{"UNKNOWN"};
};
alarm($TIMEOUT);

# Check if debug enabled
if($opt_v){
    $DEBUG=1;
}

# Print help or version info if requested
if ($opt_V) {
    print_rev();
    exit $ERRORS{"OK"};
}
if ($opt_h) {
    print_usage();
    exit $ERRORS{"OK"};
}

if($opt_w && !timeFormat($opt_w)){
    print "Wrong warning treshold '$opt_w'\n";
    exit $ERRORS{'UNKNOWN'};
}
if($opt_c && !timeFormat($opt_c)){
    print "Wrong critical treshold '$opt_c'\n";
    exit $ERRORS{'UNKNOWN'};
}
unless($opt_e){
    $opt_e = $ODSDEFAULTSTATUS;
}


# Check for required variables
unless($opt_H) {
    print "Missing hostname/address\n";
    exit $ERRORS{"UNKNOWN"};
}
unless($opt_u && $opt_p){
    print "Missing username or password\n";
    exit $ERRORS{"UNKNOWN"};
}
unless($opt_P){
    $opt_P = $DEFAULTPORT;
}



my $shucks;
# This function traps WINCH signals and passes them on
sub winch {
    my $signame = shift;
    my $pid = $spawn->pid;

    $shucks++;
 #   print "count $shucks,pid $pid, SIG$signame\n";
    $spawn->slave->clone_winsize_from(\*STDIN);
    $spawn->slave->stty(qw(raw -echo));
    kill WINCH => $spawn->pid if $spawn->pid;
}
# $SIG{WINCH} = \&winch;  # best strategy



# reader();
# test();
# exit(1);

# Main loop, switch on option.
if($opt_o){
    switch ($opt_o){
	case "LINK_TIME_DIFF" {
	    unless($opt_l){
		print "Option LINK_TIME_DIFF require a link argument\n";
		exit $ERRORS{'UNKNOWN'};
	    }
	    $res = login();
	    if(!$res){
		print $error_msg . "\n";
		exit $ERRORS{'CRITICAL'};
	    }
	    check_LINK_TIME_DIFF();
	    logoff();
	}
	case "INACT_OBJS" {
	    unless($opt_l){
		print "Option INACT_OBJS require a link argument\n";
		exit $ERRORS{'UNKNOWN'};
	    }
	    $res = login();
	    if(!$res){
		print $error_msg . "\n";
		exit $ERRORS{'CRITICAL'};
	    }
	    check_INACT_OBJS();
	    logoff();
	}
	case "ODS_TIME_DIFF" {
	    $res = login();
	    if(!$res){
		print $error_msg . "\n";
		exit $ERRORS{'CRITICAL'};
	    }
	    check_ODS_TIME_DIFF();
	    logoff();
	}
	case "ODS_STATUS" {
	    $res = login();
	    if(!$res){
		print $error_msg . "\n";
		exit $ERRORS{'CRITICAL'};
	    }
	    check_ODS_STATUS();
	    logoff();
	}
	case "LOGIN" {
	    $res = login();
	    if($res){
		print "Login ok\n";
		$spawn->clear_accum();
#		$spawn->interact();
		logoff();
		exit $ERRORS{'OK'};
	    } else {
		print $error_msg . "\n";
		exit $ERRORS{'CRITICAL'};
	    }
	}
	default {
	    print "No matching option\n";
	    exit $ERRORS{'UNKNOWN'};
	}
    }

} else {
    print "No option specified\n";
    exit $ERRORS{'UNKNOWN'};
}

# $spawn->interact();
# Fallback, should not happen.
print "Unknown error\n";
exit $ERRORS{'UNKNOWN'};



# PGDWN = more

$Expect::Log_Stdout = 0;
# use IO::Pty;
# $Expect::Exp_Internal = 1;

# $spawn->raw_pty(0);

# Helper that dump whats on the screen in readable format
sub dump_screen(){
    open(MYOUTFILE, ">>$SCREENDUMP");
    $vt->process ($spawn->before) if (defined $spawn->before);
    $i=0;

    while($i < $vt->rows()){
	if($vt->row_plaintext($i)){
	    print MYOUTFILE "$i: '" . $vt->row_plaintext($i) . "'\n";
#	print $vt->row_plaintext($i);
	}
	$i++;
    }
}


# Check the 'System Status' page using the ods400 command. Return
# ok if status equals $opt_e (NORMAL by default), critical if not.
sub check_ODS_STATUS(){
#    if(!$opt_e){
#	$opt_e = "NORMAL";
#    }
    $spawn->send("ods400\r\n");
    my $link = $opt_l;
    $res = $spawn->expect(4, "Vision Solutions" );
    #    dump_screen();
    $vt->process ($spawn->before) if (defined $spawn->before);

    if(!$res){
	print "Error! Faild to execute command 'ods400'. (" . $vt->row_plaintext($vt->rows()-1)  . ")\n";
	logoff();
	exit $ERRORS{'CRITICAL'};
    }
    my $i=1;
    my $selection;
    # Make sure we have the right screen and find the row and id of the
    # ODS/400 system Status command.
#    dump_screen();
    while($i < $vt->rows()){
	if($vt->row_plaintext($i) =~ m/.*(\d).*ODS\/400 System Status/){
	    $selection = $1;
	    last;
	}
	$i++;
    }
    # The command was not found. Exit.
    unless($selection){
	print "Error! Failed to execute command 'ods400'.\n";
	logoff();
	exit $ERRORS{'CRITICAL'};
    }

    # Send 'selection' to take us to the 'System Status' screen
    $spawn->send("$selection\r\n");
    $res = $spawn->expect(4, "System Status" );
    if(!$res){
	print "Error! Failed to execute command 'ods400'.\n";
	logoff();
	exit $ERRORS{'CRITICAL'};
    }
    $vt->process ($spawn->before) if (defined $spawn->before);
#    dump_screen();
    $spawn->send("$F5");
    $res = $spawn->expect(4, "Vision Solutions" );
    $vt->process ($spawn->before) if (defined $spawn->before);
    # code above identical to check_ODS_TIME_DIFF.
    $i=1;
    logoff();
    # We are on the correct screen, loop through it to find the status
    # and compare it to $opt_e
    while($i < $vt->rows()){
	if($vt->row_plaintext($i) =~ /.*Status:(.*)System:.*/){
	    if(trim($1) eq $opt_e){
		print "OK - ODS System status is '" . trim($1) . "'\n";
		exit $ERRORS{'OK'};
	    } else {
		print "CRITICAL - ODS System status is '" . trim($1) . "'\n";
		exit $ERRORS{'CRITICAL'};
	    }
	}
	$i++;
    }
    print "Unknown - Failed to fetch ODS system Status\n";
    exit $ERRORS{'UNKNOWN'};
}


# Check the 'System Status' page using the ods400 command.
# check all date/time's and compare them to system date/time.
sub check_ODS_TIME_DIFF(){

    $spawn->send("ods400\r\n");
    my $link = $opt_l;
    $res = $spawn->expect(4, "Vision Solutions" );
    #    dump_screen();
    $vt->process ($spawn->before) if (defined $spawn->before);

    if(!$res){
	print "Error! Faild to execute command 'ods400'. (" . $vt->row_plaintext($vt->rows()-1)  . ")\n";
	logoff();
	exit $ERRORS{'CRITICAL'};
    }
    my $i=1;
    my $selection;
    # Make sure we have the right screen and find the row and id of the
    # ODS/400 system Status command.
#    dump_screen();
    while($i < $vt->rows()){
	if($vt->row_plaintext($i) =~ m/.*(\d).*ODS\/400 System Status/){
	    $selection = $1;
	    last;
	}
	$i++;
    }
    # Command not found. Exit.
    unless($selection){
	print "Error! Failed to execute command 'ods400'.\n";
	logoff();
	exit $ERRORS{'CRITICAL'};
    }

    # Send 'selection' to take us to the 'System Status' screen
    $spawn->send("$selection\r\n");
    $res = $spawn->expect(4, "System Status" );
    if(!$res){
	print "Error! Failed to execute command 'ods400'.\n";
	logoff();
	exit $ERRORS{'CRITICAL'};
    }
    $vt->process ($spawn->before) if (defined $spawn->before);
#    dump_screen();
    $spawn->send("$F5");
    $res = $spawn->expect(4, "Vision Solutions" );
    $vt->process ($spawn->before) if (defined $spawn->before);
#    dump_screen();
    $i=1;
    my $current_time;
    my %list = ();
    my $j =0;
    while($i < $vt->rows() && $j<100){
	# Find and store 'system time'
	if($vt->row_plaintext($i) =~ /.*Date:[ ]+([0-9\/]+).*Time:[ ]+([0-9:]+).*/){
	    $current_time = get_timestamp("$1 $2");
	}
	# Find and store the time in a list.
	if($vt->row_plaintext($i) =~ /([A-Za-z\/ 0-9_]{2,15}).*([0-9\/]{7,}) +([0-9:]{7,})/){
	    my $time = get_timestamp("$2 $3");
#	    print "adding to list,  $1, $2, $3..\n";
	    $list{trim($1)} = $time;
	}
	# 'More...' found. We are at the end of the page but there is more to see.
	# Send PGDWN to continue looping throuh the entries on the next page.
	if($vt->row_plaintext($i) =~ /More\.\.\./){
	    $spawn->send("$PGDWN");
	    $res = $spawn->expect(4, "Vision Solutions" );
	    $vt->process ($spawn->before) if (defined $spawn->before);
	    dump_screen();
	    $i=1;
	}
	$i++;
	$j++;
    }
#    print "current time: $current_time\n";
    my $critLinks = "";
    my $warnLinks = "";
    # Check all timestamps against warning/critical treshold.
    for my $key ( keys %list ) {
	my $value = $list{$key};
	if($opt_c){
	    if($res = timesDiff($current_time, $value, timeToSec($opt_c))){
		$critLinks .= $key . ", ";
	    }
	}
	if($opt_w){
	    if($res = timesDiff($current_time, $value, timeToSec($opt_w))){
		$warnLinks .= $key . ", ";
	    }
	}
    }
    logoff();
    # Return appropriate status.
    if($critLinks){
	$critLinks =~ s/, $//;
	print "Critical. Time diff's for: '$critLinks' are outside critical treshold '$opt_c'.\n";
	exit $ERRORS{'CRITICAL'};
    }
    if($warnLinks){
	$warnLinks =~ s/, $//;
	print "Warning. Time diff's for: '$warnLinks' are outside warning treshold '$opt_w'.\n";
	exit $ERRORS{'WARNING'};
    }
    print "OK. Time diff's are ok for all processes.\n";
    exit $ERRORS{'OK'};

}

# Check the 'System Activity Display' for specified link. Report on anything
# in the 'Inact Objs' column. If it's empty return ok, if not return critical
# Using the oms400 command.
sub check_INACT_OBJS(){

    $spawn->send("oms400\r\n");
    my $link = $opt_l;
    $res = $spawn->expect(4, "Vision Solutions" );
    $vt->process ($spawn->before) if (defined $spawn->before);

    if(!$res){
	print "Error! Faild to execute command 'oms400'. (" . $vt->row_plaintext($vt->rows()-1)  . ")\n";
	logoff();
	exit $ERRORS{'CRITICAL'};
    }

    my $i=1;
    my $num_tabs;
    # Make sure we have the right screen and take position
    # just over the link table.
    while(!($vt->row_plaintext($i) =~ m/Link ID/) ){
	$i++;
	if($vt->rows() <= $i){
	    # We seam to be lost. Exit
	    print "Error! Failed to execute command 'oms400'. Link $link not found\n";
	    logoff();
	    exit $ERRORS{'CRITICAL'};
	}
    }
    $i++;
    # Loop the links until we find the specified one.
    while(!($vt->row_plaintext($i) =~ m/($link)/)  ){
	$i++;
	# Keep the cursor moving so that we end up on the right row.
	$spawn->send("\t");
	if($vt->rows() <= $i){
	    print "Error! Failed to execute command 'oms400'. Link $link not found\n";
	    logoff();
	    exit $ERRORS{'CRITICAL'};
	}
    }
    # We are on the right row. Send 8\r\n the take us to the
    # 'System Activity Display' of the wanted link.
    $spawn->send("8\r\n");

    $res = $spawn->expect(4, "F3=Exit" );
    # Code above identical to check_LINK_TIME_DIFF. Make function....

    $spawn->send($F5);
    $res = $spawn->expect(4, "F3=Exit" );
    $vt->process ($spawn->before) if (defined $spawn->before);
    dump_screen();
    $i = 1;
    logoff();
    # Now on the correct screen, loop the rows to find Inact objs:
    while($i < $vt->rows){
	$_ = trim($vt->row_plaintext($i));

#	if($_ =~ /.*Inact Objs:(.*)Time:.*/){ # For testing, makes if match an inact obj
	if($_ =~ /.*Inact Objs:(.*)Elapsed Time:.*/){
	    if(trim($1) eq ""){
		print "OK - Link '$link' reports no Inactive objects\n";
		exit $ERRORS{'OK'};
	    } else {
		print "Critical - Link '$link' reports Inactive objects: '" . trim($1) . "'\n";
		exit $ERRORS{'CRITICAL'};
	    }
	}
	$i++;
    }
    print "UNKNOWN - Failed to lookup Inactive objects.\n";
    exit $ERRORS{'UNKNOWN'};
}

# Check the 'System Activity Display' for specified link.
# Compare all date/times agains 'system' time.
# Using the oms400 command.
sub check_LINK_TIME_DIFF(){

    $spawn->send("oms400\r\n");
    my $link = $opt_l;
    $res = $spawn->expect(4, "Vision Solutions" );
#    dump_screen();
    $vt->process ($spawn->before) if (defined $spawn->before);

    if(!$res){
	print "Error! Faild to execute command 'oms400'. (" . $vt->row_plaintext($vt->rows()-1)  . ")\n";
	logoff();
	exit $ERRORS{'CRITICAL'};
    }

    my $i=1;
    my $num_tabs;
    # Make sure we have the right screen and take position
    # just over the link table.
    while(!($vt->row_plaintext($i) =~ m/Link ID/) ){
	$i++;
	if($vt->rows() <= $i){
	    # We seam to be lost. Exit
	    print "Error! Failed to execute command 'oms400'. Link $link not found\n";
	    logoff();
	    exit $ERRORS{'CRITICAL'};
	}
    }

    $i++;
    # Loop the links until we find the one we want
    while(!($vt->row_plaintext($i) =~ m/($link)/)  ){
	$i++;
	# Keep the cursor moving so that we end up on the right row.
	$spawn->send("\t");
	if($vt->rows() <= $i){
	    print "Error! Failed to execute command 'oms400'. Link $link not found\n";
	    logoff();
	    exit $ERRORS{'CRITICAL'};
	}
    }

    # We are on the right row. Send 8\r\n the take us to the
    # 'System Activity Display' of the wanted link.
    $spawn->send("8\r\n");
#    sleep(4);
    $res = $spawn->expect(4, "F3=Exit" );
    $i=1;

    # Fetch the current time from top row.
    my $currentdate;
    my $current_time;
    $vt->process ($spawn->before) if (defined $spawn->before);
    while($i < $vt->rows && !$currentdate){
	if($vt->row_plaintext($i) && $vt->row_plaintext($i) =~ m/Date/ ){
#	    print $vt->row_plaintext($i) . "\n";
	    $currentdate=$vt->row_plaintext($i);
	    if($currentdate =~ /[ A-Za-z]+([0-9\/]+)[ :A-Za-z]+([0-9:]+).*/){
		$current_time = get_timestamp("$1 $2");
	    }
	}
	$i++;
    }
#    dump_screen();

    $spawn->send($F5);
#    sleep(3);
    # Double expect since the page needs to generate statistics.
    $res = $spawn->expect(4, "F3=Exit" );
    $vt->process ($spawn->before) if (defined $spawn->before);
    $i=1;
    my %list = ();
    # Parse the links, find time string and convert it to timestamp.
    while($i < $vt->rows){
	$_ = trim($vt->row_plaintext($i));
	if($_ =~ /([A-Za-z\/ 0-9]{2,15}).*([0-9\/]{7,}) +([0-9:]{7,})/){
	    my $time = get_timestamp($2 . " " . $3);
	    $list{trim($1)} = $time;
	}
	$i++;
    }
    my $critLinks = "";
    my $warnLinks = "";
    # Check all timestamps against warning/critical treshold.
    for my $key ( keys %list ) {
	my $value = $list{$key};
	if($opt_c){
	    if($res = timesDiff($current_time, $value, timeToSec($opt_c))){
		$critLinks .= $key . ", ";
	    }
	}
	if($opt_w){
	    if($res = timesDiff($current_time, $value, timeToSec($opt_w))){
		$warnLinks .= $key . ", ";
	    }
	}
    }
    logoff();
    if($critLinks){
	$critLinks =~ s/, $//;
	print "Critical. Time diff's for: '$critLinks' are outside critical treshold '$opt_c'.\n";
	exit $ERRORS{'CRITICAL'};
    }
    if($warnLinks){
	$warnLinks =~ s/, $//;
	print "Warning. Time diff's for: '$warnLinks' are outside warning treshold '$opt_w'.\n";
	exit $ERRORS{'WARNING'};
    }
    print "OK. Time diff's are ok for all systems.\n";
    exit $ERRORS{'OK'};
}


# End the telnet session. Lots of 'F12' (cancel) to get back to main menu.
sub logoff(){
    $spawn->send("$F12");
    $spawn->send("$F12");
    $spawn->send("$F12");
    $spawn->send("$F12");
#    $spawn->interact();
    $res = $spawn->expect(2, "===>" );
    $spawn->send($SIGNOFF);
}


# Telnet ligin routine.
# Return 1 (true) if login was sucessfull and 0 if it failed.
sub login(){
    my $tmp_res;
    $Expect::Log_Stdout = 0;
    # Use Term:VT102 to make remote host  output readable
    $vt = Term::VT102->new ('cols' => 80, 'rows' => 25, );
    # Convert linefeeds to linefeed + carriage return.
    $vt->option_set ('LFTOCRLF', 1);
    # Make sure line wrapping is switched on.
    $vt->option_set ('LINEWRAP', 1);

    $spawn = new Expect;
    $SIG{WINCH} = \&winch;  # best strategy

    $spawn=Expect->spawn("telnet $opt_H");
    $spawn->debug(0);

    $spawn->slave->stty(qw(raw -echo));
#    $spawn->log_file("autossh.log");

    # Wait for login screen, then send username/password.
    $spawn->expect($command_timeout,"Password");
    $spawn->clear_accum();
    $spawn->send("$opt_u\t");
    $spawn->send("$opt_p\r\n");
#    $spawn->clear_accum();

    # Wait for MAIN window
    $tmp_res = $spawn->expect($command_timeout, "===>" );

    $spawn->clear_accum();
    $vt->process ($spawn->before) if (defined $spawn->before);

    if($tmp_res){
	return 1;
    } else {
	if(trim($vt->row_plaintext($vt->rows()-1)) =~ "" ){
	    $error_msg = "Error. Login failed";
	    $i=1;
	    while($i < $vt->rows()){
		if($vt->row_plaintext($i) =~ /Message/){
		    $error_msg = "Error: " . trim($vt->row_plaintext($i));
		    $spawn->send("\n");
#		    $spawn->interact();
		    logoff();
		}
		$i++;
	    }
	} else {
	    $error_msg = "Error: " . trim($vt->row_plaintext($vt->rows()-1));
	}
	return 0;
    }
}


## TMP exit...
# login();



# This gets the size of your terminal window
# $spawn->slave->clone_winsize_from(\*STDIN);

# my $PROMPT;




sub print_log($){
    my $toprint = shift;
    open(LOGFILE,">>$LOGFILE") || die("Cannot Open File");
    print LOGFILE $toprint . "\n";
    close(LOGFILE);
}



# Convert num seconds to human readable form:
# 'xd, xh, xm, xs'
sub secToHuman($){
    my $sec = shift;
    my $resStr;
    if($sec < 0 || $sec > 60*60*24*10000){
	my_die("Internal problem. Function 'secToHuman' is feed strange numbers");
    }
    print "sec: $sec\n";
    my ($seconds, $minutes, $hours, $days) = gmtime($sec);
    $days -= 1;
    if($sec >= 60*60*24){
	use integer;
	$days = $sec / (60*60*24);
	$resStr = $days . "d, ";
	print "days: " . $days . "\n";
	no integer;
    }
    $resStr .= $hours . "h, " . $minutes . "m, " . $seconds . "s" ;
    return $resStr;
}


# Takes 3 aguments, t1, t2 and diff
# If t2 differ more then 'diff' compared to t1 we return t2-t1 otherwise return 0
sub timesDiff($$$) {
    my($t1, $t2, $diff) = @_;
    # print "t1:   $t1\n";
    # print "t2:   $t2\n";
    # print "diff: $diff\n";
    if(($t1 + $diff) < $t2 ) {
	# print "1\n";
	return $t2 - $t1;
	            }
    if(($t1 - $diff) > $t2 || ($t1 - $diff) < 0) {
	# print "2\n";
	return $t2 - $t1;
    }
    return 0;
}


# Check that tims string is correctly formated. IE 20s, 10m, 2h etc
sub timeFormat($){
    my $timeStr = shift;

    if( $timeStr =~ /^\d+[\.]?[\d]*[sSmMdD]?$/ ) {
	return 1;
    } else {
	return 0;
    }
}

# Time converter. Converts 2m to 120s, 2h to 7200s etc.
# Supports:
# minutes (m | M)
# hours (h | H )
# days (d | D )
sub timeToSec($) {
    my $timeStr = shift;
    my $seconds = 0;

    # Seconds, no conversion
    if( $timeStr =~ /^\d+[\.]?[\d]*[sS]$/ ) {
	chop($timeStr);
	$seconds = $timeStr;
    }
    # Minutes, multiply by 60
    if( $timeStr =~ /^\d+[\.]?[\d]*[mM]$/ ) {
	chop($timeStr);
	$seconds = 60 * $timeStr;
    }
    # Hours, multiply by 60*60
    if( $timeStr =~ /^\d+[\.]?[\d]*[Hh]$/ ) {
	chop($timeStr);
	$seconds = 60 * 60 * $timeStr;
    }
    # Days, multiply by 60*60*24
    if( $timeStr =~ /^\d+[\.]?[\d]*[dD]$/ ) {
	chop($timeStr);
	$seconds = 60 * 60 * 24 * $timeStr;
    }
    return $seconds;
}


# Converts a date-string to timestamp. The string is splitted on '.-/: ' so working formats are, for example:
# YYYY-MM-DD hh:mm:ss or YYYY/MM/DD hh.mm.ss
# Note that the order is: year-month-date-hour-minute-second.
# The function also supports 'short-yesr' ie 06 is interpreted as 2006
# Years in the range 0..99 are interpreted as shorthand for years in the rolling "current century,"
# defined as 50 years on either side of the current year. Thus, today, in 2007, 0 would refer to 2000,
# and 45 to 2045, but 65 would refer to 1965. Twenty years from now, 65 would instead refer to 2065.
# This is messy, but matches the way people currently think about two digit dates.
# On systems where integers are 32bits this function breaks when year reaches 2038.
sub get_timestamp($) {
    my $dateStr = shift;
    my @dateArr = split(/[:\-\ \.\/]/, $dateStr);
    if(scalar(@dateArr) != 6) {
	if($DEBUG){
	    print "'$dateStr' is not a valid date string\n";
	}
	return 0;
    }

    if("@dateArr" !~ /^[\d\ ]*$/) {
	if($DEBUG) {
	    print "$dateStr' is not a valid date string\n";
	}
	return 0;
    }
    my $date;
    if($USDATE){
	$date = timelocal_nocheck($dateArr[5],$dateArr[4],$dateArr[3],$dateArr[1],$dateArr[1]-1,$dateArr[2]);
    } else {
	$date = timelocal_nocheck($dateArr[5],$dateArr[4],$dateArr[3],$dateArr[2],$dateArr[1]-1,$dateArr[0]);
    }
    if($date < 0 ){
	if($DEBUG) {
	    print "$dateStr' is not a valid date string\n";
	}
	return 0;
    }
    return $date;
}


sub print_usage () {
    print "$PROGNAME. Copyright (c) 2007 op5 AB. <support.op5.se>\n\n";
    print "This plugin check various Movex/M3 related system information. It does so by\n";
    print "connecting to the as400 using telnet. The plugin uses the oms400/ods400 \n";
    print "commands on the target machone\n\n";
    print " Usage: $PROGNAME -H <host> -o <option> -u <username> -p <password> \n";
    print "        -P <port> -l <link> -e <expect> -w <warning> -c <critical>\n";
    print " Where:\n";
    print " -H, --host ADDRESS\n";
    print "   The hostname or address of the remote as400 host.\n";
    print " -o, --option STRING\n";
    print "   The option/command to perform. Should be one off:\n";
    print "   LOGIN, LINK_TIME_DIFF, INACT_OBJS, ODS_TIME_DIFF, ODS_STATUS\n";
    print "   The options are described in more detal below.\n";
    print " -u, --user STRING\n";
    print "   The username used to connect. Note that this user must have permission\n";
    print "   to execute the oms400/ods400 commands.\n";
    print " -p, --password STRING\n";
    print "   The password used to connect to the remote host.\n";
    print " -P, --port INTEGER\n";
    print "   Port number to connect to. Default port = 21.\n";
    print " -l, --link STRING\n";
    print "   The name of the link we are interested in. Only valid with the \n";
    print "   LINK_TIME_DIFF and INACT_OBJS options. Note that the link name is case \n";
    print "   sensitive, so mvxlnk is not the same as MVXLNK\n";
    print " -e, --expect STRING\n";
    print "   Status string to search for when executing the ODS_STATUS option.\n";
    print " -w, --warning STRING\n";
    print "   Warning treshold, valid only with LINK_TIME_DIFF and ODS_TIME_DIFF options.\n";
    print "   Represents the allowed difference in time. Threshold can be specified with\n";
    print "   units, 10s equals 10 seconds, 4m equals 4 minutes, 2h equals 2 hours etc.\n";
    print "   Without unit the plugin defaults to seconds.\n";
    print " -c, --critical STRING\n";
    print "   Critical treshold. The same syntax as above.\n";
    print "\n";
    print " Examples:\n";
    print " To test a simple login:\n";
    print " > $PROGNAME -H myhost -u myuser -p mypasswd -o LOGIN\n";
    print "\n";
    print " To test for inactive objects on the 'System Activity Display' for the MVXLNK\n";
    print " link. (oms400 command)\n";
    print " > $PROGNAME -H myhost -u myuser -p mypasswd -o INACT_OBJS -l MVXLNK\n";
    print "\n";
    print " To test for time difference on the 'System Activity Display' for the MVXLNK\n";
    print " link. Warning if difference more then 5 min and critical if more then 8min\n";
    print " (oms400 command)\n";
    print " > $PROGNAME -H myhost -u user -p pwd -o LINK_TIME_DIFF -l MVXLNK -w 5m -c 8m\n";
    print "\n";
    print " To test for time difference on the 'System Status' page. (ods400 command)\n";
    print " Return warning if difference more then 5 min and critical if more then 8min\n";
    print " > $PROGNAME -H myhost -u user -p pwd -o ODS_TIME_DIFF -w 5m -c 8m\n";
    print "\n";
    print " To test for ods status, return critical if not equal to NORMAL\n";
    print " > $PROGNAME -H myhost -u user -p pwd -o ODS_STATUS -e NORMAL\n";
    print "\n";
}

sub print_help () {
    print "Execute '$PROGNAME --help' for usage instructions.\n";
}

sub print_rev(){
    print "$PROGNAME v.$PROGVERSION. \n";
}

sub my_die($) {
    my $errmsg = shift;
    print "ERROR: $errmsg\n";
#    if($telnet){
#	$telnet->close();
#    }
    exit $ERRORS{'UNKNOWN'};
}



# Helper. Strips whitspace's from beginning and end of string
sub trim($){
    my $string = shift;
    $string =~ s/^\s+//;
    $string =~ s/\s+$//;
    return $string;
}


sub test(){
    my $current_time;
    my $current = " Date   6/27/07            System Activity Display          Time:   15:42:21  ";
    if($current =~ /[ A-Za-z]+([0-9\/]+)[ :A-Za-z]+([0-9:]+).*/){
	my $time = $2;
	my $year = $1;
	$current_time = get_timestamp("$1 $2");
    }

    my %list = ();
    my @screen;
    $screen[0] = " 1. ODS/400 Definitions";
    $screen[1] = " 2. ODS/400 Object Transaction Status                            ODSOBJSTS";
    $screen[2] = " 3. ODS/400 System Status                                        ODSSYSSTS";
    $screen[3] = "4. Print System Configuration  ";
    $screen[4] = "5. Submit Sync-Check Processing                                 ODSSYNCHK ";
    $screen[5] = "6. Change System Role                                           ODSCHGROLE ";
    $screen[6] = "10. Start Object Distribution System                             STRODS ";
    $screen[7] = "11. End Object Distribution System                               ENDODS";

#    $screen[0] = "SOURCE SYSTEM   Status   Sequence #  Diff/Trans    Date     Time     Trns/Hr ";
 #   $screen[1] = "Journal                  2161158733               6/27/07 15:42:21";
 #   $screen[2] = "Reader/Sender  *ACTIVE   2161158584         149   6/27/07  15:42:22             ";
 #   $screen[3] = " Config: NORMAL   Inact Objs: s          w                 Elapsed Time:  0:00:00 ";
 #   $screen[4] = " TARGET SYSTEM                                                                  ";
#    $screen[5] = " Receiver       *ACTIVE   2161158439         294   6/27/07 15:42:23             ";
#    $screen[6] = "                                      ----------           --------             ";
#    $screen[7] = " Sending Lag                                 294            0:00:00             ";
    $screen[8] = "                                                                                ";
    $screen[9] = " Router         *ACTIVE   2161158439         294   6/27/07 15:42:24             ";
    $screen[10] = "                                                                                ";
    $screen[11] = " Apply T1       *ACTIVE   2161158431         302   6/27/07 15:42:25             ";
    $screen[12] = " Apply T2       *ACTIVE   2161158439         294   6/27/07 15:42:26             ";
    $screen[13] = " Apply T3       *ACTIVE   2161158439         294   6/27/07 15:42:27             ";
    $screen[14] = "12345678901234567890123456789012345678901234567890                                                                                ";
    $screen[15] = "                                                                                ";
    $screen[16] = " **WARNING**  Journal sequence number 2161158733 has exceeded the threshold v ";


    foreach(@screen){
	$_ = trim($_);
	if($_ =~ m/.*(\d).*ODS\/400 System Status/){
#	if($_ =~ /.*Inact Objs:(.*)Elapsed Time:.*/){
	    print "-> $_\n";
	    print "--> '" . trim($1) . "'\n";

	}
    }

#    foreach(@screen){
#	$_ = trim($_);
#	if($_ =~ /([A-Za-z\/ 0-9]{2,15}).*([0-9\/]{7,}) +([0-9:]{7,})/){
#	    my $time = get_timestamp($2 . " " . $3);
#	    $list{trim($1)} = $time;
#	}
#    }
#    for my $key ( keys %list ) {
#	my $value = $list{$key};
#	if($res = timesDiff($current_time, $value, 20)){
#	    print "$key , $res\n";
#	}
 #   }
  #  print $current . "\n";
}
sub reader(){
    while (<STDIN>) {
	$mystr = $_;
	$i=0;
	while($i < length($mystr) && $i < 10){
	    print ord(substr($mystr, $i,1));
	    if(ord(substr($mystr, $i,1)) > 31 && ord(substr($mystr, $i,1)) < 127) {
		print " - '" . substr($mystr, $i,1) . "'";
	    }
	    print"\n";
	    $i++;
	}
    }
    exit(0);
}









# JUNK.....
#   sleep(1);
#   my $host = "137.33.47.15";
#   $spawn=Expect->spawn("telnet $host");
#   $spawn->debug(0);
#   # log everything if you want
#   # $spawn->slave->clone_winsize_from(\*STDIN);
#   $spawn->slave->stty(qw(raw -echo));
#   # $spawn->expect_stty();
#   $spawn->log_file("/tmp/autossh.log.$$");
#   # $spawn->log_stdout(0);
#   sleep(1);
#   # $spawn->expect(5,"user");
#   $spawn->send("SEKOP55\t");
#   $spawn->send("SEMOVEX\r\n");
#   sleep(1);


#   $spawn->clear_accum();

#   open(MYOUTFILE, ">>filename.out");
#   # my $res = $spawn->expect(2, '-re', "^.*===>.*" );
#   $res = $spawn->expect(2, "===>" );


#   $spawn->clear_accum();

#   $vt->process ($spawn->before) if (defined $spawn->before);

#   print MYOUTFILE "vt1: '" . $vt->row_plaintext(1) . "'\n";
#   print MYOUTFILE "vt2: '" . $vt->row_plaintext(2) . "'\n";
#   print MYOUTFILE "vt3: '" . $vt->row_plaintext(3) . "'\n";
#   print MYOUTFILE "vt4: '" . $vt->row_plaintext(4) . "'\n";
#   print MYOUTFILE "vt5: '" . $vt->row_plaintext(5) . "'\n";
#   $i=0;
#   print "rows: " . $vt->rows() . "\n";
#   while($i < $vt->rows()){
#       print $vt->row_plaintext($i);
#       $i++;
#   }


#   if($res){
#       print "res: $res\n";
#   } else {
#       print "noop\n";
#       print "Error: " . trim($vt->row_plaintext($vt->rows()-1)) . "\n";
#       exit(0);
#   }


#   $spawn->send("a*\r\n");

#   # 27
#   #  91 - '['
#   #  50 - '2'
#   #  52 - '4'
#   #  126 - '~'
#   sleep(1);
#   $spawn->send(chr(27) .chr(91) .chr(50) .chr(52) .chr(126));
#   sleep(1);
#   $spawn->interact();
#   exit(0);
#   $res = $spawn->expect(2, "===>" );
#   $vt->process ($spawn->before) if (defined $spawn->before);

#   $i=0;
#   print "\n -----> rows: " . $vt->rows() . "\n";
#   while($i < $vt->rows()){
#       print $vt->row_plaintext($i);
#       $i++;
#   }

#   sleep(2);


#   $spawn->send("signoff endcnn(*yes)\r\n");
#   # sleep(1);
#   # $spawn->interact();

#   exit;

#   $spawn->send("wrkactjob");
#   sleep(1);
#   $spawn->send("\r\n");
#   sleep(1);
#   $res = $spawn->expect(2, "Subsystem" );
#   exit(0);
#   # print "before: '" . $spawn->before . "'";
#   sleep(1);
#   print "res='$res'\n";
#   # print "before: '" . $spawn->before . "'";
#   # print "match: '" . $spawn->match . "'";
#    print "after: '" . $spawn->after . "'";
#   $mystr = $spawn->after;
#   $i=0;

#   $mystr =~ s/'0'/'s'/;

#   while($i < length($mystr) && $i < 0){

#       print ord(substr($mystr, $i,1));
#       if(ord(substr($mystr, $i,1)) > 31 && ord(substr($mystr, $i,1)) < 127) {
#   	print " - '" . substr($mystr, $i,1) . "'";
#       }

#       print"\n";
#       $i++;
#   }

#   print "l:" . length($mystr) . "\n";
#   $spawn->send("signoff endcnn(*yes)\r\n");
#   sleep(1);
#   # $spawn->interact();

#   exit;

#   # my $PROMPT  = '[\]\$\>\#]\s$';
#   # my $ret = $spawn->expect(10,
#   #	[ qr/\(yes\/no\)\?\s*$/ => sub { $spawn->send("yes\n"); exp_continue; } ],
#   #	[ qr/assword:\s*$/ 	=> sub { $spawn->send("$password\n") if defined $password;  } ],
#   #	[ qr/ogin:\s*$/		=> sub { $spawn->send("$username\n"); exp_continue; } ],
#   #	[ qr/REMOTE HOST IDEN/ 	=> sub { print "FIX: .ssh/known_hosts\n"; exp_continue; } ],
#   #	[ qr/$PROMPT/ 		=> sub { $spawn->send("echo Now try window resizing\n"); } ],
#   # );

#   # $ret = $spawn->send("ls\n");
#   # print "ls return > $ret <";
#   # print "expecting prompt\n";
#   # $ret = $spawn->expect(10,$PROMPT);
#   # print "got prompt, '$ret'\n";
#   # Hand over control
#   # $spawn->interact();
#   exit;

# END misc junk...
