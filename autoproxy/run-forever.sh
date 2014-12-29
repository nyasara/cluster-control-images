#/bin/bash

# Find etcd
ETCDCTL_PEERS="`route -n | grep ^0\.0\.0\.0 | awk '{ print $2 }'`:4001"
export ETCDCTL_PEERS

confd -onetime -node=$ETCDCTL_PEERS -interval=120

service nginx start 

trap "confd -onetime -node=$ETCDCTL_PEERS" SIGHUP
trap "exit" SIGTERM SIGINT

confd -node=$ETCDCTL_PEERS -interval=120 &

while [ 1 ]
do
    sleep 60
done

# tail -f /var/log/nginx/*.log

