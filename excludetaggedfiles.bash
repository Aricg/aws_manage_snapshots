#!/bin/bash
azones=$(<tmp_zones)
KEYDIR="/etc/ssl/private/aws/"
certs=("$KEYDIR"*.key)

export JAVA_HOME="/usr/lib/jvm/java-6-openjdk-amd64/"
export EC2_HOME=/opt/ec2api/
export EC2_URL=http://ec2.amazonaws.com
export PATH=$PATH:$EC2_HOME/bin

#Zones are the top level. this is the main logic for choosing which functions run

if [[ -f $(pwd)/exclude ]]; then
> $(pwd)/exclude
fi

for zone in $azones
do
echo "Checking Zone $zone"

    for client in "${certs[@]}";
    do
        echo "checking client: $client"
        key=" -C ${client%.*}.pub -K ${client%.*}.key --region "$zone""
        ec2-describe-tags $key --filter key=backup --filter resource-type=instance |\
        awk '{print $3}' |tee -a $(pwd)/exclude
    done

done
