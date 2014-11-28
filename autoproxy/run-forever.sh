#/bin/bash

set -eo pipefail

confd -onetime

service nginx start 

confd &

tail -f /var/log/nginx/*.log

