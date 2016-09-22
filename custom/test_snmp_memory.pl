#!/bin/bash

# check_snmp_memory
# Description : Checks memory and swap usage on Windows/Linux Server
# Version : 1.9
# Author : Yoann LAMY
# Licence : GPLv2

# Commands
CMD_BASENAME="/bin/basename"
CMD_SNMPGET="/usr/bin/snmpget"
CMD_SNMPWALK="/usr/bin/snmpwalk"
CMD_AWK="/bin/awk"
CMD_GREP="/bin/grep"
CMD_BC="/usr/bin/bc"
CMD_EXPR="/usr/bin/expr"

# Script name
SCRIPTNAME=`$CMD_BASENAME $0`

# Version
VERSION="1.9"

# Plugin return codes
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

# 'hrStorageDescr', HOST-RESOURCES-MIB
OID_TAGMEMORY=".1.3.6.1.2.1.25.2.3.1.3"

# 'hrStorageAllocationUnits', HOST-RESOURCES-MIB
OID_UNIT=".1.3.6.1.2.1.25.2.3.1.4"

# 'hrStorageSize', HOST-RESOURCES-MIB
OID_TOTAL=".1.3.6.1.2.1.25.2.3.1.5"

# 'hrStorageUsed', HOST-RESOURCES-MIB
OID_USED=".1.3.6.1.2.1.25.2.3.1.6"

# 'memBuffer', UCD-SNMP-MIB
OID_BUFFER=".1.3.6.1.4.1.2021.4.14.0"

# 'memCached', UCD-SNMP-MIB
OID_CACHE=".1.3.6.1.4.1.2021.4.15.0"

# Default variables
DESCRIPTION="Unknown"
STATE=$STATE_UNKNOWN

# Default options
COMMUNITY="public"
HOSTNAME="127.0.0.1"
VERSION="3"
LEVEL="authPriv"
USERNAME="op5user"
AUTH_PROTOCOL="SHA"
AUTH_PASSWORD="OBmepCbIHQW1TRI"
PRIV_PROTOCOL="AES"
PRIV_PASSWORD="OBmepCbIHQW1TRI"
WARNING=0
CRITICAL=0

# Option processing
print_usage() {
  echo "Usage: ./check_snmp_memory -H 127.0.0.1 -C public -w 80 -c 90"
  echo "  $SCRIPTNAME -H ADDRESS"
  echo "  $SCRIPTNAME -C STRING"
  echo "  $SCRIPTNAME -w INTEGER"
  echo "  $SCRIPTNAME -c INTEGER"
  echo "  $SCRIPTNAME -v STRING"
  echo "  $SCRIPTNAME -l STRING"
  echo "  $SCRIPTNAME -u STRING"
  echo "  $SCRIPTNAME -a STRING"
  echo "  $SCRIPTNAME -A STRING"
  echo "  $SCRIPTNAME -x STRING"
  echo "  $SCRIPTNAME -X STRING"
  echo "  $SCRIPTNAME -h"
  echo "  $SCRIPTNAME -V"
}

print_version() {
  echo $SCRIPTNAME version $VERSION
  echo ""
  echo "This nagios plugins come with ABSOLUTELY NO WARRANTY."
  echo "You may redistribute copies of the plugins under the terms of the GNU General Public License v2."
}

print_help() {
  print_version
  echo ""
  print_usage
  echo ""
  echo "Checks memory and swap usage on Windows or Linux Server"
  echo ""
  echo "-H ADDRESS"
  echo "   Name or IP address of host (default: 127.0.0.1)"
  echo "-C STRING"
  echo "   Community name for the host's SNMP agent (default: public)"
  echo "-w INTEGER"
  echo "   Warning level for memory usage in percent (default: 0)"
  echo "-c INTEGER"
  echo "   Critical level for memory usage in percent (default: 0)"
  echo "-h"
  echo "   Print this help screen"
  echo "-V"
  echo "   Print version and license information"
  echo ""
  echo ""
  echo "This plugin uses the 'snmpget' command included with the NET-SNMP package."
  echo "This plugin support performance data output."
  echo "If the percentage of the warning and critical levels are set to 0, then the script returns a OK state."
}

while getopts H:C:w:c:v:l:u:a:A:x:X:hV OPT
do
  case $OPT in
    H) HOSTNAME="$OPTARG" ;;
    C) COMMUNITY="$OPTARG" ;;
    w) WARNING=$OPTARG ;;
    c) CRITICAL=$OPTARG ;;
    v) COMMUNITY="$OPTARG" ;;
    l) COMMUNITY="$OPTARG" ;;
    u) COMMUNITY="$OPTARG" ;;
    a) COMMUNITY="$OPTARG" ;;
    A) COMMUNITY="$OPTARG" ;;
    x) COMMUNITY="$OPTARG" ;;
    X) COMMUNITY="$OPTARG" ;;
    h)
      print_help
      exit $STATE_UNKNOWN
      ;;
    V)
      print_version
      exit $STATE_UNKNOWN
      ;;
   esac
done

# Plugin processing
size_convert() {
  if [ $VALUE -ge 1073741824 ]; then
    VALUE=`echo "scale=2 ; ( ( $VALUE / 1024 ) / 1024 ) / 1024" | $CMD_BC`
    VALUE="$VALUE GB"
  elif [ $VALUE -ge 1048576 ]; then
    VALUE=`echo "scale=2 ; ( $VALUE / 1024 ) / 1024" | $CMD_BC`
    VALUE="$VALUE MB"
  elif [ $VALUE -ge 1024 ]; then
    VALUE=`echo "scale=2 ; $VALUE / 1024" | $CMD_BC`
    VALUE="$VALUE KB"
  else
    VALUE="$VALUE Octets"
  fi
}

MEMORY_USED_ID=`$CMD_SNMPWALK -t 2 -r 2 -v $VERSION -c $COMMUNITY -u $USERNAME -a $AUTH_PROTOCOL -A $AUTH_PASSWORD -x $PRIV_PROTOCOL -X $PRIV_PASSWORD $HOSTNAME $OID_TAGMEMORY | $CMD_GREP -i 'Physical Memory\|Real Memory' | $CMD_AWK '{ print $1}' | $CMD_AWK -F "." '{print $NF}'`
if [ -n "$MEMORY_USED_ID" ]; then
  SWAP_USED_ID=`$CMD_SNMPWALK -t 2 -r 2 -v $VERSION -c $COMMUNITY -u $USERNAME -a $AUTH_PROTOCOL -A $AUTH_PASSWORD -x $PRIV_PROTOCOL -X $PRIV_PASSWORD $HOSTNAME $OID_TAGMEMORY | $CMD_GREP -i 'Swap Space' | $CMD_AWK '{ print $1}' | $CMD_AWK -F "." '{print $NF}'`
  if [ -z "$SWAP_USED_ID" ]; then
    SWAP_USED_ID=`$CMD_SNMPWALK -t 2 -r 2 -v $VERSION -c $COMMUNITY -u $USERNAME -a $AUTH_PROTOCOL -A $AUTH_PASSWORD -x $PRIV_PROTOCOL -X $PRIV_PASSWORD $HOSTNAME $OID_TAGMEMORY | $CMD_GREP -i 'Virtual Memory' | $CMD_AWK '{ print $1}' | $CMD_AWK -F "." '{print $NF}'`
  fi
  MEMORY_TOTAL=`$CMD_SNMPGET -t 2 -r 2 -v $VERSION -c $COMMUNITY -u $USERNAME -a $AUTH_PROTOCOL -A $AUTH_PASSWORD -x $PRIV_PROTOCOL -X $PRIV_PASSWORD -OvqU $HOSTNAME ${OID_TOTAL}.${MEMORY_USED_ID}`
  SWAP_TOTAL=`$CMD_SNMPGET -t 2 -r 2 -v $VERSION -c $COMMUNITY -u $USERNAME -a $AUTH_PROTOCOL -A $AUTH_PASSWORD -x $PRIV_PROTOCOL -X $PRIV_PASSWORD -OvqU $HOSTNAME ${OID_TOTAL}.${SWAP_USED_ID}`
  MEMORY_UNIT=`$CMD_SNMPGET -t 2 -r 2 -v $VERSION -c $COMMUNITY -u $USERNAME -a $AUTH_PROTOCOL -A $AUTH_PASSWORD -x $PRIV_PROTOCOL -X $PRIV_PASSWORD -OvqU $HOSTNAME ${OID_UNIT}.${MEMORY_USED_ID}`
  SWAP_UNIT=`$CMD_SNMPGET -t 2 -r 2 -v $VERSION -c $COMMUNITY -u $USERNAME -a $AUTH_PROTOCOL -A $AUTH_PASSWORD -x $PRIV_PROTOCOL -X $PRIV_PASSWORD -OvqU $HOSTNAME ${OID_UNIT}.${SWAP_USED_ID}`
  MEMORY_USED=`$CMD_SNMPGET -t 2 -r 2 -v $VERSION -c $COMMUNITY -u $USERNAME -a $AUTH_PROTOCOL -A $AUTH_PASSWORD -x $PRIV_PROTOCOL -X $PRIV_PASSWORD -OvqU $HOSTNAME ${OID_USED}.${MEMORY_USED_ID}`
  SWAP_USED=`$CMD_SNMPGET -t 2 -r 2 -v $VERSION -c $COMMUNITY -u $USERNAME -a $AUTH_PROTOCOL -A $AUTH_PASSWORD -x $PRIV_PROTOCOL -X $PRIV_PASSWORD -OvqU $HOSTNAME ${OID_USED}.${SWAP_USED_ID}`

  BUFFER_USED=`$CMD_SNMPGET -t 2 -r 2 -v $VERSION -c $COMMUNITY -u $USERNAME -a $AUTH_PROTOCOL -A $AUTH_PASSWORD -x $PRIV_PROTOCOL -X $PRIV_PASSWORD -OvqU $HOSTNAME ${OID_BUFFER} 2> /dev/null`
  CACHE_USED=`$CMD_SNMPGET -t 2 -r 2 -v $VERSION -c $COMMUNITY -u $USERNAME -a $AUTH_PROTOCOL -A $AUTH_PASSWORD -x $PRIV_PROTOCOL -X $PRIV_PASSWORD -OvqU $HOSTNAME ${OID_CACHE} 2> /dev/null`

  if [ -n "$MEMORY_TOTAL" ] && [ -n "$MEMORY_USED" ] && [ -n "$SWAP_TOTAL" ] && [ -n "$SWAP_USED" ]; then
    MEMORY_USED=`$CMD_EXPR \( $MEMORY_USED \* $MEMORY_UNIT \)`
    SWAP_USED=`$CMD_EXPR \( $SWAP_USED \* $SWAP_UNIT \)`
    MEMORY_TOTAL=`$CMD_EXPR \( $MEMORY_TOTAL \* $MEMORY_UNIT \)`
    SWAP_TOTAL=`$CMD_EXPR \( $SWAP_TOTAL \* $SWAP_UNIT \)`
    MEMORY_USED_POURCENT=`$CMD_EXPR \( $MEMORY_USED \* 100 \) / $MEMORY_TOTAL`
    SWAP_USED_POURCENT=`$CMD_EXPR \( $SWAP_USED \* 100 \) / $SWAP_TOTAL`
    PERFDATA_WARNING=0
    PERFDATA_CRITICAL=0

    if [ -z "$BUFFER_USED" ] && [ -z "$CACHE_USED" ]; then
      BUFFER_USED=0
      CACHE_USED=0
    else
      BUFFER_USED=`$CMD_EXPR \( $BUFFER_USED \* 1024 \)`
      CACHE_USED=`$CMD_EXPR \( $CACHE_USED \* 1024 \)`
    fi

    if [ $WARNING != 0 ] || [ $CRITICAL != 0 ]; then
      PERFDATA_WARNING=`$CMD_EXPR \( $MEMORY_TOTAL \* $WARNING \) / 100`
      PERFDATA_CRITICAL=`$CMD_EXPR \( $MEMORY_TOTAL \* $CRITICAL \) / 100`

      MEMORY_USED_REAL=`$CMD_EXPR \( $MEMORY_USED - $CACHE_USED \)`
      MEMORY_USED_REAL_POURCENT=`$CMD_EXPR \( $MEMORY_USED_REAL \* 100 \) / $MEMORY_TOTAL`

      if [ $MEMORY_USED_REAL_POURCENT -gt $CRITICAL ] && [ $CRITICAL != 0 ]; then
        STATE=$STATE_CRITICAL
      elif [ $MEMORY_USED_REAL_POURCENT -gt $WARNING ] && [ $WARNING != 0 ]; then
        STATE=$STATE_WARNING
      else
        STATE=$STATE_OK
      fi

    else
      STATE=$STATE_OK
    fi

    VALUE=$MEMORY_TOTAL
    size_convert
    MEMORY_TOTAL_FORMAT=$VALUE

    VALUE=$MEMORY_USED
    size_convert
    MEMORY_USED_FORMAT=$VALUE

    VALUE=$BUFFER_USED
    size_convert
    BUFFER_USED_FORMAT=$VALUE

    VALUE=$CACHE_USED
    size_convert
    CACHE_USED_FORMAT=$VALUE

    VALUE=$SWAP_TOTAL
    size_convert
    SWAP_TOTAL_FORMAT=$VALUE

    VALUE=$SWAP_USED
    size_convert
    SWAP_USED_FORMAT=$VALUE

    DESCRIPTION="Memory usage : $MEMORY_USED_FORMAT used for a total of $MEMORY_TOTAL_FORMAT (${MEMORY_USED_POURCENT}%)"
    if [ "$BUFFER_USED" = 0 ] && [ "$CACHE_USED" = 0 ]; then
      DESCRIPTION="${DESCRIPTION}, SWAP usage : $SWAP_USED_FORMAT used for a total of $SWAP_TOTAL_FORMAT (${SWAP_USED_POURCENT}%)"
    else
      DESCRIPTION="$DESCRIPTION with $BUFFER_USED_FORMAT in buffer and $CACHE_USED_FORMAT in cache, SWAP usage : $SWAP_USED_FORMAT used for a total of $SWAP_TOTAL_FORMAT (${SWAP_USED_POURCENT}%)"
    fi

    DESCRIPTION="${DESCRIPTION}| total=${MEMORY_TOTAL}B;$PERFDATA_WARNING;$PERFDATA_CRITICAL;0 used=${MEMORY_USED}B;0;0;0 swap=${SWAP_USED}B;0;0;0 buffer=${BUFFER_USED}B;0;0;0 cache=${CACHE_USED}B;0;0;0"
  fi
fi

echo $DESCRIPTION
exit $STATE
