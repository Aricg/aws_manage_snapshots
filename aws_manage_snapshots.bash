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
  log "CRITICAL - Script exited "$status""; exit 1 
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
  
  tmpzones=$(stat -c "%Y" tmp_zones)
  currdate=$(date +%s)

  #Generate tmp_zones if needed and update weekly 
  if [[ ! -s tmp_zones ]] ||  [[ $((currdate-tmpzones)) -gt "10080" ]];

    then
      ec2-describe-regions -C ${client%.*}.pub -K ${client%.*}.key | awk '{ print $2 }' > tmp_zones
    fi

  azones=$(<tmp_zones)

fi
        numvol=0
        numdel=0
        numsnap=0

#Zones are the top level. this is the main logic for choosing which functions run
for zone in $azones
do
        
key="--region "$zone" -C ${client%.*}.pub -K ${client%.*}.key"

        inventory
        if [[ -s "$LOGDIR"instances-"$zone"-"$(basename "${client%.*}")" ]]; then
        getsvol
        getdvol

    if [[ $del == true ]];
			then
#        log "Client:"$(basename ${client%.*})" Zone:"$zone" Mounted Volumes:${#getsvol[@]} Total Volumes:${#getdvol[@]}"
        delsnap
        
   elif [[ $snapshot == true ]];
     then
      log "Client:"$(basename ${client%.*})" Zone:"$zone" Mounted Volumes:${#getsvol[@]} Total Volumes:${#getdvol[@]}"
      makesnap
   fi

fi

done

log "Client:"$(basename ${client%.*})" Zone:All Total number of Mounted Volumes:"$numvol""
log "Client:"$(basename ${client%.*})" Zone:All Total number of Snapshots:"${#getallsnap[@]}""
log "Client:"$(basename ${client%.*})" Zone:All Size of all Snapshots:"$tot Gigs""

if [[ $del = true ]]; then
        log "Client:"$(basename ${client%.*})" Zone:All Snapshots deleted today:"$numdel""
fi
if [[ $snapshot = true ]]; then
        log "Client:"$(basename ${client%.*})" Zone:All Snapshots taken today:"$numsnap"" 
fi

        echo "######################################################################"

}

getsvol() {
#This is the main logic for parsing ec2-describe-instances with regards to determinig which volumes are attached to which instance
descinstances=$(cat "$LOGDIR"instances-"$zone"-"$(basename "${client%.*}")" | grep -v RESERVATION | grep -v TAG | grep -v GROUP | grep -v NIC | grep -v PRIVATEIP | awk '{print $2 " " $3  }' | sed 's,ami.*,,g' | sed -E '/^i-/ i\\n' | awk 'BEGIN { FS="\n"; RS="";} { for (i=2; i<=NF; i+=1){print $1 " " $i}}' )
    getsvol=()
    while read -d $'\n'; do
      getsvol+=("$REPLY")
    done < <(echo "$descinstances")

   if [[ ${getsvol[@]} == "" ]]; then 
    unset getsvol
  else

    numvol=$(( $numvol + ${#getsvol[@]} ))
   fi
  


getallsnap=()
while read -d $'\n'; do
   getallsnap+=("$REPLY")
done < <(cat "$LOGDIR"snapshots-"$zone"-"$(basename ${client%.*})" | grep SNAPSHOT | awk '{print $8'} )

tot=0
for i in ${getallsnap[@]}; do
        let tot+=$i
done




}
getdvol() {
unset listofsnapshots
#This is the main logic for parsing instances with regards to  determinig which snapshots are associated with which instance.
listofsnapshots=$(awk 'NR==FNR{a[$1];next} !($1 in a)' <(cat "$LOGDIR"volumes-"$zone"-"$(basename ${client%.*})" | grep "in-use"  | grep snap | awk {'print $4'} | sort | uniq ) <(cat "$LOGDIR"snapshots-"$zone"-"$(basename ${client%.*})" | grep SNAPSHOT | awk '{ print $2 " " $3 " " $5 }' | sed 's,\+.*,,g' | sort -k2 | head -c -1 ) )
  #get the uniq list of volume names in $listofsnapshots
  getdvol=()
  while read -d $'\n'; do
    getdvol+=("$REPLY")
  done < <(echo "$listofsnapshots" | awk '{ print $2 }' | sort | uniq )
}

getnumkeep() {

#this is the main logic to sort out which snapshots are associated with which attached volumes 

	getnumkeep=()
	while read -d $'\n'; do
		getnumkeep+=("$REPLY")
  done < <(echo "$listofsnapshots" | awk -v  volume="$vol" 'BEGIN { FS=volume;} {if (NF=="2") print $1 }' )

#actually print which snapshots belong to which volumes

if [[ $verbose == true ]]; then

        if [[ "${#getnumkeep[@]}" -lt "$numbertokeep" ]]; then  

          if [[ $(cat "$LOGDIR"volumes-$zone-"$(basename  ${client%.*})" | grep $vol | grep available ) ]]; then
            
                  log "Volume: $vol Only has "${#getnumkeep[@]}" snapshots but it is not attached to an instance ... OK ";
            
          elif [[ $(cat "$LOGDIR"volumes-$zone-"$(basename  ${client%.*})" | grep $vol) ]]; then

                  log "Volume: $vol Only has "${#getnumkeep[@]}" snapshots ... WARNING";

                else
                        log "$(echo "$listofsnapshots" | awk -v  volume="$vol" 'BEGIN { FS=volume;} {if (NF=="2") print $1 }' | xargs ) is a/or are snapshot(s) of a deleted volume $vol .... OK"
                fi

        else
              log "Volume: $vol Has "${#getnumkeep[@]}" snapshots ... OK"
        fi

fi



}

dothedelete () {
      for snapshot in ${getnumkeep[@]:$numbertokeep:${#getnumkeep[@]}}
        do

          if [[ $test == true ]]; then
            echo "test: ec2-delete-snapshot $key $snapshot"

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
                   ((numdel++))
       done
     }

delsnap () {
  


  if ! [[ -z "$listofsnapshots" ]];
  then

log "Client:$(basename "${client%.*}") Zone:"$zone" "Mounted Volumes:"${#getsvol[@]}" Total Volumes:"${#getdvol[@]}" "Keeping:"$numbertokeep""
      
      for vol in "${getdvol[@]}";
        do
            getnumkeep $@
              if ! [[ -z "${getnumkeep[@]:$numbertokeep:${#getnumkeep[@]}}" ]]; then
                dothedelete $@
              fi
        done
    else 

log "No Volumes in $zone for "$(basename ${client%.*})""

fi

}

makesnap () {
	for vol in "${getsvol[@]}";
		do

			instance=$(echo $vol | awk '{print $1}')
			device=$(echo $vol | awk '{print $2}')
			volume=$(echo $vol | awk '{print $3}')

		if [[ $test == true ]]; then
      echo "test: ec2-create-snapshot $key --description ""$volume" of "$device" of "$instance"" "$volume""
		else

if ! [[ -z $volume ]]; then

      #Take Snapshot
      #TODO enable this
      dosnap="$(ec2-create-snapshot $key --description ""$volume" of "$device" of "$instance"" "$volume" 2>&1)"

      #Check Errors and Log
      status="$?"
      log $(echo "$dosnap")
      logandexit "$status"

      #Tag Snapshot
      #TODO This too
      tag=$(echo "$dosnap" | awk '{print $2}')
      dotag="$(ec2tag $key "$tag" --tag Name="Backup of "$volume" of "$device" of "$instance"" 2>&1)"

      #Check Errors and Log
      status="$?"
      log $(echo "$dotag")
      logandexit "$status"

fi

      fi
      ((numsnap++))
	done
}

inventory () {
  for description in volumes snapshots instances
    do
      
      currdate=$(date +%s)
      lastrun="$LOGDIR""$description"-"$zone"-"$(basename ${client%.*})""-lastrun"
      if [[ -e $lastrun ]]; then
        lastrunage=$( stat -c "%Y" "$lastrun" )
        else
        lastrunage="432001"

      fi
      
      inventoryfile="$LOGDIR""$description"-"$zone"-"$(basename ${client%.*})"
      if [[ -e $inventoryfile ]]; then
        inventoryage=$( stat -c "%Y" "$inventoryfile")
        else
                inventoryage="43201"
      fi

      #TODO this doesnt work yet
      if !  [[ -s $inventoryfile ]] && [[ $((currdate-lastrunage)) -gt "43200"  ]]; then
                 echo "#####ABORT#####********"             
      fi
      #if inventory file is size 0 and lastrun is less than a day then skip all output.


if [[ $((currdate-lastrunage)) -gt "43200"  ]];  then 

        echo "Checking for "$(basename ${client%.*})"'s "$description" in $zone avaliablity zone to "$LOGDIR""$description"-"$zone"-"$(basename ${client%.*})"  (this can take a while)"
#
        #Log an inventory of all infomation parsed by this script
        echo "ec2-describe-"$description" --headers $key"
        doinventory=$(ec2-describe-"$description" --headers $key)
        #Check errors and log
        status="$?"
        logandexit "$status"
        touch "$LOGDIR""$description"-"$zone"-"$(basename ${client%.*})""-lastrun"

          if ! [[ -z $doinventory ]]; then
          echo "$doinventory" > "$LOGDIR""$description"-"$zone"-"$(basename ${client%.*})"
          fi

fi

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
 -v  Verbose Mode
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
                t ) test=true;;
                l ) LOG="$OPTARG" ;;
                k ) KEYDIR="$OPTARG" ;;
                i ) inventory=true ;;
                s ) snapshot=true ;;
                d ) numbertokeep="$OPTARG"
                del=true 
                ;;
                v) verbose=true;;
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
