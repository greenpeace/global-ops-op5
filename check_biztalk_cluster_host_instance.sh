#!/bin/bash

### ### som kollar att MSDTC process som visar vilken server som är aktiv, körs på exakt en av de servrar som anges i argumentet.

SERVICE='BTSSvc$GcCxHost'

if [ $# -ne 1 -o "$1" == "-h" ]; then
    echo "Usage: $1 -h | ip.address,ip.address,ip.address, ..."
    exit
fi

IFS=,


RUNNING=0
for i in $1; do

    status=`/opt/plugins/check_nt -H $i -p 1248 -v SERVICESTATE -l $SERVICE`
    ret=$?

    if [ $ret == 0 ]; then
        RUNNING=$(($RUNNING + 1))
        TEXT="$TEXT$i is running $SERVICE "
    fi

done

if [ $RUNNING == 0 ]; then
    echo "INSTANCES CRITICAL: None running $SERVICE"
    exit 2
elif [ $RUNNING -gt 1 ]; then
    echo "INSTANCES CRITICAL: More than one ($RUNNING) hosts running
$SERVICE! ($TEXT)"
    exit 2
else
    echo "INSTANCES OK: $TEXT"
    exit 0
fi