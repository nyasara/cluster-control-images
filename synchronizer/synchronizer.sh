#/bin/bash

# Find etcd
ETCDCTL_PEERS="`route -n | grep ^0\.0\.0\.0 | awk '{ print $2 }'`:4001"
export ETCDCTL_PEERS


# Make sure the core package is up to date and set the ready key
# Convenience variable for the key for the core package (fixed)
export etcdpackagedir="/synchronizer/packages/core"
# Figure out where the core package is stored 
export method=`etcdctl get $etcdpackagedir/method`
echo "$etcdpackagedir $method"
# If this is a git package (default for core)
if [ "$method" = "git" ]
then
    echo "Getting via git"
    # Clear and then clone the repo
    export repo=`etcdctl get $etcdpackagedir/repo`
    export branch=`etcdctl get $etcdpackagedir/branch`
    echo "Line 1"
    # Figure out the directory that git will clone it into
    export repodir=`echo $repo | awk '{a=split($0, parts, "/"); print parts[a]}'`
    # Remove the existing repo in case 
    echo "Emptying $repodir"
    rm -rf $repodir
    echo "Get container core via git from $repo into $repodir"
    git clone --branch $branch $repo
    echo "git clone --branch $branch $repo"
    # Make sure the /srv directory for the package exists
    mkdir /srv/core
    mkdir /srv/core/containers
    # Go through each container in the package
    for container in `etcdctl ls $etcdpackagedir/containers`
    do
        # Get the name
        export containername=`echo $container | awk '{a=split($0, parts, "/"); print parts[a]}'`
        # Find the path within the repo for this package
        export repopath=`etcdctl get $container/repopath`
        # Copy the stuff over
        cp -r $repodir/$repopath/ /srv/core/containers/$containername
        echo "cp -r $repodir/$repopath /srv/core/containers/$containername"
        # Update the container version
        export version=`cat /srv/core/containers/$containername/container_version`
        echo "version=`cat /srv/core/containers/$containername/container_version`"
        etcdctl set $container/container_version $version
        echo "etcdctl set $container/container_version $version"
        # Update the config version
        export version=`cat /srv/core/containers/$containername/config_version`
        echo "version=`cat /srv/core/containers/$containername/config_version`"
        etcdctl set $container/config_version $version
        echo "etcdctl set $container/config_version $version"
    done
fi

echo "Completed core package downloads"
etcdctl set /synchronizer/ready 1

while [ 1 ]
do
    sleep 15
    echo "Waiting..."
done

# Loop forever
while [ 1 ]
do
    # Check the system for the kill signal indicating we should shut down
    killsignal=`etcdctl get /cluster/runstate`
    if [ "$killsignal" = "1" ]
    then
        break
    fi
    # Check the list of packages    
    for package in `etcdctl ls /synchronizer/packages`
    do
        # For each container in the package
        for container in `etcdctl ls /synchronizer/packages/$package/containers`
        do
            # Figure out the kind of container
            # For now they are all git repos

            # Pull the correct git repo
            git clone `etcdctl get /synchronizer/packages/$package/containers/$container/repo`
            # Copy from the git repo to /srv/$package/containers/$container
            cp -r $repopath /srv/$package/containers/$container
            version=`cat /srv/core/containers/$container/container_version`
            etcdctl set /synchronizer/packages/core/containers/$container/container_version $container_version
            version=`cat /srv/core/containers/$container/config_version`
            etcdctl set /synchronizer/packages/core/containers/$container/config_version $config_version
        done
    done
    echo "Synchronizer check cycle complete"
    sleep 60
done
