#/bin/bash

# Find etcd
# ETCDCTL_PEERS="`route -n | grep ^0\.0\.0\.0 | awk '{ print $2 }'`:4001"
# export ETCDCTL_PEERS

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
            if [ "$SERVICE_HASH" != "$CURRENT_SERVICE_HASH" ]
            then
                # Unload and destroy each service
                for service in `ls /srv/$package/containers/$container/services`
                do
                    # There is no unloading to do for an @ service, assume a scaler, and make the @ service depend on the scaler
                    if [ -z "`grep "\@" $service`" ] 
                    then
                        fleetctl unload $service
                    fi
                    fleetctl destroy $service
                done

                # Submit each service
                for service in `ls /srv/$package/containers/$container/services`
                do
                    fleetctl submit /srv/$pacakge/containers/$container/services/$service
                done
            fi

            # Then look in the deploy folder for information on how to run this thing (only needed for instantiated services)
            # Execute deploy/deploy.sh to get info on how much to run and how
            export rundata=`/bin/sh deploy/deploy.sh`
            if [ -n "`grep \@ $service`" ]
            then
                # An instantiated service runs a set of services as named
                cat $rundata | while read instance
                do
                    # See if it is missing from a list of units, and if it is missing, instantiate it
                    if [ -z "`fleetctl list-units | grep $instance`" ]
                    then
                        fleetctl start $instance
                    fi
                done
            else
                # A non-instantiated service either runs or doesnt'
                if [ -n "$rundata" ]
                then
                    if [ -z "`fleetctl list-units | grep $service`" ]
                    then
                        fleetctl start $service
                    fi
                else
                    if [ -n "`fleetctl list-units | grep $service`" ]
                    then
                        fleetctl stop $service
                    fi
                fi
            fi
        done
    done      
done
