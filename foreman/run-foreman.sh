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
            echo "Container dir $CONTAINER_DIR"

            # If there is, foreman has two tasks
            # First, make sure the deployed image is the same version and hash as the most recent librarian build


            # Second, make sure there are no changes to the services
            export SERVICE_HASH="`cat $CONTAINER_DIR/services/* | md5sum - | awk '{print $1}'`"
            export CURRENT_SERVICE_HASH="`etcdctl ls /foreman/deploy/$package/$container/services_hash`"
            echo "$SERVICE_HASH - servic - $CURRENT_SERVICE_HASH"
            # If they are different
            if [ "$SERVICE_HASH" != "$CURRENT_SERVICE_HASH" ]
            then
                echo "Reload services"
                # Unload and destroy each service
                for service in `ls /srv/$package/containers/$container/services`
                do
                    echo "Destroy $service"
                    # There is no unloading to do for an @ service, assume a scaler, and make the @ service depend on the scaler
                    if [ -z "`echo $service | grep \"\@\"`" ] 
                    then
                        fleetctl unload $service
                    fi
                    fleetctl destroy $service
                done

                # Submit each service
                for service in `ls /srv/$package/containers/$container/services`
                do
                    echo "Create $service"
                    fleetctl submit /srv/$package/containers/$container/services/$service
                done
            fi

            # Then look in the deploy folder for information on how to run this thing (only needed for instantiated services)
            # Execute deploy/deploy.sh to get info on how much to run and how
            for service in `ls /srv/$package/containers/$container/services`
            do
                echo "Figure out how many $service to run"
                export rundata="`/bin/sh /srv/$package/containers/$container/deploy/deploy-$service.sh`"
                echo "$rundata - rundata"
                echo "$service - export service"
                if [ -n "`echo $service | grep \"\@\"`" ]
                then
                    echo "Instantiated"
                    # An instantiated service runs a set of services as named
                    cat $rundata | while read instance
                    do
                        # See if it is missing from a list of units, and if it is missing, instantiate it
                        if [ -z "`fleetctl list-units | grep $instance`" ]
                        then
                            # Can't block, because some services will wait for others
                            fleetctl starti --no-block $instance
                        fi
                    done
                else
                    echo "Single or global"
                    # A non-instantiated service either runs or doesnt'
                    if [ -n "$rundata" ]
                    then
                        echo "Is not running"
                        if [ -z "`fleetctl list-units | grep $service`" ]
                        then 
                            # Can't block, because some services will wait for others
                            echo "Needs to run"
                            fleetctl start --no-block $service
                        fi
                    else
                        echo "Is running"
                        if [ -n "`fleetctl list-units | grep $service`" ]
                        then
                            echo "Needs to stop"
                            fleetctl stop $service
                        fi
                    fi
                fi
            done
            # Update the deployed hashes
            etcdctl set /foreman/deploy/$package/$container/services_hash "$SERVICE_HASH"
        done
    done
    echo "Sleeping"
    sleep 60
done
