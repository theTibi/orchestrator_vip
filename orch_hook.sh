#!/bin/bash


isitdead=$1
cluster=$2
oldmaster=$3
newmaster=$4

logfile="/var/log/orch_hook.log"

# list of clusternames
clusternames=(rep blea lajos)

# clustername=( interface IP user)
rep=( eth0 "192.168.56.121" orchuser )
#prod1=( eth1 "10.20.10.5" vipuser )


if [[ $isitdead == "DeadMaster" ]]; then

	array=$cluster
	interface=$array[0]
	IP=$array[1]
	user=$array[2]

	if [ ! -z ${!IP} ] ; then

		echo "/usr/local/bin/orch_vip.sh -d 1 -n $newmaster -i ${!interface} -I ${!IP} -u ${!user} -o $oldmaster" | tee $logfile
		/usr/local/bin/orch_vip.sh -d 1 -n $newmaster -i ${!interface} -I ${!IP} -u ${!user} -o $oldmaster

	else 

		echo "Cluster does not exist!" | tee $logfile

	fi

fi
