#! /usr/bin/perl
#
# check_bigip_pool
# - Check the number of available servers in a BigIP Virtual Server
#
# Designed for F5 BigIP 4.5 and LTM 9.x.
#
# Copyright (C) 2006-2007 Thomas Guyot-Sionnest <tguyot@gmail.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
#
# Extended to support LTM 10.x software versions. By Guillermo Caracuel Ruiz gcaracuel@epes.es
#
use strict;
use warnings;
use vars qw($PROGNAME $VERSION $WARNING $CRITICAL $snmpcmd $snmpwalkcmd %bip);
use Nagios::Plugin;
$PROGNAME = 'check_bigip_pool';
$VERSION = '2.03';
$WARNING = 90;
$CRITICAL = 50;
$snmpcmd = '/usr/bin/snmpget';
$snmpwalkcmd = '/usr/bin/snmpwalk';
# BigIP config. For each bigip version, there is the base OID for various
# objects.
%bip = (
'4.5' => {
'PoolActiveMemberCnt' => '.1.3.6.1.4.1.3375.1.1.7.2.1.27.',
'PoolMemberCnt' => '.1.3.6.1.4.1.3375.1.1.7.2.1.4.',
},
'9' => {
'PoolActiveMemberCnt' => '.1.3.6.1.4.1.3375.2.2.5.1.2.1.8.',
'PoolMemberCnt' => '.1.3.6.1.4.1.3375.2.2.5.3.2.1.1',
},
'10' => {
'PoolActiveMemberCnt' => '.1.3.6.1.4.1.3375.2.2.5.1.2.1.8.',
'PoolMemberCnt' => '.1.3.6.1.4.1.3375.2.2.5.3.2.1.1',
},
'11' => {
'PoolActiveMemberCnt' => '.1.3.6.1.4.1.3375.2.2.5.1.2.1.8.',
'PoolMemberCnt' => '.1.3.6.1.4.1.3375.2.2.5.1.2.1.23',
}
);
my $np = Nagios::Plugin->new(
usage => "Usage: %s -H <hostname> -C <Community> -S <SW Version>\n"
. ' -P <Pool Name> [ -w <warning percent> ] [ -c <critical percent> ]',
version => $VERSION,
plugin => $PROGNAME,
shortname => uc($PROGNAME),
blurb => 'Check the number of available nodes in a BigIP Pool',
timeout => 10,
);
$np->add_arg(
spec => 'hostname|H=s',
help => '-H, --hostname=<hostname>',
required => 1,
);
$np->add_arg(
spec => 'community|C=s',
help => '-C, --community=<Community>',
required => 1,
);
$np->add_arg(
spec => 'software|S=s',
help => "-S, --software=<SW Version> \n"
. " The BigIP software version running on the BigIP. This can be:\n"
. " 4.5\tOlder BigIP models like the 5100 series.\n"
. " 9\tBigIP LTM like the 6400 series.\n"
. " 10\tNewer BigIP LTM like the 6400 series.",
required => 1,
);
$np->add_arg(
spec => 'pool|P=s',
help => "-P, --pool=<Pool Name>\n"
. " This is the exact (case-sensitive) Pool Name\n",
required => 1,
);
$np->add_arg(
spec => 'warning|w=f',
help => "-w, --warning=<warning percent>\n"
. " The the check will return a WARNING state when there is LESS THAN this\n"
. " percentage of alive nodes. Floats are accepted. The default is $WARNING",
default => $WARNING,
required => 0,
);
$np->add_arg(
spec => 'critical|c=f',
help => "-c, --critical=<critical percent>\n"
. " The the check will return a CRITICAL state when there is LESS THAN this\n"
. " percentage of alive nodes. Floats are accepted. The default is $CRITICAL",
default => $CRITICAL,
required => 0,
);
$np->getopts;
# Assign, then check args
my $hostname = $np->opts->hostname;
my $community = $np->opts->community;
my $software = $np->opts->software;
my $PoolName = $np->opts->pool;
my $warnpercent = $np->opts->warning;
my $critpercent = $np->opts->critical;
$np->nagios_exit('UNKNOWN', 'Hostname contains invalid characters.')
if ($hostname =~ /\`|\~|\!|\$|\%|\^|\&|\*|\||\'|\"|\<|\>|\?|\,|\(|\)|\=/);
$np->nagios_exit('UNKNOWN', "Unknown SW version $software")
if ($software ne '4.5' && $software ne '9' && $software ne '10' && $software ne '11');
$np->nagios_exit('UNKNOWN', 'Community contains invalid characters.')
if ($community =~ /\`|\~|\!|\$|\%|\^|\&|\*|\||\'|\"|\<|\>|\?|\,|\(|\)|\=/);
$np->nagios_exit('UNKNOWN', 'Warning thresholds must be a float between 0 and 100.')
if ($warnpercent < 0 || $warnpercent > 100);
$np->nagios_exit('UNKNOWN', 'Critical threshold must be a float between 0 and 100.')
if ($critpercent < 0 || $critpercent > 100);
$np->nagios_exit('UNKNOWN', 'Warning threshold must not be lower than critical threshold.')
if ($warnpercent < $critpercent);
# Just in case of problems, let's not hang Nagios
alarm $np->opts->timeout;
my $oidPoolName = $PoolName;
$oidPoolName =~ s/(.)/sprintf('.%u', ord($1))/eg;
$oidPoolName = length($PoolName) . $oidPoolName;
# Construct the OIDs for Members count & Active members
# v9 doesn't have a member count so we have to walk
# F5-BIGIP-LOCAL-MIB::ltmPoolMemberPoolName and look for our pool name
my $cmd;
if ($software eq '4.5') {
$cmd = "$snmpcmd -v2c -c $community -m '' -On -Oe $hostname " . $bip{$software}{'PoolMemberCnt'} . $oidPoolName;
}
if ($software eq '9' || $software eq '10' || $software eq '11') {
$cmd = "$snmpwalkcmd -v2c -c $community -m '' -On -Oe $hostname " . $bip{$software}{'PoolMemberCnt'};
}
if ($np->opts->verbose) {
print STDERR "Getting 'MemberQty' trough SNMP\n";
print STDERR "Running command: \"$cmd\"\n" if ($np->opts->verbose >= 2);
} else {
$cmd .= ' 2>/dev/null';
}
my ($MemberQty, $MemberQtyCount);
if ($software eq '4.5') {
$MemberQty = `$cmd`;
$np->nagios_exit('CRITICAL', 'Could not retrieve MemberQty from the BigIP') if ($? != 0);
}
if ($software eq '9' || $software eq '10') {
$MemberQtyCount = 0;
my $membermatch = $bip{$software}{'PoolMemberCnt'} . ".$oidPoolName";
$membermatch =~ s/\./\\./g;
print STDERR "Matching F5-BIGIP-LOCAL-MIB::ltmPoolMemberPoolName against '$membermatch'\n"
if ($np->opts->verbose);
open (SNMPWALK, "$cmd|") or $np->nagios_exit('CRITICAL', 'Could not walk ltmPoolMemberPoolName from the BigIP');
while (<SNMPWALK>) {
$MemberQty .= $_;
$MemberQtyCount++ if (/^$membermatch/);
}
}
if($software eq '11')
{
$MemberQtyCount = 0;
my $membermatch = $bip{$software}{'PoolMemberCnt'} . ".$oidPoolName";
$membermatch =~ s/\./\\./g;
print STDERR "Matching F5-BIGIP-LOCAL-MIB::ltmPoolMemberPoolName against '$membermatch'\n"
if ($np->opts->verbose);
open (SNMPWALK, "$cmd|") or $np->nagios_exit('CRITICAL', 'Could not walk ltmPoolMemberPoolName from the BigIP');
while (<SNMPWALK>) {
$MemberQty .= $_ if (/^$membermatch/);
}
}
print STDERR "Command returned: \"$MemberQty\"\n" if ($np->opts->verbose >= 3);
$cmd = "$snmpcmd -v2c -c $community -m '' -On -Oe $hostname " . $bip{$software}{'PoolActiveMemberCnt'} . $oidPoolName;
if ($np->opts->verbose) {
print STDERR "Getting 'ActiveMemberCount' trough SNMP\n";
print STDERR "Running command: \"$cmd\"\n" if ($np->opts->verbose >= 2);
} else {
$cmd .= ' 2>/dev/null';
}
my $ActiveMemberCount = `$cmd`;
print STDERR "Command returned: \"$ActiveMemberCount\"\n" if ($np->opts->verbose >= 3);
$np->nagios_exit('CRITICAL', 'Could not retrieve ActiveMemberCount from the BigIP') if ($? != 0);
#Turn off alarm
alarm(0);
# Process the results
if ($software eq '4.5') {
my @test;
@test = split(/ /, $MemberQty);
$np->nagios_exit('CRITICAL', 'Could not interpret MemberQty from the BigIP')
if ($test[3] !~ /^\d+$/);
$MemberQty = $test[3];
$MemberQty = int($MemberQty);
}
if ($software eq '9' || $software eq '10') {
$MemberQty = $MemberQtyCount;
}
if ($software eq '11') {
my @test;
@test = split(/ /, $MemberQty);
$np->nagios_exit('CRITICAL', 'Could not interpret MemberQty from the BigIP')
if ($test[3] !~ /^\d+$/);
$MemberQty = $test[3];
$MemberQty = int($MemberQty);
}
my @test;
@test = split(/ /, $ActiveMemberCount);
$np->nagios_exit('CRITICAL', 'Could not interpret ActiveMemberCount from the BigIP')
if ($test[3] !~ /^\d+$/);
$ActiveMemberCount = $test[3];
$ActiveMemberCount = int($ActiveMemberCount);
# Return the status based on values gatheres and thresholds set.
$np->nagios_exit('UNKNOWN', "$PoolName $ActiveMemberCount/$MemberQty nodes make no sense")
if ($ActiveMemberCount < 0 || $MemberQty <= 0 || $ActiveMemberCount > $MemberQty);
$np->nagios_exit('OK', "$PoolName all $MemberQty nodes online")
if ($MemberQty == $ActiveMemberCount);
$np->nagios_exit('CRITICAL', "$PoolName none of $MemberQty nodes online")
if ($ActiveMemberCount == 0);
$np->nagios_exit('CRITICAL', "$PoolName $ActiveMemberCount/$MemberQty nodes online")
if (($ActiveMemberCount / $MemberQty * 100) < $critpercent);
$np->nagios_exit('WARNING', "$PoolName $ActiveMemberCount/$MemberQty nodes online")
if (($ActiveMemberCount / $MemberQty * 100) < $warnpercent);
$np->nagios_exit('OK', "$PoolName $ActiveMemberCount/$MemberQty nodes online")
if (($ActiveMemberCount / $MemberQty * 100) >= $warnpercent);
# We should NEVER end up here...
$np->nagios_exit('UNKNOWN', "$PoolName $ActiveMemberCount/$MemberQty unknown");
