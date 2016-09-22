#!/bin/bash
# License: GPL
# Copyright (C) 2008 op5 AB
# Author: Henrik Nilsson <henrik30000@gmail.com>
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

function check_range
{
  range="$1"
  value="$2"
  inside=0
  if [ "${range:0:1}" = '@' ]; then
    inside=1
    range="${range:1}"
  fi
  endrange="${range#*:}"
  if [ "$range" != "${range%:*}" ]; then
    range="${range%:*}"
    if [ "$range" != "~" ] && [ "$value" -lt "$range" ]; then return $((1-${inside})); fi
  else
    if [ "$value" -lt 0 ]; then return $((1-${inside})); fi # No ":end", so the only value will be end and start defaults to 0
    endrange="$range"
  fi
  if [ ! -z "$endrange" ]; then # infinity
    if [ "$value" -gt "$endrange" ]; then return $((1-${inside}))
    else return "$inside"; fi
  fi
  return inside;
}

# Parse commandline arguments
flag=""
for arg in $@; do
  if [ "$flag" = "-w" ]; then
    warningage="$arg"
    flag=""
  elif [ "$flag" = "-c" ]; then
    criticalage="$arg"
    flag=""
  elif [ "$flag" = "-t" ]; then
    (sleep "$arg"; kill -9 "$$") &
    flag=""
  else
    if [ "$arg" = "-w" -o "$arg" = "--warning" ]; then flag="-w"; fi
    if [ "$arg" = "-c" -o "$arg" = "--critical" ]; then flag="-c"; fi
    if [ "$arg" = "-t" -o "$arg" = "--timeout" ]; then flag="-t"; fi
    if [ "$arg" = "-h" -o "$arg" = "--help" ]; then
      echo "Flags:"
      echo "-w/--warning [range]   Trigger a warning if the age in days of"
      echo "                       the last backup goes outside of the range."
      echo "                       Default: 0:7"
      echo "-c/--critical [range]  Trigger a critical status if the age in"
      echo "                       days of the last backup goes outside of"
      echo "                       the range. Default: 0:14"
      echo "-h/--help              Show this help text"
      echo "-t/--timeout [x]       Make the check timeout after x seconds"
    fi
  fi
done

[ -z "$warningage" ] && warningage="0:7" # Default to a week
[ -z "$criticalage" ] && criticalage="0:14" # Default to two weeks

if [ -r /etc/op5backup.conf ]; then
  source /etc/op5backup.conf
fi
# Fill in defaults
[ -z "$transfer" ] && transfer="local"
[ -z "$storagepath" ] && storagepath="/root/"
[ -z "$excludedate" ] && excludedate="no"
[ -z "$backupfilename" ] && backupfilename="$HOSTNAME-Backup"

# Escape special characters
hostname="$(echo "$HOSTNAME" | sed -e "s/\\\\/\\\\\\\\/g;s/\./\\./g;")"
if [ -r /var/log/cron ]; then
  logstatus="$(grep "[a-zA-Z]* [0-9: ]* $hostname op5backup:" /var/log/cron | tail -n 1)"
fi

# Check last status report for failure
echo "$logstatus" | grep "[Ff]ail" && (
echo -n "OP5BACKUP CRITICAL - "
echo "$logstatus" | sed -e "s/^.* op5backup: //;"
[ "$(jobs | grep "^\[1\]")" != "" ] && kill %1
exit 2
)

# Check that the backup file exists
if [ "$transfer" = "ftp" ]; then
  if [ "$excludedate" != "yes" ]; then backupfilename="${backupfilename}-*"; fi
  backupfiles="$((lftp -e "set net:max-retries 3 && open $backupserver/$backuppath -u $backupuser,$backuppass || quit 1; \
    ls */${backupfilename}.tar.gz; quit 0"; ret="$?") | sort | tail -n 1 | sed -e "s/^.* //;")"
  if [ "$ret" != "0" ]; then
    echo "OP5BACKUP UNKNOWN - Failed to login to the FTP server where backups are stored"
    [ "$(jobs | grep "^\[1\]")" != "" ] && kill %1
    exit 3
  fi
  if [ -z "$backupfiles" ]; then
    if [ "$logstatus" = "" ]; then # No backup seems to have run yet
      echo "OP5BACKUP WARNING - No backup files found"
      [ "$(jobs | grep "^\[1\]")" != "" ] && kill %1
      exit 1
    else
      echo "OP5BACKUP CRITICAL - No backup files found"
      [ "$(jobs | grep "^\[1\]")" != "" ] && kill %1
      exit 2
    fi
  fi
  backupage="$((($(date +%s)-$(date -d "${backupfiles%/*}" +%s))/86400))"
else
  if [ "$excludedate" = "yes" ]; then
    if [ ! -e "${storagepath}/${backupfilename}.tar.gz" ]; then
      if [ "$logstatus" = "" ]; then # No backup seems to have run yet
        echo "OP5BACKUP WARNING - No backup file found"
        [ "$(jobs | grep "^\[1\]")" != "" ] && kill %1
        exit 1
      else
        echo "OP5BACKUP CRITICAL - No backup file found"
        [ "$(jobs | grep "^\[1\]")" != "" ] && kill %1
        exit 2
      fi
    fi
    backupage="$((($(date +%s)-$(stat -c %Y "${storagepath}/${backupfilename}.tar.gz"))/86400))"
  else
    if [ ! -x "$storagepath" ]; then
      echo "OP5BACKUP UNKNOWN - Cannot list files in storagepath"
      [ "$(jobs | grep "^\[1\]")" != "" ] && kill %1
      exit 3
    fi
    lastbackup="$(find "${storagepath}" -name "${backupfilename}-*.tar.gz" | sort | tail -n 1)"
    if [ -z "$lastbackup" ]; then
      if [ "$logstatus" = "" ]; then # No backup seems to have run yet
        echo "OP5BACKUP WARNING - No backup files found"
        [ "$(jobs | grep "^\[1\]")" != "" ] && kill %1
        exit 1
      else
        echo "OP5BACKUP CRITICAL - No backup files found"
        [ "$(jobs | grep "^\[1\]")" != "" ] && kill %1
        exit 2
      fi
    fi
    backupage="$((($(date +%s)-$(stat -c %Y "${lastbackup}"))/86400))"
  fi
fi

# Check if the backup is recent enough
check_range "$criticalage" "$backupage"
if [ "$?" != "0" ]; then
  echo -n "OP5BACKUP CRITICAL - Latest backup is too old"
  echo " |'backup age'=${backupage} days;${warningage};${criticalage};0"
  [ "$(jobs | grep "^\[1\]")" != "" ] && kill %1
  exit 2
fi
check_range "$warningage" "$backupage"
if [ "$?" != "0" ]; then
  echo -n "OP5BACKUP WARNING - Latest backup is old"
  echo " |'backup age'=${backupage} days;${warningage};${criticalage};0"
  [ "$(jobs | grep "^\[1\]")" != "" ] && kill %1
  exit 1
fi

if [ -z "$logstatus" ]; then
  logstatus="Latest backup is recent enough"
fi
echo -n "OP5BACKUP OK - "
echo -n "$logstatus" | sed -e "s/^.* op5backup: //;"
echo " |'backup age'=${backupage} days;${warningage};${criticalage};0"
[ "$(jobs | grep "^\[1\]")" != "" ] && kill %1
exit 0
