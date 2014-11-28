#/bin/bash

# Find etcd
ETCDCTL_PEERS="`route -n | grep ^0\.0\.0\.0 | awk '{ print $2 }'`:4001"
export ETCDCTL_PEERS

# Make sure the core package is up to date and set the ready key

export etcdpackagedir="/synchronizer/packages/core/containers"
for container in `etcdctl ls $etcdpackagedir`
do
    export method=`etcdctl get $etcdpackagedir/$container/method`
    if [ "$method" = "git" ]
    then
        export etcdcontainerdir="$etcdpackagedir/$container"
        echo "Get container $container via git in $etcdcontainerdir"
        git clone `etcdctl get $etcdcontainerdir/repo` core-$container
        echo "git clone `etcdctl get $etcdcontainerdir/repo` core-$container"
        cp -r core-$container/`etcdctl get $etcdcontainerdir/repopath` /srv/core/containers/$container
        echo "cp -r core-$container/`etcdctl get $etcdcontainerdir/repopath` /srv/core/containers/$container"
        export version=`cat /srv/core/containers/$container/container_version`
        echo "version=`cat /srv/core/containers/$container/container_version`"
        echo "etcdctl set $etcdcontainerdir/container_version $container_version"
        etcdctl set $etcdcontainerdir/container_version $container_version
        export version=`cat /srv/core/containers/$container/config_version`
        echo "version=`cat /srv/core/containers/$container/config_version`"
        etcdctl set $etcdcontainerdir/config_version $config_version
        echo "etcdctl set $etcdcontainerdir/config_version $config_version"
    fi
done
etcdctl set /synchronizer/ready 1

while [ 1 ]
do
    sleep 15
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
