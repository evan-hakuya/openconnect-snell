FROM --platform=$BUILDPLATFORM tonistiigi/xx AS xx
FROM --platform=$BUILDPLATFORM debian:bookworm-slim AS build

LABEL maintainer="SukkaW <hi@skk.moe>"

ARG SNELL_VERSION=5.0.1
ARG TARGETPLATFORM

COPY --from=xx / /
COPY get-snell-url.sh /get-snell-url.sh

RUN xx-info env \
  && apt-get update \
  && apt-get install --no-install-recommends --yes wget unzip ca-certificates \
  && rm -rf /var/lib/apt/lists/* \
  && wget -O snell-server.zip $(/get-snell-url.sh ${SNELL_VERSION} $(xx-info arch)) \
  && unzip snell-server.zip \
  && rm snell-server.zip \
  && xx-verify /snell-server

FROM debian:bookworm-slim

ENV SNELL_HOST=0.0.0.0
ENV SNELL_PORT=8388
ENV SNELL_PSK=
ENV SNELL_OBFS=off

EXPOSE ${SNELL_PORT}/tcp
EXPOSE ${SNELL_PORT}/udp

RUN apt-get update \
  && apt-get install --no-install-recommends --yes openconnect ca-certificates iproute2 \
  && rm -rf /var/lib/apt/lists/*
COPY --from=build /snell-server /usr/bin/snell-server
COPY docker-entrypoint.sh /docker-entrypoint.sh
COPY healthcheck.sh /usr/local/bin/healthcheck

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 CMD ["/usr/local/bin/healthcheck"]

ENTRYPOINT ["/docker-entrypoint.sh"]
