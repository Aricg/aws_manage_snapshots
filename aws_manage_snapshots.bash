#!/bin/bash
#########################
# How to use
# Naviage to the aws/securityCredentials page and generate a x.509 certificate
# take both the public and the private certificate file and place them in $KEYDIR
# rename the public and private certificate foo.pub and foo.key respectivly
# you may provide this script with any number of certificate pairs
#
# What it does
# This script takes a SNAPSHOT of all ATTACHED volumes across all AVALIABILITY zones.
# Bascially it covers your ass.
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

whoareyou () {
if [[ $(whoami) != "root" ]]
then
      echo "This script must be run as user root"
      exit 1
fi
}

logandexit () {
if [ $status -ne 0 ]; then
  log "Script exited "$status""; exit "$status"
fi
}

log() {
if [ ! -d "$LOGDIR" ]; then
  mkdir -p "$LOGDIR" > /dev/null 2>&1
fi

if [ ! -f "$LOGDIR""$LOG" ]; then
	touch "$LOGDIR""$LOG"
  log "Creating Log File"
fi
	echo "$(date "+%Y/%m/%d %H:%M:%S"): $@ " 2>&1 | tee -a "$LOGDIR""$LOG"
}

get_clients() {
#certs must be in $KEYDIR and in the format projectname.key and projectname.pub
for client in "${certs[@]}";
do
	describe_instances "$@"
done

}

#Get a list of avaliable avaliablility zones to ensure we snapshot ATTACHED volmes in all zones
describe_instances() {

if [[ ! -s tmp_zones ]]; then
  #TODO catch errors
  #TODO choose DC to backup as opt arg
  #TODO regenerate tmp_zones if it is more than $x days old, Amazon has been known to add new data centers ;)
	ec2-describe-regions -C ${client%.*}.pub -K ${client%.*}.key | awk '{ print $2 }' > tmp_zones
fi

#we must check each zone for each client.
for zone in $(cat tmp_zones)
do
	key="--region "$zone" -C ${client%.*}.pub -K ${client%.*}.key"

    if [[ $inventory == true ]];
			then
        inventory

    elif [[ $del == true ]];
			then
        getdel
        #if ! [[ $test == true ]]; then
        delsnap
        #fi

		elif [[ $snapshot == true ]];
			then
				getvol
				makesnap
		fi
done
}

getvol() {
if [[ $test == true ]]; then log "this is only a test"; fi

  log "running ec2-describe-instances to find "$(basename ${client%.*})"'s volumes in $zone avaliablity zone (this can take a while)"

  #TODO catch errors, possibly log tmp.info it's interesting to audit
  ec2-describe-instances $key |grep -v RESERVATION | grep -v TAG | awk '{print $2 " " $3  }' | sed 's,ami.*,,g' | sed -E '/^i-/ i\\n' | awk 'BEGIN { FS="\n"; RS="";} { for (i=2; i<=NF; i+=1){print $1 " " $i}}' > tmp_info

    getvol=()
    while read -d $'\n'; do
      getvol+=("$REPLY")
    done < <(cat tmp_info)
}

getdel() {
if [[ $test == true ]]; then log "this is only a test"; fi

  log "running ec2-describe-snapshot to find "$(basename ${client%.*})"'s snapshots in $zone avaliablity zone (this can take a while)"

  #TODO catch errors here, log tmp_info, and possibly rewrite it, as its infomation we need to delete snapshots and should be named more clearly

  descsnap=$(ec2-describe-snapshots -o self $key | grep SNAPSHOT | awk '{ print $2 " " $3 " " $5 }' | sed 's,\+.*,,g' |  sort -k2) 
  runningvolumes=$(echo "$descsnap" | awk '{ print $2 }' | sort | uniq )

  log ""$(basename ${client%.*})"'s Running Volumes in "$zone":"
  log $runningvolumes 
  log $trimmedsnapshots
 
#TODO remove temporary file 
#  echo "$descsnap" > tmp_info

    getdel=()
    while read -d $' '; do
      getdel+=("$REPLY")
    done < <(echo $runningvolumes )

}

getnumkeep() {

  allsnapshots=$(echo "$descsnap" | awk -v  volume="$vol" 'BEGIN { FS=volume;} {if (NF=="2") print $1 }')
  trimmedsnapshots=$(echo "$descsnap" | awk -v  volume="$vol" 'BEGIN { FS=volume;} {if (NF=="2") print $1 }' | head -n -"$numbertokeep")
  log "Volume:"
  log $vol
  log "Associated Snapshots:"
  log $allsnapshots 

        if ! [[ -z $trimmedsnapshots ]]; then
          log "Snapshots to be deleted:"
          log $trimmedsnapshots
        fi 

	getnumkeep=()
	while read -d $' '; do
		getnumkeep+=("$REPLY")
  done < <(echo $trimmedsnapshots)

}


delsnap () {
	for vol in "${getdel[@]}";
	do
#Looks like i need new logic as this deletes backup volumes of unattached instances. wihtout knowing it
		getnumkeep "$@"
#		log "Keeping "$numbertokeep" snapshots of volume $vol for "$(basename "${client%.*}")""

      for tbd in "${getnumkeep[@]}";
        do
          if [[ $test == true ]]; then
#            echo "Example delete of $vol's snapshot: ec2-delete-snapshot $key "$tbd" "
echo "test switch enabled not calling dodelete on snap $tbd"
          else

            #Delete Volume
            dodelete=$(ec2-delete-snapshot $key $tbd)
            
            #Check errors and log
            status=$?
            log $(echo "$dodelete")
            logandexit "$status"

          fi
      done
	done
}

makesnap () {

	for vol in "${getvol[@]}";
		do

			instance=$(echo $vol | awk '{print $1}')
			device=$(echo $vol | awk '{print $2}')
			volume=$(echo $vol | awk '{print $3}')

		if [[ $test == true ]]; then
			echo "TEST COMMAND OUTPUT : ec2-create-snapshot $key --description ""$volume" of "$device" of "$instance"" "$volume""

		else

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
        -h	Show this message
	-t	Run in test mode
	-s	Run in snapshot mode
	-i	Run in inventory mode
	-d  Delete all but X snapshots for each volume
	-l	Choose log dir
	-k	Choose key dir

Example Inventory mode :$0  -i -l $LOGDIR -k $KEYDIR
Example Snapshot mode  :$0  -s -l $LOGDIR -k $KEYDIR
Example Delete mode saving the 15 most recent snapshots  :$0  -d 15
Note: keys must be in the format projectname.key and projectname.pub

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

#TODO optionally only snap the volumes of a single client

while getopts "tl:k:isd:h" OPTION
do
        case $OPTION in
                t ) test=true ;;
                l ) LOGDIR="$OPTARG" ;;
                k ) KEYDIR="$OPTARG" ;;
                i ) inventory=true ;;
                s ) snapshot=true ;;
                d ) numbertokeep="$OPTARG"
                del=true 
                ;;
                h ) usage; exit;;
                \? ) echo "Unknown option: -$OPTARG" >&2; exit 1;;
        esac
done
#                if [[ -z "$numbertokeep" ]] && [[ $del = true ]]; then 
#                  echo "You must provide a number of snapshots to keep"; exit 1 
#                fi  

                if [[ $snapshot == "true" ]] && [[ $del == "true" ]]; then
                  echo  "incompatable options"; exit 1
                fi

get_clients "$@"
