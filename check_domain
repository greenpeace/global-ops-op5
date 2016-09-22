#!/bin/sh
####################################################
# script to check domain name experation time.
# it works only on UNIX system
# you need to install whois on system
# yum install whois - for centos OS
#
#
#
####################################################
#
PROGRAM=${0##*/}
PROGPATH=${0%/*}
. $PROGPATH/utils.sh


function getmonth() {
       case $month in
             01) echo jan ;;
             02) echo feb ;;
             03) echo mar ;;
             04) echo apr ;;
             05) echo may ;;
             06) echo jun ;;
             07) echo jul ;;
             08) echo aug ;;
             09) echo sep ;;
             10) echo oct ;;
             11) echo nov ;;
             12) echo dec ;;
               *) echo  0 ;;
       esac
}

####################################################
#			default days						####
if [ -z $4 ];
then
	warning=30
else warning=$4
fi

if [ -z $6 ];
then
	critical=7
else critical=$6
fi

#
####################################################
#			arguments from utils.sh				####
domain=$2

####################################################
#			Checking if you have whois			####
WHOIS=/usr/bin/whois
if [ ! -e $WHOIS ];
then
	echo "Please yum install whois"
	exit
fi

####################################################
#		Checking if script can be executed		####
if [ -z $? ] || [ -z $1 ] || [ -z $domain ];
then
	echo "Usage: $PROGRAM -d <domain> [-c <critical>] [-w <warning>]"
	exit
fi

####################################################
#	checking .name	and defining whois server	####
DLTYPE=`echo $domain | cut -d '.' -f2`
if [ ${DLTYPE} == 'com' ] || [ ${DLTYPE} == 'edu' ] || [ ${DLTYPE} == 'net' ];
then
	TYPE=internic
	WHOIS_SERVER="whois.internic.org"
elif [ ${DLTYPE} == 'org' ];
then
	TYPE=pir
	WHOIS_SERVER="whois.pir.org"
elif [ ${DLTYPE} == 'in' ];
then
	TYPE=in
	WHOIS_SERVER="whois.registry.in"
elif [ ${DLTYPE} == 'co' ];
then
	TYPE=nic
	WHOIS_SERVER="whois.nic.uk"
elif [ ${DLTYPE} == 'biz' ];
then
	TYPE=neulevel
	WHOIS_SERVER="whois.neulevel.biz"
elif [ ${DLTYPE} == 'info' ];
then
	TYPE=afilias
	WHOIS_SERVER="whois.afilias.info"
elif [ ${DLTYPE} == 'ru' ];
then
	TYPE=russia
	WHOIS_SERVER="whois.nic.ru"
elif [ ${DLTYPE} == 'dk' ];
then
	TYPE=dk-hostmaster
	WHOIS_SERVER="whois.dk-hostmaster.dk"
elif [ ${DLTYPE} == 'se' ];
then
    TYPE=iis
    WHOIS_SERVER="whois.iis.se"
elif [ ${DLTYPE} == 'fi' ];
then
    TYPE=ficora
    WHOIS_SERVER="whois.ficora.fi"
elif [ ${DLTYPE} == 'ie' ];
then
    TYPE=domainregistry-ie
    WHOIS_SERVER="whois.domainregistry.ie"
elif [ ${DLTYPE} == 'us' ];
then
    TYPE=nic-us
    WHOIS_SERVER="whois.nic.us"
elif [ ${DLTYPE} == 'cn' ];
then
    TYPE=cnnic
    WHOIS_SERVER="whois.cnnic.cn"
elif [ ${DLTYPE} == 'nu' ];
then
    TYPE=nunames
    WHOIS_SERVER="whois.nic.nu"
else
	echo "We do not support this domain (not integrated). Sorry."
	exit $STATE_UNKNOWN
fi

####################################################
#			do whois							####

FILE=/tmp/domain_$2.txt
out=`$WHOIS -h $WHOIS_SERVER $domain > $FILE`

####################################################
#			expiration formats					####

# for domains .com, .edu, .net #
if [ $TYPE == 'internic' ];
then
expiration=`cat ${FILE} | awk '/Expiration Date:/' | cut -d ':' -f2`
# for .org domains
elif [ $TYPE == 'pir' ];
then
expiration=`cat ${FILE} | awk '/Expiration Date:/' | cut -d ':' -f2 | cut -d ' ' -f1`
# for .in domains
elif [ $TYPE == 'in' ];
then
expiration=`cat ${FILE} | awk '/Expiration Date:/' | cut -d ':' -f2 | cut -d ' ' -f1`
# for co.uk domains
elif [ $TYPE == 'nic' ];
then
expiration=`cat ${FILE} | awk '/Expiry date:/' | cut -d ':' -f2`
# for .biz domains
elif [ $TYPE == 'neulevel' ];
then
month=`cat ${FILE} | awk '/Domain Expiration Date:/' | cut -d ' ' -f26`
day=`cat ${FILE} | awk '/Domain Expiration Date:/' | cut -d ' ' -f27`
year=`cat ${FILE} | awk '/Domain Expiration Date:/' | cut -d ' ' -f30`
expiration=$day-$month-$year
# for .info domains
elif [ $TYPE == 'afilias' ];
then
expiration=`cat ${FILE} | awk '/Expiration Date:/' | cut -d ':' -f2 | cut -d ' ' -f1`
#for .ru domains
elif [ $TYPE == 'russia' ];
then
day=`cat ${FILE} | awk '/paid-till:/' | cut -d ':' -f2 | cut -d '.' -f3`
month=`cat ${FILE} | awk '/paid-till:/' | cut -d ':' -f2 | cut -d '.' -f2`
year=`cat ${FILE} | awk '/paid-till:/' | cut -d ':' -f2 | cut -d ' ' -f5 | cut -d '.' -f1`
expiration=$day-$(getmonth ${2})-$year
#for .dk domains
elif [ $TYPE == 'dk-hostmaster' ];
then
day=`cat ${FILE} | awk '/Expires:/' | cut -d '-' -f3`
month=`cat ${FILE} | awk '/Expires:/' | cut -d '-' -f2`
year=`cat ${FILE} | awk '/Expires:/' | cut -d ' ' -f15 | cut -d '-' -f1`
expiration=$day-$(getmonth ${2})-$year
#for .se domains
elif [ $TYPE == 'iis' ];
then
dos2unix -q $FILE
day=`cat ${FILE} | awk '/expires:/' | cut -d ':' -f2 | cut -d '-' -f3`
month=`cat ${FILE} | awk '/expires:/' | cut -d ':' -f2 | cut -d '-' -f2`
year=`cat ${FILE} | awk '/expires:/' | sed 's/^[a-zA-Z\ :]*//g' | cut -d '-' -f1`
expiration=$day-$(getmonth ${2})-$year
#for .fi domains
elif [ $TYPE == 'ficora' ];
then
dos2unix -q $FILE
day=`cat ${FILE} | awk '/expires:/' | cut -d ':' -f2 | cut -d '.' -f1`
month=`cat ${FILE} | awk '/expires:/' | cut -d ':' -f2 | cut -d '.' -f2`
year=`cat ${FILE} | awk '/expires:/' | cut -d ':' -f2 | cut -d '.' -f3`
expiration=$day-$(getmonth ${2})-$year
#for .ie domains
elif [ $TYPE == 'domainregistry-ie' ];
then
expiration=`cat ${FILE} | awk '/renewal:/' | cut -d ':' -f2`
#for .us domains
elif [ $TYPE == 'nic-us' ];
then
expiration=`cat ${FILE} | awk '/Domain Expiration Date:/ {print $6 "-" $5 "-" $9}'`
#for .cn domains
elif [ $TYPE == 'cnnic' ];
then
day=`cat ${FILE} | awk '/Expiration Date:/' | cut -d ' ' -f3 | cut -d '-' -f3`
month=`cat ${FILE} | awk '/Expiration Date:/' | cut -d ' ' -f3 | cut -d '-' -f2`
year=`cat ${FILE} | awk '/Expiration Date:/' | cut -d ' ' -f3 | cut -d '-' -f1`
expiration=$day-$(getmonth ${2})-$year
#for .nu domains
elif [ $TYPE == 'nunames' ];
then
day=`cat ${FILE} | awk '/Record expires on/ {print  $4 }' | cut -d '-' -f3 | sed 's/\.//'`
month=`cat ${FILE} | awk '/Record expires on/ {print  $4 }' | cut -d '-' -f2`
year=`cat ${FILE} | awk '/Record expires on/ {print  $4 }' | cut -d '-' -f1`
expiration=$day-$month-$year

fi
rm $FILE

####################################################
#			if can't get expiration time		####
if [ -z $expiration ];
then
	echo "UNKNOWN - can not retrieve expiration time"
	exit $STATE_UNKNOWN
fi

####################################################
#			expiration counting					####
expiration_date=$(date +%s --date="$expiration")
NOW=$(date +%s)
DAYSLEFT=$((($expiration_date-$NOW)/86400))

####################################################
#				alerts							####
if [ $DAYSLEFT -lt 0 ];
then
	echo "CRITICAL - Domain is expired"
	exit $STATE_CRITICAL
elif [ $DAYSLEFT -lt $critical ];
then
	echo "CRITICAL - Domain will expire in $DAYSLEFT days"
	exit $STATE_CRITICAL
elif [ $DAYSLEFT -lt $warning ];
then
	echo "WARNING - Domain will expire after $DAYSLEFT days on $expiration"
	exit $STATE_WARNING
fi

echo "OK - Domain will expire on $expiration"
exit $STATE_OK
