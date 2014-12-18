aws_manage_snapshots
====================
```

usage: ./aws_manage_snapshots.bash [OPTIONS]
 -h  Show this message
 -t  test but do not take any action if called alone, take an inventory for each client to the log dir and output some statistics.
 -s  Take a snapshot of all attached volumes for all detected clients
 -v  Verbose Mode, used to log a warning if attached volumes do not have at least X snapshots
 -d  Delete all but X most recent snapshots for each volume listed by above action
 -l  Choose log name
 -k  Choose key dir
 -c  Specify which detected accounts you with to run the script against.
 -a  Specify which avaliablility zones you wish to run the script against.
 -e  Specify a file with a new line delimited list of instances whose volumes should be exclude from being snapshotted

Example Snapshot mode  :./aws_manage_snapshots.bash  -s -l /var/log/aws/ -k /etc/ssl/private/aws/
Example Delete mode saving the 15 most recent snapshots  :./aws_manage_snapshots.bash  -d 15
Example Test keeping 15 snapshots for client enovance verbose mode: ./aws_manage_snapshots.bash -t -d 15 -c enovance -v
Note: keys must be in the format projectname.key and projectname.pub
Note: to generate list for -e switch, tag instances "backup = no" and run excludetaggedfiles.bash

```

Requirements
============
ec2-api-tools  -- avaliable in ubntu 12.04 multiverse repo

```
ec2-api-tools
 |Depends: default-jre-headless
  Depends: <java6-runtime-headless>
    openjdk-6-jre-headless
    default-jre-headless
    openjdk-7-jre-headless

```

INSTALLING IN DEBIAN
====================


Get java
```
apt-get install default-jre-headless unzip git
export JAVA_HOME="/usr/lib/jvm/java-6-openjdk-amd64/"

:~# $JAVA_HOME/bin/java -version
java version "1.6.0_27"
OpenJDK Runtime Environment (IcedTea6 1.12.6) (6b27-1.12.6-1~deb7u1)
OpenJDK 64-Bit Server VM (build 20.0-b12, mixed mode)

```

Get the ec2-api-tools

```
wget http://s3.amazonaws.com/ec2-downloads/ec2-api-tools.zip && unzip ec2-api-tools.zip
mkdir /opt/ec2api/ && mv ec2-api-tools-1.6.12.0/bin/ /opt/ec2api/ && mv ec2-api-tools-1.6.12.0/lib/ /opt/ec2api/

export EC2_HOME=/opt/ec2api/
export PATH=$PATH:$EC2_HOME/bin
export EC2_URL=http://ec2.amazonaws.com
```

Get this script
```
cd /opt/
git clone clone https://github.com/enovance/aws_manage_snapshots.git 
mkdir /etc/ssl/private/aws/

#mv your key pairs into the key dir (default /etc/ssl/private/aws/)

:/opt/aws_manage_snapshots# ./aws_manage_snapshots.bash -t
2013/11/29 16:04:00: running ec2-describe-instances to list example companies volumes and attachements in eu-west-1 avaliablity zone
...
[/snip]
```

Dont forget to update /etc/profile or .bashrc
````
export JAVA_HOME="/usr/lib/jvm/java-(6 or maybe 7)-openjdk-amd64/"
export EC2_HOME=/opt/ec2api/
export PATH=$PATH:$EC2_HOME/bin
export EC2_URL=http://ec2.amazonaws.com
```

Adding a new client for backups at eNovance.
* log in to https://console.aws.amazon.com/console/home?#
* On the top navigation bar, click project-name -> Security and Credentials.
* Click on X.509 certificats -> Create New Certificate
* Rename Certificates to ProjectName.pub and ProjectName.key
* Copy certificates to fooserver.com/etc/ssl/private/aws/ 





