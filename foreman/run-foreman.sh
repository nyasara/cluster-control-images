#/bin/bash

# Find etcd
ETCDCTL_PEERS="`route -n | grep ^0\.0\.0\.0 | awk '{ print $2 }'`:4001"
export ETCDCTL_PEERS

while [ 1 ]
do
    # Loop through packages
    for package in `ls /srv | grep -v ^core$`
    do
        # Loop through containers
        for container in `ls /srv/$package/containers`
        do
            # If there is not a deploy directory, skip
            if [ ! -d "/srv/$package/containers/$container/deploy" ]
            then continue
            fi

            export CONTAINER_DIR="/srv/$package/containers/$container"

            # If there is, foreman has two tasks
            # First, make sure the deployed image is the same version and hash as the most recent librarian build

            # Second, make sure there are no changes to the services
            export SERVICE_HASH="`cat $CONTAINER_DIR/services/* 2> /dev/null | md5sum -` | awk '{print $1}'"
            export CURRENT_SERVICE_HASH="`etcdctl ls /foreman/$package/$container/services_hash`"
            # If they are different
            if [ $SERVICE_HASH != $CURRENT_SERVICE_HASH ]
            then
                # Unload and destroy each service
                for service in `ls /srv/$package/containers/$container/services`
                do
                    # There is no unloading to do for an @ service, assume a scaler, and make the @ service depend on the scaler
                    if [ -z "`grep \@ $service`" ]
                    then
                        fleetctl unload $service
                    fi
                    fleetctl destroy $service
                done

                # Submit and start each service
                for service in `ls /srv/$package/containers/$container/services`
                do
                    fleetctl submit $service
                    # If this is an instantiated service, (with an @), don't start it, assume a scaler who will take care of it
                    if [ -z "`grep \@ $service`" ]
                    then
                        fleetctl start $service
                    fi
                done
            fi

        done
    done      
done
