# Connect chart 3.2.36 uses appVersion 4.115.1. Keep connect/test.sh on that version.
FROM docker.redpanda.com/redpandadata/connect:4.115.1

USER root
COPY adsb.yaml /connect/adsb.yaml
COPY placeholder.yaml /connect/placeholder.yaml
COPY entrypoint.sh /connect/entrypoint.sh
RUN chmod 755 /connect/entrypoint.sh
USER connect

ENTRYPOINT ["/connect/entrypoint.sh"]
