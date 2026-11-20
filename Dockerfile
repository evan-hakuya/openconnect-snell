FROM debian:bookworm-slim

LABEL maintainer="SukkaW <hi@skk.moe>"

ENV SOCKS5_HOST=0.0.0.0
ENV SOCKS5_PORT=8388
ENV SOCKS5_USER=
ENV SOCKS5_PASSWORD=

EXPOSE ${SOCKS5_PORT}/tcp

RUN apt-get update \
  && apt-get install --no-install-recommends --yes ca-certificates iproute2 microsocks openconnect \
  && rm -rf /var/lib/apt/lists/*

COPY docker-entrypoint.sh /docker-entrypoint.sh
COPY healthcheck.sh /usr/local/bin/healthcheck

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 CMD ["/usr/local/bin/healthcheck"]

ENTRYPOINT ["/docker-entrypoint.sh"]
