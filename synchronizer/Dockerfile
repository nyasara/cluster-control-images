FROM nyasara/docker-managementbase

# Copy the worker script in and make it executable
COPY synchronizer.sh /working/
RUN chmod 750 /working/synchronizer.sh

# Declare the volume for where the config will be
VOLUME /etc/synchronizer
WORKDIR /working

ENV ETCDCTL_PEERS http://172.17.42.1:4001

# Run the watch script forever
CMD ["/bin/bash", "/working/synchronizer.sh"]
