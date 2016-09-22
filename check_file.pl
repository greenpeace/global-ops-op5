#!/usr/bin/perl -w
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


use File::Glob ':glob';
use File::Basename;

use strict;
use Getopt::Long;
use File::stat;
use lib "/opt/plugins/";
use utils qw ($TIMEOUT %ERRORS &print_revision &support);
use Switch;

sub print_help ();
sub print_usage ();
sub check_result ($);
sub check_result_low ($);
sub check_result_high ($);
sub format_multi;
sub trim ($);
my ($opt_c, $opt_f, $opt_w, $opt_C, $opt_W, $opt_h, $opt_V, $opt_a, $opt_d, $opt_v, $opt_t);
my ($result, $message, $age, $size, $st, @tmparr, $status);

my $dir_check = 0;
my $PROGNAME="check_file";
my $PROGVERSION="1.1.3";

my @ERRORS_STR=('OK','WARNING','CRITICAL','UNKNOWN');
my $DEBUG=0;

Getopt::Long::Configure('bundling');
GetOptions(
	"V"   => \$opt_V, "version"	=> \$opt_V,
	"h"   => \$opt_h, "help"	=> \$opt_h,
	"f=s" => \$opt_f, "file=s"	=> \$opt_f,
	"d" => \$opt_d, "directory"	=> \$opt_d,
	"v=s" => \$opt_a, "variable=s" => \$opt_a,
	"t=f" => \$opt_t, "timeout=f" => \$opt_t,
	"w=f" => \$opt_w, "warning-low=f" => \$opt_w,
	"W=f" => \$opt_W, "warning-high=f" => \$opt_W,
	"c=f" => \$opt_c, "critical-low=f" => \$opt_c,
	"C=f" => \$opt_C, "critical-high=f" => \$opt_C);

# Set and use alarmclock.
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
	print "$PROGNAME v$PROGVERSION\n";
	exit $ERRORS{'OK'};
}

if ($opt_h) {
	print_help();
	exit $ERRORS{'OK'};
}

if ($opt_d){
	$dir_check = 1;
}



if ( ! $opt_f) {
	print "No file or directory specified\n";
	exit $ERRORS{'UNKNOWN'};
}
if ( ! $opt_a ) {
	print "No variable supplied (Don't know what to do...)\n";
	exit $ERRORS{'UNKNOWN'};
}


if ($dir_check){
	switch($opt_a){
		case "num" {
			my $string = $opt_f;
			$string =~ s/\/*$//;
			unless ( -d $opt_f ) {
				print "$opt_f: Dir not found\n";
				exit $ERRORS{'UNKNOWN'};
			}
			@tmparr = glob("$opt_f/*");
			$result = scalar(@tmparr);
			$status = check_result($result);
			print "$ERRORS_STR[$status] - $result files in directory '$opt_f'\n";
			exit($status);
		}
		case "age" {
			unless ( -d $opt_f ) {
				print "$opt_f: Dir not found\n";
				exit $ERRORS{'UNKNOWN'};
			}
			$st = File::stat::stat($opt_f);
			$age = time - $st->mtime;
			$status = check_result($age);
			print "$ERRORS_STR[$status] - Directory '$opt_f' is $age seconds old\n";
			exit($status);
		}
		case "size" {
			my $string = $opt_f;
			$string =~ s/\/*$//;
			
			unless ( -d $string ) {
				print "$opt_f: Directory not found\n";
				exit $ERRORS{'UNKNOWN'};
			}
			@tmparr = glob("$string/*");
			my $file;
			my ($numLowCrit, $numLowWarn, $numHighCrit, $numHighWarn);
			my (@lowCrit, @lowWarn, @highCrit, @highWarn);
			$numLowCrit = 0;
			$numLowWarn = 0; 
			$numHighCrit = 0;
			$numHighWarn = 0;
			foreach $file (@tmparr){
				$st = File::stat::stat($file);
#				$age = time - $st->mtime;
				$size = $st->size;
				$status = check_result_low($size);
				if($status == $ERRORS{'WARNING'}){
					$numLowWarn += 1;
					push(@lowWarn, basename($file));
				}
				if($status == $ERRORS{'CRITICAL'}){
					$numLowWarn += 1;
					push(@lowCrit, basename($file));
				}
				$status = check_result_high($size);
				if($status == $ERRORS{'WARNING'}){
					$numHighWarn += 1;
					push(@highWarn, basename($file));
				}
				if($status == $ERRORS{'CRITICAL'}) {
					push(@highCrit, basename($file));
					$numHighCrit += 1;
				}
			#	print $file . " ";
			}
			if($numHighCrit){
				print "Critical - $numHighCrit files in dir '$opt_f' is larger then $opt_C bytes. (" . 
				  format_multi(@highCrit)  . ")\n";
				exit $ERRORS{'CRITICAL'};
			}
			if($numLowCrit){
				print "Critical - $numLowCrit files in dir '$opt_f' is smaller then $opt_c bytes. (" .
				  format_multi(@lowCrit)  . ")\n";
				exit $ERRORS{'CRITICAL'};
			}
			if($numHighWarn){
				print "Warning - $numHighWarn files in dir '$opt_f' is larger then $opt_W bytes. (" . 
				  format_multi(@highWarn)  . ")\n";
				exit $ERRORS{'WARNING'};
			}
			if($numLowWarn){
				print "Warning - $numLowWarn files in dir '$opt_f' is smaller then $opt_w bytes. (" .
				  format_multi(@lowWarn)  . ")\n";
				exit $ERRORS{'WARNING'};
			}
			print "OK - All " . scalar(@tmparr) . " files in dir '$opt_f' are within the size limit(s)\n";
			exit $ERRORS{'OK'};
		}
		default {
			print "Unknown argument '$opt_a'\n";
			exit $ERRORS{'UNKNOWN'};
		}
	}
} else {
	my $num_crit = 0;
	my $num_warn = 0;
	my $num_ok = 0;
	my $num_tot = 0;
	my $file;

	switch($opt_a){
		case "num" {
			@tmparr = bsd_glob("$opt_f",GLOB_ERR);
			$result = scalar(@tmparr);
			$status = check_result($result);
			print "$ERRORS_STR[$status] - $result file(s) matching '$opt_f'\n";
			exit($status);
		}
		case "age" {
			@tmparr = bsd_glob($opt_f,GLOB_ERR);
			$result = scalar(@tmparr);
#			print $result . "\n";
#			if( ! $result ) {
#				print "$opt_f: File not found\n";
#				exit $ERRORS{'UNKNOWN'};
#			}
			foreach(@tmparr) {
				$file = $_;
				$st = File::stat::stat($_);
				$age = time - $st->mtime;
				$status = check_result($age);
				if($status == $ERRORS{'CRITICAL'}){
					$num_crit += 1;
				}
				if($status == $ERRORS{'WARNING'}){
					$num_warn += 1;
				}
				if($status == $ERRORS{'OK'}){
					$num_ok += 1;
				}
				$num_tot += 1;
			}
			if($num_crit){
				if($num_tot == 1){
					print "CRITICAL - File '$file' is $age seconds old\n";
				} else {
					print "CRITICAL - $num_crit of $num_tot files has critical age\n";
				}
				exit $ERRORS{'CRITICAL'};
			}
			if($num_warn){
				if($num_tot == 1){
					print "WARNING - File '$file' is $age seconds old\n";
				} else {
					print "WARNING - $num_warn of $num_tot files has warning age\n";
					}
				exit $ERRORS{'WARNING'};
			}
			if($num_tot == 1){
				print "OK - File '$file' is $age seconds old\n";
			} else {
				print "OK - All $num_ok files has ok age\n";
			}
			exit $ERRORS{'OK'};
		}
		case "size" {
			@tmparr = bsd_glob($opt_f,GLOB_ERR);
			$result = scalar(@tmparr);
#			if( ! $result ) {
#				print "$opt_f: File not found\n";
#				exit $ERRORS{'UNKNOWN'};
#			}
			foreach(@tmparr) {
				$file = $_;
				$st = File::stat::stat($_);
				$size = $st->size;
				$status = check_result($size);
				if($status == $ERRORS{'CRITICAL'}){
					$num_crit += 1;
				}
				if($status == $ERRORS{'WARNING'}){
					$num_warn += 1;
				}
				if($status == $ERRORS{'OK'}){
					$num_ok += 1;
				}
				$num_tot += 1;
			}
			if($num_crit){
				if($num_tot == 1){
					print "CRITICAL - File '$file' is $size bytes\n";
				} else {
					print "CRITICAL - $num_crit of $num_tot files is critical in size\n";
				}
				exit $ERRORS{'CRITICAL'};
			}
			if($num_warn){
				if($num_tot == 1){
					print "WARNING - File '$file' is $size bytes\n";
				} else {
					print "WARNING - $num_warn of $num_tot files is warning in size\n";
					}
				exit $ERRORS{'WARNING'};
			}
			if($num_tot == 1){
				print "OK - File '$file' is $size bytes\n";
			} else {
				print "OK - All $num_ok files is ok in size\n";
			}
			exit $ERRORS{'OK'};
		}
		default {
			print "Unknown argument '$opt_a'\n";
			exit $ERRORS{'UNKNOWN'};
		}
	}

}

print "Unknown error\n";
exit $ERRORS{'UNKNOWN'};


# Helpers
sub format_multi{
	my $s;
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


sub check_result_low($) {
	my $res = shift;
	if($res !~ /\d+\.?\d?/){
		print "Non numeric comparison, query returned '$res'\n";
		exit $ERRORS{"UNKNOWN"};
	}
	if(defined($opt_c) && $opt_c >= $res) {
		#       print "CRIT\n";
		return $ERRORS{"CRITICAL"};
	}
	if(defined($opt_w) && $opt_w >= $res) {
		#       print "WARN\n";
		return $ERRORS{"WARNING"};
	}
	return $ERRORS{'OK'};
}

sub check_result_high($) {
	my $res = shift;
	if($res !~ /\d+\.?\d?/){
		print "Non numeric comparison, query returned '$res'\n";
		exit $ERRORS{"UNKNOWN"};
	}
	if(defined($opt_C) && $opt_C <= $res) {
#		print "CRIT\n";
		return $ERRORS{"CRITICAL"};
	}
	if(defined($opt_W) && $opt_W <= $res) {
#		print "WARN\n";
		return $ERRORS{"WARNING"};
	}
	return $ERRORS{'OK'};
}

sub check_result($) {
	my $res = shift;
	if($DEBUG){
		print "Comparing value '$res' to tresholds\n";
	}
	 
	if($res !~ /\d+\.?\d?/){
		print "Non numeric comparison, query returned '$res'\n";
		exit $ERRORS{"UNKNOWN"};
	}
	
	if(defined($opt_c) && $opt_c >= $res) {
#		print "CRIT\n";
		return $ERRORS{"CRITICAL"};
	}
	if(defined($opt_w) && $opt_w >= $res) {
#		print "WARN\n";
		return $ERRORS{"WARNING"};
	}
	if(defined($opt_C) && $opt_C <= $res) {
#		print "CRIT\n";
		return $ERRORS{"CRITICAL"};
	}
	if(defined($opt_W) && $opt_W <= $res) {
#		print "WARN\n";
		return $ERRORS{"WARNING"};
	}
#	print "OK\n";
	return $ERRORS{"OK"};
}

sub print_usage () {
	print "Usage:\n";
#	print "  $PROGNAME [-w <secs>] [-c <secs>] [-W <size>] [-C <size>] -f <file>\n";
	print "  $PROGNAME [-h | --help]\n";
	print "  $PROGNAME [-V | --version]\n";
	print "  $PROGNAME -f <file> -v <variable> [-d] [-w <low-warn>] [-W <high-warn>]\n";
	print "            [-c <low-crit>] [-C <high-crit>] [-t <timeout>]\n";
	print "  Where:\n";
	print "   -f <file> is the file to check\n";
	print "      Wildcards '*' is supported (escape with backslash '\\' on Unix/Linux)\n"; 
	print "   -d check directory instead of file\n";
	print "   -v <variable> is the variable to check. Valid variables are:\n";
	print "     size = Check the size of specified file compared to treshold(s). \n";
	print "            If -d is used the size of all files in the directory are \n";
	print "            compared to treshold(s).\n";
	print "     age = Check the age of specified file compared to treshold(s).\n";
	print "           If -d the age of all files in the dir are compared to treshold(s).\n";
	print "     num = Check the number of files matching supplied file-name. \n";
	print "           If -d the number of file in the dir are compared to treshold(s)\n";
	print "           Wildcards is supported if escaped with a backslash '\'. To search \n";
	print "           for all files starting with 'check_file' you use: \n";
	print "           $PROGNAME -f check_file\* -v num ...\n";
	print "           To return critical if file do not exist use:\n";
	print "           $PROGNAME -f <file> -v num -c 0 \n";
	print "   -w = low warning treshold. Warn if result is less or equal to treshold.\n";
	print "   -c = low critical treshold. Critical if result is less or equal to treshold.\n";
	print "   -W = high warning treshold. Warn if result is larger or equal to treshold.\n";
	print "   -C = high critical treshold. Crit if result is larger or equal to treshold.\n";
	print "      Critical tresholds have precedence so the plugin returns critical if both\n";
	print "      critical and warning tresholds are reached\n";
	print "   -t <timeout> (sec) can be applied to all commands. Default timeout $TIMEOUT\n";
	print "\n";
	print "Examples:\n";
	print "   To search for all files starting with 'check_file' you use: \n";
	print "      $PROGNAME -f check_file\* -v num ...\n";
	print "   To return critical if file do not exist use:\n";
	print "      $PROGNAME -f <file> -v num -c 0 \n";
	print "   To return critical if one ore more files starting with check* is older than\n";
	print "   500 seconds use:\n";
	print "      $PROGNAME -f check* -v age -C 500\n";
	print "\n";

}

sub print_help () {
	print "$PROGNAME v$PROGVERSION\n";
	print_usage();
}
# Strip leading/trailing whitespaces and trailing newline fromstring
sub trim($){
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}
