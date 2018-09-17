#!/bin/bash
#
DEBUG=0
 
logfile=/var/log/op5/eventhandler.log
 
if [ "$DEBUG" == "1" ]; then
    echo "DEBUG: $0 called with \"$0 $@\"" >> $logfile
fi
 
if [ "$1" == "-h" -o "$#" -ne "5" ]; then
    echo
    echo "Usage: $0 <servicestate> <servicestatetype> <serviceattempts> <jenkinsserver> <token>"
    echo
    echo "       Were servicestate is the SERVICESTATE macro and servicestatetype"
    echo "       is the SERVICESTATETYPE macro from Nagios."
    echo
    echo "       ** This script will exit on all but CRITICAL and HARD **"
    echo
    exit 3
fi
 
SERVICESTATE=$1
SERVICESTATETYPE=$2
SERVICEATTEMPT=$3
JENKINSHOSTNAME=$4
WEBHOOKTOKEN=$5
 
if [ "$SERVICESTATE" != "CRITICAL" -o "$SERVICESTATETYPE" != "HARD" ]; then
    echo "$0 will run for CRITICAL and HARD, not $SERVICESTATE and $SERVICESTATETYPE"
    echo "$0 will run for CRITICAL : HARD, not $SERVICESTATE : $SERVICESTATETYPE." >> $logfile
    exit 1
fi
 
# Call Jenkins server with Webhook token
if [ "$SERVICEATTEMPT" = 1 ]; then
	curl -vs https://"$JENKINSHOSTNAME"/generic-webhook-trigger/invoke?token="$WEBHOOKTOKEN"
	echo "Eventhanlder run: $0 called with \"$0 $@\"" >> $logfile
else
	echo "$0 will run for One time only."
    echo "$0 will run for One time only." >> $logfile
fi

# E.O.F