#!/bin/bash
#Author: Larry Titus
#Date: December 1st 2016
#Reference: https://kb.op5.com/display/HOWTOs/Using+eventhandlers+to+restart+services

state=$1
statetype=$2
host=$3
username=$4
password=$5

logfile=/opt/monitor/var/eventhandler.log

# Oct 13 2014 14:59:44 GMT
date=`date +"%b %d %Y %H:%M:%S %Z"`
case "$1" in
WARNING)
if [ "$statetype" = "HARD" ] ; then
/bin/echo -e "$date vmware_snapshot_report.sh: Got $state and sending report of old snapshots on host $host " >> $logfile
/opt/plugins/custom/check_snapshot.pl --server $host --username $username --password $password > /tmp/snapshots-$host.txt
#/opt/plugins/custom/show-all-vmware-snapshots.pl --server $host --username $username --password $password > /tmp/snapshots-$host.txt
/usr/bin/printf "\nOP5 has detected that host $host has old snapshots. This is a report of snapshots found as of $date."| /usr/bin/mutt -e "my_hdr From: sysop <sysop@greenpeace.org>" -s "[op5] PROBLEM: Old Snapshots found on $host" -i "/tmp/snapshots-$host.txt" global-apps-group@greenpeace.org
/bin/rm /tmp/snapshots-$host.txt

fi
;;
esac
