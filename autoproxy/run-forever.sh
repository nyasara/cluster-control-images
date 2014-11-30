#/bin/bash

# Find etcd
ETCDCTL_PEERS="`route -n | grep ^0\.0\.0\.0 | awk '{ print $2 }'`:4001"
export ETCDCTL_PEERS

confd -onetime -node=$ETCDCTL_PEERS

service nginx start 

confd -node=$ETCDCTL_PEERS &

tail -f /var/log/nginx/*.log

