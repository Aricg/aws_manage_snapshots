aws_manage_snapshots
====================

ec2-create and delete snapshots for any number of 509.x key-paris with the aws cli api, Inventory with ec2-describe-volumes/snapshots/instances



    "./aws_manage_snapshots": ensures a snapshot is made for all attached volumes in all zones for all clients
    version: 1.1
    usage: ./aws_manage_snapshots [OPTIONS]
    -h  Show this message
	  -t	Run in test mode
	  -s	Run in snapshot mode
	  -i	Run in inventory mode
	  -d #  Run in delete old snapshots mode ( # = number of snapshots to keep) 
	  -l	Choose log dir
	  -k	Choose key dir

    Example Inventory mode :./aws_manage_snapshots  -i -l /var/log/aws/ -k /etc/ssl/private/aws/
    Example Snapshot mode  :./aws_manage_snapshots  -s -l /var/log/aws/ -k /etc/ssl/private/aws
    Example Delete  mode   :./aws_manage_snapshots  -d 15
    Note: keys must be in the format projectname.key and projectname.pub

    detected accounts:
    foo
    bar
    baz

