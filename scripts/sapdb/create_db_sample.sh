#!/bin/sh
###
# 		dont start script as root!
#		--------------------------
#
# create example database TST with (only for seperated packages - sapdb-ind, sapdb-srv, sapdb-testdb):
#   - 20 MB data devspace and 8 MB log devspace
#   - demo database user test (with password test)
###


id=`id | sed s/\(.*// | sed s/uid=//`

if [ "$id" = "0" ]; then
	echo "dont start script as root"
	exit 1
fi 

export PATH=/opt/sapdb/indep_prog/bin:$PATH
#set -x

# name of the database
SID=DBT2

# start remote communication server
echo "start communication server..."
x_server start >/dev/null 2>&1

# stop and drop probably existing demo database
echo "stop and drop existing $SID..."
dbmcli -d $SID -u dbm,dbm db_offline >/dev/null 2>&1
dbmcli -d $SID -u dbm,dbm db_drop >/dev/null 2>&1

# create new demo database
echo "create database $SID..."
_o=`/opt/sapdb/depend/bin/dbmcli -s -R /opt/sapdb/depend db_create $SID dbm,dbm 2>&1`
_test=`echo $_o | grep OK`
if [ "$_test" = "" ]; then
	echo "create $SID failed: $_o"
	exit 1
fi

# create directory where to put the database files
mkdir -p $HOME/$SID

# setup database parameters
echo "set parameters for $SID..."
_o=`cat <<EOF | dbmcli -d $SID -u dbm,dbm 2>&1
param_rmfile
param_startsession
param_init
param_put LOG_MODE SINGLE
param_put CAT_CACHE_SUPPLY 300
param_put DATA_CACHE 25000
param_put MAXDATADEVSPACES 5
param_put MAXDATAPAGES 4096000
param_put _PACKET_SIZE 131072
param_put _IDXFILE_LIST_SIZE 8192
param_put MAXLOCKS 5000
param_put MAXCPU 1
param_put _RESTART_TIME 100000
param_checkall
param_commitsession
param_adddevspace 1 SYS  $HOME/$SID/SYS_001   F
param_adddevspace 1 DATA $HOME/$SID/DATA_001 F 81920
param_adddevspace 1 LOG  $HOME/$SID/LOG_001  F 40960
quit
EOF`
_test=`echo $_o | grep OK`
if [ "$_test" = "" ]; then
        echo "set parameters failed: $_o"
        exit 1
fi


# startup database
echo "start $SID..."
_o=`dbmcli -d $SID -u dbm,dbm db_start 2>&1`
_test=`echo $_o | grep OK`
if [ "$_test" = "" ]; then
        echo "start $SID failed: $_o"
        exit 1
fi


# initialize database files
echo "initializing $SID..."
_o=`cat <<EOF | dbmcli -d $SID -u dbm,dbm 2>&1
util_connect dbm,dbm
util_execute init config
util_activate dba,dba
quit
EOF`
_test=`echo $_o | grep OK`
if [ "$_test" = "" ]; then
        echo "initialize $SID failed: $_o"
        exit 1
fi

# load database system tables
echo "load system tables..."
_o=`dbmcli -d $SID -u dbm,dbm load_systab -u dba,dba -ud domain 2>&1`
_test=`echo $_o | grep OK`
if [ "$_test" = "" ]; then
        echo "load system tables failed: $_o"
        exit 1
fi

# create database demo user
echo "create database demo user..."
_o=`cat <<EOF | dbmcli -d $SID -u dba,dba 2>&1
sql_connect dba,dba
sql_execute CREATE USER dbt PASSWORD dbt DBA NOT EXCLUSIVE
EOF`
_test=`echo $_o | grep OK`
if [ "$_test" = "" ]; then
        echo "create db user failed: $_o"
        exit 1
fi

echo "set backup parameters..."
_o=`cat <<EOF | dbmcli -d $SID -u dbm,dbm 2>&1
backup_media_put data $HOME/$SID/datasave FILE DATA 0 8 YES
backup_media_put auto $HOME/$SID/autosave FILE AUTO
backup_media_put trash $HOME/$SID/trash FILE DATA 0 8 YES
util_connect dbm,dbm
backup_save data
autosave_on
quit
EOF`
_test=`echo $_o | grep OK`
if [ "$_test" = "" ]; then
        echo "set backup parameters failed: $_o"
        exit 1
fi


exit 0
