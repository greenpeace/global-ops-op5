#!/bin/sh
#
# Nagios plugin to check wether Internet is still working or not :)
#
# License: GPL
# Copyright (c) 2007 op5 AB
# Author: Johannes Dagemark <jd@op5.com>
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

print_usage() {
        echo "check_internet.sh: You forgot to specify any websites to check"
        echo ""
        echo "Usage: check_internet.sh [-H] website1 website2 websiteN"
        echo ""
        echo "Options:"
        echo " -h, --help"
        echo "    Print detailed help screen"
        echo " -H, --hostname"
        echo "    Websites to check for"
        echo ""
        echo "Example:"
        echo "check_internet.sh www.op5.com www.linux.org www.un.org"
        echo ""
        echo "You can define as many hosts as you like. As long as one"
        echo "host is up, Internet is up"
        echo ""
}

# Make sure the correct number of command line
# arguments have been supplied

if [ $# -lt 1 ]; then
        print_usage
        exit 3
fi

while test -n "$1"; do
    case "$1" in
        --help)
            print_usage
            exit 0
            ;;
        -h)
            print_usage
            exit 0
            ;;
        --hostname)
            shift
            SITES=$@
            shift
            ;;
        -H)
            shift
            SITES=$@
            shift
            ;;
        *)
            SITES=$@
            shift
            ;;
    esac
    shift
done

for host in $SITES; do
    /opt/plugins/check_http -H $host -t 5 >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "Internet is UP, $host responded"
                exit 0
        fi
done
echo "Internet is Down, none of checked hosts: $SITES responded"
exit 2

