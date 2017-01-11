#!/bin/bash


isitdead=$1
cluster=$2
oldmaster=$3
newmaster=$4
mysqluser="orchestrator"
export MYSQL_PWD="xxxpassxxx"

logfile="/var/log/orch_hook.log"

# list of clusternames
clusternames=(rep blea lajos)

# clustername=( interface IP user Inter_IP)
rep=( eth1 "192.168.56.121" orchuser "192.168.56.125")

if [[ $isitdead == "DeadMaster" ]]; then

	array=$cluster
	interface=$array[0]
	IP=$array[1]
	user=$array[2]

	if [ ! -z ${!IP} ] ; then

		echo $(date)
		echo "Revocering from: $isitdead"
		echo "New master is: $newmaster"
		echo "/usr/local/bin/orch_vip.sh -d 1 -n $newmaster -i ${!interface} -I ${!IP} -u ${!user} -o $oldmaster" | tee $logfile
		/usr/local/bin/orch_vip.sh -d 1 -n $newmaster -i ${!interface} -I ${!IP} -u ${!user} -o $oldmaster
		mysql -h$newmaster -u$mysqluser < /usr/local/bin/orch_event.sql
	else

		echo "Cluster does not exist!" | tee $logfile

	fi
elif [[ $isitdead == "DeadIntermediateMasterWithSingleSlaveFailingToConnect" ]]; then

	array=$cluster
	interface=$array[0]
	IP=$array[3]
	user=$array[2]
	slavehost=`echo $5 | cut -d":" -f1`

	echo $(date)
	echo "Revocering from: $isitdead"
	echo "New intermediate master is: $slavehost"
	echo "/usr/local/bin/orch_vip.sh -d 1 -n $slavehost -i ${!interface} -I ${!IP} -u ${!user} -o $oldmaster" | tee $logfile
	/usr/local/bin/orch_vip.sh -d 1 -n $slavehost -i ${!interface} -I ${!IP} -u ${!user} -o $oldmaster


elif [[ $isitdead == "DeadIntermediateMaster" ]]; then

	array=$cluster
	interface=$array[0]
	IP=$array[3]
	user=$array[2]
	slavehost=`echo $5 | sed -E "s/:[0-9]+//g" | sed -E "s/,/ /g"`
	showslave=`mysql -h$newmaster -u$mysqluser -sN -e "SHOW SLAVE HOSTS;" | awk '{print $2}'`
	newintermediatemaster=`echo $slavehost $showslave | tr ' ' '\n' | sort | uniq -d`

	echo $(date)
	echo "Revocering from: $isitdead"
	echo "New intermediate master is: $newintermediatemaster"
	echo "/usr/local/bin/orch_vip.sh -d 1 -n $newintermediatemaster -i ${!interface} -I ${!IP} -u ${!user} -o $oldmaster" | tee $logfile
	/usr/local/bin/orch_vip.sh -d 1 -n $newintermediatemaster -i ${!interface} -I ${!IP} -u ${!user} -o $oldmaster


fi

