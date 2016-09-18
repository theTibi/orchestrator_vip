#!/bin/bash


isitdead=$1
cluster=$2
oldmaster=$3
newmaster=$4

interface="eth0"
user="orchuser"

if [[ $cluster =~ "rep" ]]; then

	IP="192.168.56.121"

	if [[ $isitdead == "DeadMaster" ]]; then

		/usr/local/bin/orch_vip.sh -d 1 -n $newmaster -i $interface -I $IP -u $user -o $oldmaster

	fi 
fi
