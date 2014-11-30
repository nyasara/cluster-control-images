FROM nyasara/docker-managementbase

# Declare the volume for where the config will be
VOLUME /etc/foreman
WORKDIR /working

# Copy the worker script in and make it executable
COPY run-foreman.sh /working/
RUN chmod 750 /working/run-foreman.sh

# Run the worker forever
CMD ["/bin/bash","/working/run-foreman.sh"]
