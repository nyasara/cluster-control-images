#/bin/bash

# Find etcd
ETCDCTL_PEERS="`route -n | grep ^0\.0\.0\.0 | awk '{ print $2 }'`:4001"
export ETCDCTL_PEERS

confd -onetime -node=$ETCDCTL_PEERS

docker-registry &
confd -node=$ETCDCTL_PEERS &
CONFIG_FILE=`md5sum /docker-registry/config/registry-config.yml`
echo $CONFIG_FILE
while [ 1 ]
do     
    DOCKER_PID=`ps -ef | grep docker-registry | grep -v grep | awk '{ print $2 }'`
    NEW_FILE=`md5sum /docker-registry/config/registry-config.yml`
    if [ "$NEW_FILE" != "$CONFIG_FILE" ]
    then
        kill $DOCKER_PID
        docker-registry &
    fi
    CONFIG_FILE="$NEW_FILE"
    sleep 60
done
