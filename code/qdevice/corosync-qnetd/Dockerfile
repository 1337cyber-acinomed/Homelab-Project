# Project Polaris
# Container: corosync-qnetd
# Purpose: External quorum device for the Proxmox administrative cluster

FROM debian:13-slim

LABEL maintainer="Project Polaris"
LABEL description="Corosync QNetd for Project Polaris Administrative Cluster"
LABEL version="1.0.0"

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y \
        corosync-qnetd \
        ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/corosync/qnetd && \
    chown -R coroqnetd:coroqnetd /etc/corosync/qnetd

EXPOSE 5403/tcp

VOLUME ["/etc/corosync/qnetd"]

ENTRYPOINT ["/usr/bin/corosync-qnetd"]
CMD ["-f"]
