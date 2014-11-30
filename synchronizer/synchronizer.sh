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

    # Do the clone
    echo "Get container core via git from $repo into $repodir"
    git clone --branch $branch $repo
    echo "git clone --branch $branch $repo"

    # Save the current revision ID to etcd
    etcdctl set $etcdpackagedir/revision `cd $repodir && git rev-parse $branch`
    
    # Make sure the /srv directory for the package exists
    if [ ! -d "/srv/core" ]; then mkdir /srv/core; fi
    if [ ! -d "/srv/core/containers" ]; then mkdir /srv/core/containers; fi
    
    # Go through each container in the package
    for container in `etcdctl ls $etcdpackagedir/containers`
    do
        # Get the name
        export containername=`echo $container | awk '{a=split($0, parts, "/"); print parts[a]}'`
        # Find the path within the repo for this package
        export repopath=`etcdctl get $container/repopath`
        # Copy the stuff over
        cp -r -T $repodir/$repopath/ /srv/core/containers/$containername/
        echo "cp -r -T $repodir/$repopath /srv/core/containers/$containername"
        # Update the container version
        export version="`cat /srv/core/containers/$containername/container_version`0"
        echo "version=`cat /srv/core/containers/$containername/container_version`"
        etcdctl set $container/container_version $version
        echo "etcdctl set $container/container_version $version"
        # Update the config version
        export version="`cat /srv/core/containers/$containername/config_version`0"
        echo "version=`cat /srv/core/containers/$containername/config_version`"
        etcdctl set $container/config_version $version
        echo "etcdctl set $container/config_version $version"
    done
fi

echo "Completed core package downloads"
etcdctl set /synchronizer/ready 1

# Loop forever
while [ 1 ]
do
    export killsignal=`etcdctl get /cluster/runstate`
    if [ "$killsignal" = "1" ]
    then
        break
    fi

    for etcdpackagedir in `etcdctl ls /synchronizer/packages`
    do
        export packagename=`echo $etcdpackagedir | awk '{a=split($0, parts, "/"); print parts[a]}'`
        # Figure out where the package is stored 
        export method=`etcdctl get $etcdpackagedir/method`
        echo "$etcdpackagedir $method"
        # If this is a git package
        if [ "$method" = "git" ]
        then
            echo "Getting via git"
            # Clear and then clone the repo
            export repo=`etcdctl get $etcdpackagedir/repo`
            export branch=`etcdctl get $etcdpackagedir/branch`
            echo "Line 1"
            # Figure out the directory that git will clone it into
            export repodir=`echo $repo | awk '{a=split($0, parts, "/"); print parts[a]}'`

            # See if that directory does not exist or the revision has changed
            if [ ! -d "$repodir" ] || [ "`etcdctl get $etcdpackagedir/revision`" != "`cd $repodir && git rev-parse $branch`" ]
            then
                # Remove the existing repo if it was there
                if [ -d "$repodir" ]
                then 
                    echo "Emptying $repodir"
                    rm -rf $repodir
                fi

                # DO the clone
                echo "Get package $etcdpackagedir via git from $repo into $repodir"
                git clone --branch $branch $repo
                echo "git clone --branch $branch $repo"

                # Update the revision ID in etcd
                etcdctl set $etcdpackagedir/revision `cd $repodir && git rev-parse $branch`

                # Make sure the /srv directory for the package exists
                if [ ! -d "/srv/$packagename" ]; then mkdir /srv/$packagename; fi
                if [ ! -d "/srv/$packagename/containers" ]; then mkdir /srv/$packagename/containers; fi

                # Go through each container in the package
                for container in `etcdctl ls $etcdpackagedir/containers`
                do
                    # Get the name
                    export containername=`echo $container | awk '{a=split($0, parts, "/"); print parts[a]}'`
                    # Find the path within the repo for this package
                    export repopath=`etcdctl get $container/repopath`
                    # Copy the stuff over
                    cp -r -T $repodir/$repopath/ /srv/$packagename/containers/$containername/
                    echo "cp -r -T $repodir/$repopath /srv/$packagename/containers/$containername"
                    # Update the container version
                    export version="`cat /srv/$packagename/containers/$containername/container_version`0"
                    echo "version=`cat /srv/$packagename/containers/$containername/container_version`"
                    etcdctl set $container/container_version $version
                    echo "etcdctl set $container/container_version $version"
                    # Update the config version
                    export version="`cat /srv/$packagename/containers/$containername/config_version`0"
                    echo "version=`cat /srv/$packagename/containers/$containername/config_version`"
                    etcdctl set $container/config_version $version
                    echo "etcdctl set $container/config_version $version"
                done
            else
                echo "$packagename up to date with source repo"
            fi
        fi
    done
    echo "Synchronizer check cycle complete"
    sleep 60
done
