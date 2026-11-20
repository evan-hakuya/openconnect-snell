FROM debian:bookworm-slim

LABEL maintainer="SukkaW <hi@skk.moe>"

ENV SOCKS5_HOST=0.0.0.0
ENV SOCKS5_PORT=8388
EXPOSE ${SOCKS5_PORT}/tcp
EXPOSE ${SOCKS5_PORT}/udp

RUN apt-get update \
  && apt-get install --no-install-recommends --yes ca-certificates iproute2 dante-server openconnect \
  && rm -rf /var/lib/apt/lists/*

COPY docker-entrypoint.sh /docker-entrypoint.sh
COPY healthcheck.sh /usr/local/bin/healthcheck

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 CMD ["/usr/local/bin/healthcheck"]

ENTRYPOINT ["/docker-entrypoint.sh"]
