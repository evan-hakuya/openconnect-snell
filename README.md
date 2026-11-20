# openconnect-socks5

[![Docker Pulls](https://img.shields.io/docker/pulls/sukka/openconnect-snell.svg)](https://hub.docker.com/r/sukka/openconnect-snell) [![Docker Stars](https://img.shields.io/docker/stars/sukka/openconnect-snell.svg)](https://hub.docker.com/r/sukka/openconnect-snell) [![Docker Automated build](https://img.shields.io/docker/automated/sukka/openconnect-snell.svg)](https://hub.docker.com/r/sukka/openconnect-snell)

Allow Surge to connect to OpenConnect through a SOCKS5 proxy inside a Docker container.

```bash
docker pull sukka/openconnect-snell:latest
```

```bash
docker run -d \
  --privileged \
  --restart unless-stopped \
  -p 127.0.0.1:18388:8388/tcp \
  -e VPN_USER=your-user \
  -e VPN_PASSWORD=your-password \
  -e VPN_AUTH_CODE= \
  -e VPN_AUTH_GROUP= \
  -e VPN_SERVERCERT= \
  -e VPN_HOST=vpn.example.com \
  -e VPN_NO_DTLS=1 \
  -e SOCKS5_PORT=8388 \
  --name openconnect-socks5 sukka/openconnect-snell
```

```conf
[Proxy]
Proxy-CompanyVPN = socks5, 127.0.0.1, 18388
```

## Configuration

- `SOCKS5_HOST`: SOCKS5 listen address. Default is `0.0.0.0`.
- `SOCKS5_PORT`: SOCKS5 listen port. Default is `8388`.
- `SOCKS5_USER`: Optional SOCKS5 username.
- `SOCKS5_PASSWORD`: Optional SOCKS5 password.

- `VPN_USER`: OpenConnect Username. Required.
- `VPN_PASSWORD`: OpenConnect Password. Required.
- `VPN_PASSWD`: Legacy alias for `VPN_PASSWORD`.
- `VPN_HOST`: Where the OpenConnect will be connected to. Required.
- `VPN_SERVERCERT`: OpenConnect server certificate fingerprint to trust. Useful when the server configured certificate is untrusted. Optional.
- `VPN_AUTH_GROUP`: OpenConnect authentication group. Optional.
- `VPN_AUTH_CODE`: OpenConnect authentication code. Optional.
- `VPN_NO_DTLS`: Disable OpenConnect DTLS. Optional.

The container starts Dante after `tun0` is ready. Dante supports SOCKS5 TCP and UDP relay. The container health check requires an active `tun0` interface, an OpenConnect process, and a Dante process.

SOCKS5 UDP uses a dynamic relay port. Use host networking or publish the relay port range in Docker. A fixed `8388/udp` mapping only covers the SOCKS5 control port.

Build a local image for the current architecture:

```bash
docker build -t openconnect-snell:dev .
```

Build and publish both supported architectures:

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --tag ghcr.io/your-user/openconnect-snell:2026.11.20 \
  --push .
```

## License

[MIT](./LICENSE)

----

**openconnect-snell** © [Sukka](https://github.com/SukkaW), Released under the [MIT](./LICENSE) License.
Authored and maintained by Sukka with help from contributors ([list](https://github.com/SukkaW/openconnect-snell/graphs/contributors)).

> [Personal Website](https://skk.moe) · [Blog](https://blog.skk.moe) · GitHub [@SukkaW](https://github.com/SukkaW) · Telegram Channel [@SukkaChannel](https://t.me/SukkaChannel) · Mastodon [@sukka@acg.mn](https://acg.mn/@sukka) · Twitter [@isukkaw](https://twitter.com/isukkaw) · Keybase [@sukka](https://keybase.io/sukka)
