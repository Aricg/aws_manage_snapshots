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

version="1.2"
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

#pretty logs
log() {
if [ ! -d "$LOGDIR" ]; then
  mkdir -p "$LOGDIR" > /dev/null 2>&1
fi

if [ ! -f "$LOGDIR""$LOG" ]; then
	touch "$LOGDIR""$LOG"
        log "Creating Log File"
fi

	echo "$(date "+%Y/%m/%d %H:%M:%S"): $@" | tee -a "$LOGDIR""$LOG"
}

#Keys must be in the format projectname.key and projectname.pub
get_clients()
{

for client in "${certs[@]}";
do
	describe_instances "$@"
done

}

inventory () {
for description in volumes snapshots instances
do
                 log "Logging "$(basename ${client%.*})"'s "$description" in $zone avaliablity zone to "$LOGDIR"instances-"$zone"-"$(basename ${client%.*})"  (this can take a while)"
                        ec2-describe-"$description" --headers $key > "$LOGDIR"instances-"$zone"-"$(basename ${client%.*})"
done
}

#Get a list of avaliable avaliablility zones to ensure we snapshot ATTACHED volmes in all zones
describe_instances() {

if [[ $snapshot == true ]] && [[ $del == true ]]; then
	echo  "incompatable options"; exit 1
fi

#these wont change often, so generating once almost acceptable
if [[ ! -s tmp_zones ]]; then
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
				delsnap


			#this prepares the information to be parsed.
		elif [[ $snapshot == true ]];
			then
				getvol
				makesnap
		fi

	done
}

getvol() {

log "running ec2-describe-instances to find "$(basename ${client%.*})"'s volumes in $zone avaliablity zone (this can take a while)"
	if [[ $test == true ]]; then log "this is only a test"; fi
ec2-describe-instances $key |grep -v RESERVATION | grep -v TAG | awk '{print $2 " " $3  }' | sed 's,ami.*,,g' | sed -E '/^i-/ i\\n' | awk 'BEGIN { FS="\n"; RS="";} { for (i=2; i<=NF; i+=1){print $1 " " $i}}' > tmp_info

	getvol=()
	while read -d $'\n'; do
		getvol+=("$REPLY")
	done < <(cat tmp_info)
}

getdel() {

log "running ec2-describe-snapshot to find "$(basename ${client%.*})"'s snapshots in $zone avaliablity zone (this can take a while)"
	if [[ $test == true ]]; then log "this is only a test"; fi
ec2-describe-snapshots -o self $key | grep SNAPSHOT | awk '{ print $2 " " $3 " " $5 }' | sed 's,\+.*,,g' |  sort -k2 > tmp_info

	getdel=()
	while read -d $'\n'; do
		getdel+=("$REPLY")
	done < <(cat tmp_info | awk '{ print $2 }' | sort | uniq )
}

getnumkeep() {
	getnumkeep=()
	while read -d $'\n'; do
		getnumkeep+=("$REPLY")
	done < <(cat tmp_info  | awk -v  volume="$vol" 'BEGIN { FS=volume;} {if (NF=="2") print $1 }' | head -n -"$numbertokeep")


}


delsnap () {

if [[ $del == true ]]; then

	for vol in "${getdel[@]}";
	do
		getnumkeep "$@"
		log "Keeping "$numbertokeep" snapshots of volume $vol for "$(basename "${client%.*}")""

		for tbd in "${getnumkeep[@]}";
			do
				if [[ $test == true ]]; then
                                        echo "deleting $tbd of $vol "
                                        echo "Example output: ec2-delete-snapshot $key "$tbd""
				else
					log "deleting $tbd of $vol"
                                        ec2-delete-snapshot $key $tbd
				fi

			done

	done
fi
}

makesnap () {

if [[ $snapshot == true ]]; then

	for vol in "${getvol[@]}";
		do

			instance=$(echo $vol | awk '{print $1}')
			device=$(echo $vol | awk '{print $2}')
			volume=$(echo $vol | awk '{print $3}')

		#I need to call ec2tag with the ouput if the snapshot command so I made the output a variable, probably not the best thing to do. but. meh.
		if [[ $test == true ]]; then
			log "TEST COMMAND OUTPUT : ec2-create-snapshot $key --description ""$volume" of "$device" of "$instance"" "$volume""
		else
			if snap="$(ec2-create-snapshot $key --description ""$volume" of "$device" of "$instance"" "$volume" | awk '{print $2}')"; then

				log "Snapshot "$snap" succeeded for client "${client%.*}" "
				ec2tag $key "$snap" --tag Name="Backup of "$volume" of "$device" of "$instance""

			else
				status=$?
				log "This command failed: ec2-create-snapshot $key --description ""$volume" of "$device" of "$instance"" "$volume""
				log "With this status $status"
			fi
		fi
	done
fi
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
	-d	Run in delete old snapshots mode (keeps 15 snapshots of each attached volume)
	-l	Choose log dir
	-k	Choose key dir

Example Inventory mode :$0  -i -l $LOGDIR -k $KEYDIR
Example Snapshot mode  :$0  -s -l $LOGDIR -k $KEYDIR
Example Delete  mode   :$0  -d
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

while getopts ":tl:k:hid:s" OPTION
do

        case $OPTION in
                t ) test=true ;;
                l ) LOGDIR="$OPTARG" ;;
                k ) KEYDIR="$OPTARG" ;;
                i ) inventory=true ;;
                s ) snapshot=true ;;
                d ) del=true
                numbertokeep="$OPTARG";;
                h ) usage; exit;;
                \? ) echo "Unknown option: -$OPTARG" >&2; exit 1;;
                *  ) echo "Unimplimented option: -$OPTARG" >&2; exit 1;;
        esac
done

get_clients "$@"
