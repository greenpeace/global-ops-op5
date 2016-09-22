#!/usr/bin/perl -w
#
# Nagios plugin to monitor op5 backup
#
# License: GPL
# Copyright (c) 2010 op5 AB
# Author: Kostyantyn Hushchyn <op5-users@lists.op5.com>
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
use Getopt::Long;
use File::stat;
use File::Basename;
use Time::Local;
use vars qw ($TIMEOUT $PROGNAME $VERSION %ERRORS);

my @ERRORS_STR=('OK','WARNING','CRITICAL','UNKNOWN');
my $PROGNAME = basename($0);
my $VERSION = '0.1.0';
my $backup_dir = "/var/log/op5-backup";
my @backups;
my $max_date = 0;
my $max_time = 0;
my ($opt_h, $opt_V, $opt_w, $opt_c, $opt_t);

$TIMEOUT = 10;

my $sanity = GetOptions(
	"V"   => \$opt_V, "version"	=> \$opt_V,
	"h"   => \$opt_h, "help"	=> \$opt_h,
	"w=i" => \$opt_w, "warning=i"	=> \$opt_w,
	"c=i" => \$opt_c, "critical=i"	=> \$opt_c,
	"t=f" => \$opt_t, "timeout=f" => \$opt_t);

# Set and use alarmclock.
if($opt_t)
{
	$TIMEOUT = $opt_t;
}

if ($opt_V)
{
	print("$PROGNAME v$VERSION\n");
	exit(0);
}

if ($opt_h || !$sanity)
{
	print_help();
	exit(3);
}

$opt_w = 7 if (!$opt_w);
$opt_c = 14 if (!$opt_c);

# Just in case of problems, let's not hang Nagios
$SIG{'ALRM'} = sub {
	nagios_exit("timed out (alarm)", 3);
};
alarm($TIMEOUT);

opendir(my $dh, $backup_dir) || nagios_exit("Can't open backup dir $backup_dir: $!", 2);
while (my $filename = readdir($dh))
{
	my ($backup_date, $backup_time) = $filename =~ m/backup-(.*)-(.*)\.log/;
	if (defined($backup_date) && defined($backup_time))
	{
		if ($max_date < $backup_date)
		{
			$max_date = $backup_date;
			$max_time = $backup_time;
		}
		elsif ($max_date == $backup_date)
		{
			$max_time = $backup_time if ($backup_time > $max_time);
		}
	}
}
closedir($dh);

nagios_exit("$backup_dir/backup-$max_date-$max_time.log does not exist", 2) if (!-f "$backup_dir/backup-$max_date-$max_time.log");
open(my $log_handle, '<', "$backup_dir/backup-$max_date-$max_time.log") or nagios_exit("Can't open backup $backup_dir/backup-$max_date-$max_time.log: $!", 2);
my $res = seek($log_handle, -32, 2);
my @text = <$log_handle>;
close($log_handle);

$max_date .= $max_time;
$max_date =~ s/(....)(..)(..)(..)(..)(..)/$1-$2-$3 $4:$5:$6/;

my $time_diff = time() - timelocal($6, $5, $4, $3, $2 - 1, $1);

nagios_exit("Latest backup scheduled on $max_date is in future. Please, check your clock settings", 2) if ($time_diff < 0);
nagios_exit("Latest backup scheduled on $max_date is too old (more than $opt_c days)", 2) if ($time_diff > 86400 * $opt_c);
nagios_exit("Latest backup scheduled on $max_date is too old (more than $opt_w days)", 1) if ($time_diff > 86400 * $opt_w);

if (@text) {
	nagios_exit("Last backup scheduled on $max_date was succesfully completed", 0) if ($text[-1] =~ /Backup was successfully created\n/);
	nagios_exit("Last backup scheduled on $max_date failed", 2) if ($text[-1] eq "FAIL\n");
}

nagios_exit("Last backup scheduled on $max_date still in progress", 3);

sub print_usage
{
	print("  Plugin works with op5 backup 2.0 and later\n\n");
	print("Usage:\n");
	print("  $PROGNAME [-h | --help]\n");
	print("  $PROGNAME [-V | --version]\n");
	print("  $PROGNAME [-t <timeout>]\n");
	print("  Where:\n");
	print("   -t <timeout> (sec) can be applied to all commands. Default timeout $TIMEOUT\n");
	print("   -w/--warning [days]    Trigger a warning if the age in days of\n");
	print("                          the last backup goes outside of the range\n");
	print("                          [0..days]. Default: 7\n");
	print("   -c/--critical [days]   Trigger a critical status if the age in\n");
	print("                          days of the last backup goes outside of\n");
	print("                          the range [0..days]. Default: 14\n");
	print("   -h/--help              Show this help text\n");
}

sub print_help
{
	print "$PROGNAME v$VERSION\n";
	print_usage();
}

sub nagios_exit
{
	my ($message, $return) = @_;

	$message = "" if (!defined($message));
	$return = 3 if (!defined($return) && $return < 0 && $return > @ERRORS_STR);

	print($PROGNAME . " " . $ERRORS_STR[$return] . " - " . $message . "\n");
	exit($return);
}
