# Trino Docker Setup

This repository runs a small Trino cluster with one coordinator and one worker.
It is intended as a production-ready starting point for Oracle Linux / RHEL-like
servers, not as a final security baseline.

## Server Baseline

- Linux x86-64: Oracle Linux, RHEL 8/9, or Ubuntu 22.04+
- Kernel 5.x or newer
- Java 24 JDK on the host for the pinned `TRINO_VERSION=470` baseline
- Python 3.9+
- glibc 2.28+
- `ulimit -n >= 131072`
- `ulimit -u >= 128000`
- Swap disabled
- Transparent Huge Pages set to `never`
- Network access between coordinator and workers
- Inbound `8080` for HTTP, optionally `8443` for HTTPS/TLS

The official Trino container image includes the runtime needed by Trino itself.
The host Java check exists because the requested server baseline includes it.
Current Trino releases have moved beyond this baseline; review the official
deployment requirements before bumping `TRINO_VERSION`.

## Files

- `docker-compose.yml`: coordinator, worker, network, ulimits, healthcheck
- `etc/coordinator`: coordinator Trino config
- `etc/worker`: worker Trino config
- `etc/catalog`: database connector catalogs
- `.env.example`: environment template for secrets and endpoints
- `scripts/preflight.sh`: host readiness checks

## Usage

Create an environment file:

```bash
cp .env.example .env
```

Edit `.env` with the real PostgreSQL and Oracle connection values.

Run host checks:

```bash
bash scripts/preflight.sh
```

Start Trino:

```bash
docker compose up -d
```

Check cluster health:

```bash
curl http://localhost:8080/v1/info
docker compose logs -f trino-coordinator
```

Open the Trino UI:

```text
http://localhost:8080
```

## TLS

HTTPS is intentionally left commented until the keystore and authentication
policy are known. To enable it:

1. Mount a keystore under `/etc/trino/certs`.
2. Uncomment the HTTPS properties in `etc/coordinator/config.properties`.
3. Uncomment the `8443` port mapping in `docker-compose.yml`.
4. Store `TRINO_KEYSTORE_PASSWORD` in `.env` or your secret manager.

## Scaling Workers

This compose file defines one worker with a static `node.id`. For more workers,
create separate worker config directories with unique `node.id` values, then add
or template additional services. Do not run multiple replicas with the same
`node.id`.

## Production Notes

- Replace placeholder passwords before first run.
- Keep `.env` out of version control.
- Prefer a secret manager for database passwords.
- Confirm firewall rules for coordinator-worker communication.
- Add authentication before exposing Trino outside a trusted network.
- Tune JVM heap and query memory based on actual server RAM.
