FROM nyasara/docker-managementbase

# Install Docker so we can build
RUN curl -sSL https://get.docker.com/ubuntu/ | sh

# Declare the volume for where the config will be
VOLUME /etc/librarian
WORKDIR /working

# Copy the worker script in and make it executable
COPY run-librarian.sh /working/
RUN chmod 750 /working/run-librarian.sh

# Run the worker forever
CMD ["/bin/bash","/working/run-librarian.sh"]
