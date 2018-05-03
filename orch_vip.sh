#!/bin/bash

emailaddress="email@example.com"
sendmail=0

function usage {
  cat << EOF
 usage: $0 [-h] [-d master is dead] [-o old master ] [-s ssh options] [-n new master] [-i interface] [-I] [-u SSH user]
 
 OPTIONS:
    -h        Show this message
    -o string Old master hostname or IP address 
    -d int    If master is dead should be 1 otherweise it is 0
    -s string SSH options
    -n string New master hostname or IP address
    -i string Interface exmple eth0:1
    -I string Virtual IP
    -u string SSH user
EOF

}

while getopts ho:d:s:n:i:I:u: flag; do
  case $flag in
    o)
      orig_master="$OPTARG";
      ;;
    d)
      isitdead="${OPTARG}";
      ;;
    s)
      ssh_options="${OPTARG}";
      ;;
    n)
      new_master="$OPTARG";
      ;;
    i)
      interface="$OPTARG";
      ;;
    I)
      vip="$OPTARG";
      ;;
    u)
      ssh_user="$OPTARG";
      ;;
    h)
      usage;
      exit 0;
      ;;
    *)
      usage;
      exit 1;
      ;;
  esac
done


if [ $OPTIND -eq 1 ]; then 
    echo "No options were passed"; 
    usage;
fi

shift $(( OPTIND - 1 ));

# discover commands from our path
ssh=$(which ssh)
arping=$(which arping)
ip2util=$(which ip)

# command for adding our vip
cmd_vip_add="sudo -n $ip2util address add ${vip} dev ${interface}"
# command for deleting our vip
cmd_vip_del="sudo -n $ip2util address del ${vip}/32 dev ${interface}"
# command for discovering if our vip is enabled
cmd_vip_chk="sudo -n $ip2util address show dev ${interface} to ${vip%/*}/32"
# command for sending gratuitous arp to announce ip move
cmd_arp_fix="sudo -n $arping -c 1 -I ${interface} ${vip%/*}"
# command for sending gratuitous arp to announce ip move on current server
cmd_local_arp_fix="sudo -n $arping -c 1 ${vip%/*}"

vip_stop() {
    rc=0

    # ensure the vip is removed
    $ssh ${ssh_options} -tt ${ssh_user}@${orig_master} \
    "[ -n \"\$(${cmd_vip_chk})\" ] && ${cmd_vip_del} && sudo ${ip2util} route flush cache || [ -z \"\$(${cmd_vip_chk})\" ]"
    rc=$?
    return $rc
}

vip_start() {
    rc=0

    # ensure the vip is added
    # this command should exit with failure if we are unable to add the vip
    # if the vip already exists always exit 0 (whether or not we added it)
    $ssh ${ssh_options} -tt ${ssh_user}@${new_master} \
     "[ -z \"\$(${cmd_vip_chk})\" ] && ${cmd_vip_add} && ${cmd_arp_fix} || [ -n \"\$(${cmd_vip_chk})\" ]"
    rc=$?
    $cmd_local_arp_fix
    return $rc
}

vip_status() {
    $arping -c 1 ${vip%/*}
    if ping -c 1 -W 1 "$vip"; then
        return 0
    else
        return 1
    fi
}

if [[ $isitdead == 0 ]]; then
    echo "Online failover"
    if vip_stop; then 
        if vip_start; then
            echo "$vip is moved to $new_master."
            if [ $sendmail -eq 1 ]; then mail -s "$vip is moved to $new_master." "$emailaddress" < /dev/null &> /dev/null  ; fi
        else
            echo "Can't add $vip on $new_master!" 
            if [ $sendmail -eq 1 ]; then mail -s "Can't add $vip on $new_master!" "$emailaddress" < /dev/null &> /dev/null  ; fi
            exit 1
        fi
    else
        echo $rc
        echo "Can't remove the $vip from orig_master!"
        if [ $sendmail -eq 1 ]; then mail -s "Can't remove the $vip from orig_master!" "$emailaddress" < /dev/null &> /dev/null  ; fi
        exit 1
    fi


elif [[ $isitdead == 1 ]]; then
    echo "Master is dead, failover"
    # make sure the vip is not available 
    if vip_status; then 
        if vip_stop; then
            if [ $sendmail -eq 1 ]; then mail -s "$vip is removed from orig_master." "$emailaddress" < /dev/null &> /dev/null  ; fi
        else
            if [ $sendmail -eq 1 ]; then mail -s "Couldn't remove $vip from orig_master." "$emailaddress" < /dev/null &> /dev/null  ; fi
            exit 1
        fi
    fi

    if vip_start; then
          echo "$vip is moved to $new_master."
          if [ $sendmail -eq 1 ]; then mail -s "$vip is moved to $new_master." "$emailaddress" < /dev/null &> /dev/null  ; fi

    else
          echo "Can't add $vip on $new_master!" 
          if [ $sendmail -eq 1 ]; then mail -s "Can't add $vip on $new_master!" "$emailaddress" < /dev/null &> /dev/null  ; fi
          exit 1
    fi
else
    echo "Wrong argument, the master is dead or live?"

fi
