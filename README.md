aws_manage_snapshots
====================
```
version: 1.3
usage: ./aws_manage_snapshots.bash [OPTIONS]
 -h  Show this message
 -t  List Volumes and which Machine they are attached to, don't take any action
 -s  Take a snapshot of all volumes listed by above action
 -v  List each clients attached volumes and their associated snapshots
 -d  Delete all but X most recent snapshots for each volume listed by above action
 -i  Write an inventory for each client to the log dir
 -l  Choose log dir
 -k  Choose key dir
 -c  Specify which detected accounts you wish to run the script against.
 -a  Specify which avaliablility zones you wish to run the script against.

Example Inventory mode :./aws_manage_snapshots.bash  -i -l /var/log/aws/ -k /etc/ssl/private/aws/
Example Snapshot mode  :./aws_manage_snapshots.bash  -s -l /var/log/aws/ -k /etc/ssl/private/aws/
Example Delete mode saving the 15 most recent snapshots  :./aws_manage_snapshots.bash  -d 15
Example List attached volumes for client foo in zone us-east-1:./aws_manage_snapshots.bash -v -c foo -a us-east-1
Note: keys must be in the format projectname.key and projectname.pub

zones: eu-west-1 sa-east-1 us-east-1 ap-northeast-1 us-west-2 us-west-1 ap-southeast-1 ap-southeast-2

detected accounts:
foo 
bar
buzz
```

Requirements
============
ec2-api-tools ec2-ami-tools -- avaliable in ubntu 12.04 multiverse repo

```
ec2-api-tools
 |Depends: default-jre-headless
  Depends: <java6-runtime-headless>
    openjdk-6-jre-headless
    default-jre-headless
    openjdk-7-jre-headless
$ apt-cache depends ec2-ami-tools
ec2-ami-tools
  Depends: ruby
    ruby1.8
  Depends: <libopenssl-ruby>
    libruby
  Depends: curl
```
