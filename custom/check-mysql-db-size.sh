#!/bin/bash
## script to check database size

if [ $# -ne "2" ]; then
    echo "Usage: `basename $0` mysql_config_file database_name"
    exit
fi

cnf_file=$1
db_name=$2

db_size=$(mysql --defaults-file=$1 -sN -e "SELECT ROUND(SUM(data_length + index_length) / 1024 /1024,0) FROM information_schema.TABLES WHERE table_schema=\"$2\" GROUP BY table_schema")

if [[ ! -z $db_size ]]; then
    echo "OK. $2 database size is ${db_size}MB | db_size=$db_size"
    exit 0
else
    echo "ERROR. Unable to get database size for $2"
    exit 1
fi

exit
