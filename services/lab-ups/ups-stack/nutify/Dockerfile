FROM dartsteven/nutify:latest-raspberrypi5-arm64

USER root

COPY config-init.py /usr/local/bin/config-init.py
COPY db-init.py /usr/local/bin/db-init.py
COPY wrapper-entrypoint.sh /usr/local/bin/wrapper-entrypoint.sh

RUN chmod 755 /usr/local/bin/config-init.py \
    /usr/local/bin/db-init.py \
    /usr/local/bin/wrapper-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/wrapper-entrypoint.sh"]
CMD ["/usr/local/bin/generate-settings.sh", "/usr/local/bin/docker-entrypoint", "/usr/local/bin/start-services.sh"]
