#!/usr/bin/perl -w
#
# License: GPL
# Copyright (c) 2008 op5 AB
# Author: Kostyantyn Gushtin <op5-users@lists.op5.com>
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


my %statuses = (0 => 'OK', 1 => 'WARNING', 2 => 'CRITICAL', 3 => 'UNKNOWN');

if (grep(m/^-h$/, @ARGV) || grep(m/^--help$/, @ARGV) || @ARGV != 3)
{
	print "check_dummy.pl 1.0.0\n\n";
        print "This plugin will simply return the state corresponding to the numeric value
of the <state> argument with text1 as output data and text2 as performance data.\n\nUsage: check_dummy.pl <state> <text1> <text2>\n\n";
        exit (0);
}

if (!$statuses{$ARGV[0]})
{
        print "UNKNOWN - Only 0, 1, 2, 3 status codes allowed\n";
        exit (3);
}

print $statuses{$ARGV[0]} . " - $ARGV[1] | $ARGV[2]\n";
exit($ARGV[0]);
