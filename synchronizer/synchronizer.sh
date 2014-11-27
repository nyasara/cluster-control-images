# Make sure the core package is up to date and set the ready key

for container in `etcdctl ls /synchronizer/packages/core/containers`
do
    git clone `etcdctl get /synchronizer/packages/core/containers/$container/repo`
    cp -r `etcdctl get /synchronizer/packages/core/containers/$container/repopath` /srv/core/containers/$container
    version=`cat /srv/core/containers/$container/container_version`
    etcdctl set /synchronizer/packages/core/containers/$container/container_version $container_version
    version=`cat /srv/core/containers/$container/config_version`
    etcdctl set /synchronizer/packages/core/containers/$container/config_version $config_version
done
etcdctl set /synchronizer/ready 1

# Loop forever
while [ 1 ]
do
    # Check the system for the kill signal indicating we should shut down
    killsignal=`etcdctl get /cluster/runstate`
    if [ $killsignal -eq "1" ]
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
done
