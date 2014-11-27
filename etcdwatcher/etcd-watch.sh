#/bin/bash

ETCDCTL_PEERS="`route -n | grep ^0\.0\.0\.0 | awk '{ print $2 }'`:4001"
export ETCDCTL_PEERS

while [ 1 ] 
do
    # Read in all the values from the file and update them in etcd
    for keyfile in `ls /etc/corestrap/keys.d`
    do
        while read key value
        do
            OLDVAL=`etcdctl get $key`
            if [ "$OLDVAL" != "$value" ]
            then
                etcdctl set $key "$value"
                echo "Updated"
            fi
            echo $key
            echo $value
        done < /etc/corestrap/keys.d/$keyfile
        etcdctl set /corestrap/status 1
        sleep 60
    done
done
etcdctl rm /corestrap/status
