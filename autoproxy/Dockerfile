FROM nyasara/docker-managementbase

RUN apt-get update \
    && apt-get install -yq nginx \
    && mkdir /working

COPY nginx.toml /etc/confd/conf.d/
COPY nginx.tmpl /etc/confd/templates/
COPY run-forever.sh /working/

CMD ["/bin/bash", "/working/run-forever.sh"]

