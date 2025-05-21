FROM debian:stable-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        cron \
        nginx-light \
        certbot \
        stunnel4 \
        curl \
        ca-certificates \
        gcc make build-essential && \
    rm -rf /var/lib/apt/lists/*

# 3proxy
RUN curl -L https://github.com/z3APA3A/3proxy/archive/refs/heads/master.tar.gz | \
    tar xz -C /opt/ && \
    make -C /opt/3proxy-master -f Makefile.Linux && \
    cp /opt/3proxy-master/bin/3proxy /usr/local/bin/ && mkdir -p /etc/3proxy && mkdir -p /var/lib/stunnel

COPY ./entrypoint.sh /entrypoint.sh

ENTRYPOINT ["sh", "/entrypoint.sh"]
