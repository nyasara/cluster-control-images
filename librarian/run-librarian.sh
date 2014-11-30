#/bin/bash

# Find etcd
ETCDCTL_PEERS="`route -n | grep ^0\.0\.0\.0 | awk '{ print $2 }'`:4001"
export ETCDCTL_PEERS
export HOST_IP="`route -n | grep ^0\.0\.0\.0 | awk '{ print $2 }'`"

while [ 1 ]
do
    # Loop through the list of packages in /srv
    for package in `ls /srv`
    do
        # Loop through the containers within a package
        for container in `ls /srv/$package/containers`
        do
            # If they do not have a build directory, don't do anything
            if [ ! -d "/srv/$package/containers/$container/build" ]
            then
                continue
            fi

            export NEWEST_CONTAINER_VERSION="`etcdctl get /synchronizer/packages/$package/containers/$container/container_version`"
            export PARENT_IMAGE_NAME="`cat /srv/$package/containers/$container/build/Dockerfile | grep ^FROM | awk '{print $2}'`"
            if [ -z "`echo $PARENT_IMAGE_NAME | grep ':'`" ]
            then
                export PARENT_TAG_NAME="latest"
            else                
                export PARENT_TAG_NAME="`echo $PARENT_IMAGE_NAME | egrep -o :.+ | egrep -o [^:]+`"
                export PARENT_IMAGE_NAME="`echo $PARENT_IMAGE_NAME | egrep -o [^:]: | egrep -o [^:]+`"
            fi
            export PARENT_HASH="`docker images | grep $PARENT_IMAGE_NAME | grep $PARENT_TAG_NAME | awk '{print $3}'`"

            # Check the container version in synchronizer against what we last built
            # If synchronizer has a newer version, do a rebuild
            if [ "`etcdctl get /librarian/buildinfo/$package/$container/build_version`" = "$NEWEST_CONTAINER_VERSION" ]
            then
                # Check the Dockerfile for the FROM statement
                # And check that base image ID to see if it is what we have as the last base for this image
                # If there is not a match, do a rebuild
                if [ "`etcdctl get /librarian/buildinfo/$package/$container/parent_hash`" = "$PARENT_HASH" ]
                then 
                    continue
                fi
            fi

            # We will use the image tag names a lot, and they're complicated, so...convenience variables
            export LATEST_NAME="$HOST_IP:5001/$package/$container"
            export TAG_NAME="$HOST_IP:5001/$package/$container:`etcdctl get /synchronizer/packages/$package/containers/$container/container_version`"
            # If we have to rebuild, rebuild
            docker build -t $LATEST_NAME /srv/$package/containers/$container/build

            # Push to the registry as the latest tag
            docker push $LATEST_NAME
            # Then also tag it with the container_version number
            docker tag $LATEST_NAME $TAG_NAME
            docker push $TAG_NAME

            # And untag anything older
            # TODO 

            # Store the base hash in parent_hash
            etcdctl set /librarian/buildinfo/$package/$container/parent_hash $PARENT_HASH 
            # Store our hash in built_hash
            etcdctl set /librarian/buildinfo/$package/$container/built_hash "`docker images | grep $package/$container | grep latest | awk '{print $3}'`"
            # Update the version in /librarian
            etcdctl set /librarian/buildinfo/$package/$container/build_version "$NEWEST_CONTAINER_VERSION" 
        done
    done
done
