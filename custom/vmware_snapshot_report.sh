#!/bin/bash
#Author: Larry Titus
#Date: March 20th 2015
#Reference: https://kb.op5.com/display/HOWTOs/Using+eventhandlers+to+restart+services

state=$1
statetype=$2
host=$3
url=$4

logfile=/opt/monitor/var/eventhandler.log

# Oct 13 2014 14:59:44 GMT
date=`date +"%b %d %Y %H:%M:%S %Z"`
case "$1" in
CRITICAL)
if [ "$statetype" = "HARD" ] ; then
/bin/echo -e "$date vmware_snapshot_report.sh: Got $state and sending a snapshot report for host $host " >> $logfile

/opt/plugins/custom/wkhtmltoimage-amd64 $url /tmp/snapshot-$host.jpg > /dev/null 2>&1
/usr/bin/asmonitor /opt/plugins/custom/check_snapshot.pl --server $host --username x --password x

/bin/echo "OP5 has detected that host $host is in state $state. Attached is a screenshot of $url taken on $date."| /usr/bin/mutt -e "my_hdr From: sysop <sysop@greenpeace.org>" -s "[op5] PROBLEM: Screenshot of $url" -a "/tmp/snapshot-$host.jpg" global-apps-group@greenpeace.org

/bin/rm /tmp/snapshot-$host.jpg
fi
;;
esac
