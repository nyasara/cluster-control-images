#/bin/bash

while [ 1 ] 
do
    # Read in all the values from the file and update them in etcd
    for keyfile in `ls /etc/corestrap/keys.d`
    do
        while read key value
        do
            OLDVAL=`/working/etcdctl --peers $ETCD_BASE_URL --no-sync get $key`
            if [ "$OLDVAL" != "$value" ]
            then
                /working/etcdctl --peers $ETCD_BASE_URL --no-sync set $key "$value"
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
