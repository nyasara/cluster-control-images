#/bin/bash

# Find etcd
ETCDCTL_PEERS="`route -n | grep ^0\.0\.0\.0 | awk '{ print $2 }'`:4001"
export ETCDCTL_PEERS
export REGISTRY_ADDRESS="`etcdctl get /registry/location`"

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

            echo "$PARENT_IMAGE_NAME - image name"
            # TODO - properly handle it if registry for the image is specified in the FROM lien
            if [ -z "`echo $PARENT_IMAGE_NAME | grep ':'`" ]
            then
                echo "Use tag latest"
                export PARENT_TAG_NAME="latest"
            else                               
                export PARENT_TAG_NAME="`echo $PARENT_IMAGE_NAME | egrep -o :.+ | egrep -o [^:]+`"
                export PARENT_IMAGE_NAME="`echo $PARENT_IMAGE_NAME | egrep -o [^:]: | egrep -o [^:]+`"
                echo "Use tag $PARENT_TAG_NAME $PARENT_IMAGE_NAME"
            fi
            
            echo "We='re going to try pulling $REGISTRY_ADDRESS/$PARENT_IMAGE_NAME:$PARENT_TAG_NAME"
            # Try to pull from the local registry, and see if it failed
            if [ -z "`docker pull $REGISTRY_ADDRESS/$PARENT_IMAGE_NAME:$PARENT_TAG_NAME`" ]
            then
                echo "Trying main registry"
                # If it failed, try to pull it from the main Docker Hub registry, then tag it for the local registry and push
                docker pull $PARENT_IMAGE_NAME:$PARENT_TAG_NAME
            else
                echo "Found it locally, retagging"
                # If we did get it locally, tag it to remove the registry location 
                docker tag $REGISTRY_ADDRESS/$PARENT_IMAGE_NAME:$PARENT_TAG_NAME $PARENT_IMAGE_NAME:$PARENT_TAG_NAME
            fi

            # Then save off the hash of the parent so we can check for changes to it later
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
            export LATEST_NAME="$REGISTRY_ADDRESS/$package/$container"
            tagnumber=`etcdctl get /synchronizer/packages/$package/containers/$container/container_version`
            export TAG_NAME="$REGISTRY_ADDRESS/$package/$container:$tagnumber"
            echo "Name data $LATEST_NAME $tagnumber $TAG_NAME"
            # If we have to rebuild, rebuild, not caching because of possible things that won't get done
            docker build --no-cache -t $LATEST_NAME /srv/$package/containers/$container/build

            # Push to the registry as the latest tag
            docker push $LATEST_NAME
            # Then also tag it with the container_version number and push
            docker tag $LATEST_NAME $TAG_NAME
            docker push $TAG_NAME

            # And untag anything older (Just echoing for now)
            docker images | grep "$package/$container" | grep -v latest | grep -v $tagnumber | awk '{print $2}' | while read oldtag; do echo "Would remove $package/$container:$oldtag"; done

            # Store the base hash in parent_hash
            etcdctl set /librarian/buildinfo/$package/$container/parent_hash $PARENT_HASH 
            # Store our hash in built_hash
            etcdctl set /librarian/buildinfo/$package/$container/built_hash "`docker images | grep $package/$container | grep latest | awk '{print $3}'`"
            # Update the version in /librarian
            etcdctl set /librarian/buildinfo/$package/$container/build_version "$NEWEST_CONTAINER_VERSION" 
        done
    done
done
