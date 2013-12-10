#!/bin/bash
#########################
# How to use
# Naviage to the aws/securityCredentials page and generate a x.509 certificate
# take both the public and the private certificate file and place them in $KEYDIR
# rename the public and private certificate foo.pub and foo.key respectivly
# you may provide this script with any number of certificate pairs
#
# Aric Gardner 2013
#
# Copyleft Information
# Usage of the works is permitted provided that this instrument is retained with the works, so that any entity that uses the works is notified of this instrument.
# DISCLAIMER: THE WORKS ARE WITHOUT WARRANTY.
##########################

version="1.3"
LOG="snapshots.log"
LOGDIR="/var/log/aws/"
KEYDIR="/etc/ssl/private/aws/"
certs=("$KEYDIR"*.key)

#put your exports here, so that crons work and stuff
if [ -f exports ]; then
source exports
fi


whoareyou () {
if [[ $(whoami) != "root" ]]
then
      echo "This script must be run as user root"
      exit 1
fi
}

logandexit () {
if [ $status -ne 0 ]; then
  log "Script exited "$status""; exit 1 
fi
}

log() {
if [ ! -d "$LOGDIR" ]; then
  mkdir -p "$LOGDIR" > /dev/null 2>&1
fi

if [ ! -f "$LOGDIR""$LOG" ]; then
	touch "$LOGDIR""$LOG"
fi

	echo "$(date "+%Y/%m/%d %H:%M:%S"): $@ " 2>&1 | tee -a "$LOGDIR""$LOG"
}

get_clients() {
#certs must be in $KEYDIR and in the format projectname.key and projectname.pub

if ! [[ -z $client ]]; then 
  
  for client in ""$KEYDIR""$client"";
  do
  	describe_instances "$client" 
  done

else

  for client in "${certs[@]}";
  do
  	describe_instances "$@"
  done

fi
}

#Get a list of avaliable avaliablility zones to ensure we snapshot ATTACHED volmes in all zones
describe_instances() {

#If $azones is not set as an OPTARG grab it from tmp_zones (which we create if needed)
if [[ -z $azones ]]; then
  
    if [[ ! -s tmp_zones ]]; then
      ec2-describe-regions -C ${client%.*}.pub -K ${client%.*}.key | awk '{ print $2 }' > tmp_zones
    fi

  azones=$(<tmp_zones)

fi


#Zones are the top level. this is the main logic for choosing which functions run
for zone in $azones
do
key="--region "$zone" -C ${client%.*}.pub -K ${client%.*}.key"

    if [[ $inventory == true ]];
			then
        inventory

    elif [[ $del == true ]];
			then
        #Logic to show volumes and their snapshots as well as delete old snapshots are in these functions
        getdvol
        delsnap

   elif [[ $snapshot == true ]];
     then
       #Logic to show attached volumes and take snapshots are in these functions
       getsvol
       makesnap
   fi

done

}

getsvol() {


if [[ $test == true ]]; then 
  log "running ec2-describe-instances to list "$(basename ${client%.*})"'s volumes and attachements in $zone avaliablity zone "

else
  log "running ec2-describe-instances to preapare "$(basename ${client%.*})"'s volumes in $zone avaliablity for immediate snapshot"

fi

#TODO pipefail would be usefull
#This is the main logic for parsing ec2-describe-instances with regards to determinig which volumes are attached to which instance
#descinstances=$(ec2-describe-instances $key |grep -v RESERVATION | grep -v TAG | grep -v GROUP | grep -v NIC | grep -v PRIVATEIP | awk '{print $2 " " $3  }' | sed 's,ami.*,,g' | sed -E '/^i-/ i\\n' | awk 'BEGIN { FS="\n"; RS="";} { for (i=2; i<=NF; i+=1){print $1 " " $i}}')

descinstances=$(cat /var/log/aws/instances-"$zone"-enovance | grep -v RESERVATION | grep -v TAG | grep -v GROUP | grep -v NIC | grep -v PRIVATEIP | awk '{print $2 " " $3  }' | sed 's,ami.*,,g' | sed -E '/^i-/ i\\n' | awk 'BEGIN { FS="\n"; RS="";} { for (i=2; i<=NF; i+=1){print $1 " " $i}}' )

    getsvol=()
    while read -d $'\n'; do
      getsvol+=("$REPLY")
    done < <(echo "$descinstances")
}


getdvol() {

#this variable gets built with + and therefore needs to be unset as its never steped on. 
unset listofsnapshots

if [[ $test == true ]]; then 
  log "running ec2-describe-snapshot to list "$(basename ${client%.*})"'s snapshots in $zone avaliablity zone (this can take a while)"
  
else

  log "running ec2-describe-snapshot to delete "$(basename ${client%.*})"'s snapshots if there are more than $numbertokeep associated with any instance for $zone avaliablility zone"
fi

#This is the main logic for parsing instances with regards to  determinig which snapshots are associated with which instance.
#this one liner is divided to provide Both List and Delete functionality

excludeme=()

listofsnapshots=$(awk 'NR==FNR{a[$1];next} !($1 in a)' <(cat /var/log/aws/volumes-$zone-enovance | grep "in-use"  | grep snap | awk {'print $4'} | sort | uniq ) <(cat /var/log/aws/snapshots-$zone-enovance | grep SNAPSHOT | awk '{ print $2 " " $3 " " $5 }' | sed 's,\+.*,,g' | sort -k2 | head -c -1 ) )

}

getnumkeep() {

#this is the main logic to sort out which snapshots are associated with which attached volumes 

	getnumkeep=()
	while read -d $'\n'; do
		getnumkeep+=("$REPLY")
  done < <(echo "$listofsnapshots" | awk -v  volume="$vol" 'BEGIN { FS=volume;} {if (NF=="2") print $1 }' )

#actually print which snapshots belong to which volumes
log "Volume: $vol Has "${#getnumkeep[@]}" snapshots "

}

dothedelete () {
      for snapshot in ${getnumkeep[@]:$numbertokeep:${#getnumkeep[@]}}
        do

          if [[ $test == true ]]; then
            echo "test switch enabled not calling dodelete on snap $snapshot"

          else
                #Delete Volume
                if ! [[ -z $snapshot ]]; then
                   log "running ec2-delete-snapshot $snapshot"
                   dodelete=$(ec2-delete-snapshot $key $snapshot)
                   #Check errors and log
                   status=$?
                   #dont exit if their is a failure. but do log it.
                   log $(echo "$dodelete")
                fi
          fi
       done
     }

delsnap () {
  
  #get the uniq list of volume names in $listofsnapshots
  getdvol=()
  while read -d $'\n'; do
    getdvol+=("$REPLY")
  done < <(echo "$listofsnapshots" | awk '{ print $2 }' | sort | uniq )


      log "Keeping at least "$numbertokeep" snapshots of volumes "${getdvol[@]}" for "$(basename "${client%.*}")""
#for vol in "${getdvol[@]:1}";
for vol in "${getdvol[@]}";
  do
      getnumkeep $@
  if ! [[ -z "${getnumkeep[@]:$numbertokeep:${#getnumkeep[@]}}" ]]; then
      dothedelete $@
  fi
	done
}

makesnap () {
	for vol in "${getsvol[@]}";
		do
      echo "$vol"

			instance=$(echo $vol | awk '{print $1}')
			device=$(echo $vol | awk '{print $2}')
			volume=$(echo $vol | awk '{print $3}')

		if [[ $test == true ]]; then
      echo "In $zone Client "$(basename ${client%.*})" has "$volume" attached as "$device" on "$instance""
		else

if ! [[ -z $volume ]]; then

      #Take Snapshot
      dosnap="$(ec2-create-snapshot $key --description ""$volume" of "$device" of "$instance"" "$volume" 2>&1)"

      #Check Errors and Log
      status="$?"
      log $(echo "$dosnap")
      logandexit "$status"

      #Tag Snapshot
      tag=$(echo "$dosnap" | awk '{print $2}')
      dotag="$(ec2tag $key "$tag" --tag Name="Backup of "$volume" of "$device" of "$instance"" 2>&1)"

      #Check Errors and Log
      status="$?"
      log $(echo "$dotag")
      logandexit "$status"
fi

      fi
	done
}

inventory () {
  for description in volumes snapshots instances
    do
        echo "Logging "$(basename ${client%.*})"'s "$description" in $zone avaliablity zone to "$LOGDIR""$description"-"$zone"-"$(basename ${client%.*})"  (this can take a while)"

        #Log an inventory of all infomation parsed by this script
        doinventory=$(ec2-describe-"$description" --headers $key)

        #Check errors and log
        status="$?"
          if ! [[ -z $doinventory ]]; then
          echo "$doinventory" > "$LOGDIR""$description"-"$zone"-"$(basename ${client%.*})"
          fi
        logandexit "$status"
    done
}



usage() {
cat << EOF

"$0": ensures a snapshot is made for all attached volumes in all zones for all clients
version: $version
usage: $0 [OPTIONS]
 -h  Show this message
 -t  List Volumes and which Machines they are attached to, don't take any action 
 -s  Take a snapshot of all volumes listed by above action
 -v  List each clients attached volumes and their associated snapshots  
 -d  Delete all but X most recent snapshots for each volume listed by above action
 -i  Write an inventory for each client to the log dir	
 -l  Choose log name
 -k  Choose key dir
 -c  Specify which detected accounts you with to run the script against. 
 -a  Specify which avaliablility zones you wish to run the script against.

Example Inventory mode :$0  -i -l $LOGDIR -k $KEYDIR
Example Snapshot mode  :$0  -s -l $LOGDIR -k $KEYDIR
Example Delete mode saving the 15 most recent snapshots  :$0  -d 15
Example List attached volumes for client foo in zone us-east-1:$0 -v -c foo -a us-east-1 
Note: keys must be in the format projectname.key and projectname.pub

zones: eu-west-1 sa-east-1 us-east-1 ap-northeast-1 us-west-2 us-west-1 ap-southeast-1 ap-southeast-2

detected accounts:
EOF

for client in "${certs[@]}";
do
	basename "${client%.*}"
done

echo ""
exit 1

}

whoareyou

if [[ -z "$@" ]]; then usage
fi

while getopts "tl:k:isd:hvc:a:" OPTION
do
        case $OPTION in
                t ) test=true
                snapshot=true
                ;;
                l ) LOG="$OPTARG" ;;
                k ) KEYDIR="$OPTARG" ;;
                i ) inventory=true ;;
                s ) snapshot=true ;;
                d ) numbertokeep="$OPTARG"
                del=true 
                ;;
                v) test=true
                del=true
                ;;
                c ) client="$OPTARG";;
                a ) azones="$OPTARG";;
                h ) usage; exit;;
                \? ) echo "Unknown option: -$OPTARG" >&2; exit 1;;
        esac
done

                if [[ $snapshot == "true" ]] && [[ $del == "true" ]]; then
                  echo  "incompatable options"; exit 1
                fi

get_clients "$@"
