#/bin/bash

ETCDCTL_PEERS="`route -n | grep ^0\.0\.0\.0 | awk '{ print $2 }'`:4001"
export ETCDCTL_PEERS

while [ 1 ] 
do
    for package in `ls /srv`
    do
        for container in `ls /srv/$package/containers`
        do
            # Read in all the values from the file and update them in etcd
            for keyfile in `ls /srv/$package/containers/$container/keys`
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
                done < /srv/$package/containers/$container/keys/$keyfile
            done
        done
    done
    etcdctl set /etcdwatcher/status 1                
    sleep 60
done
etcdctl rm /etcdwatcher/status
