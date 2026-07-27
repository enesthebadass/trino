# Trino Docker Setup

This repository runs a Trino cluster with one coordinator and three workers.
It is intended as a production-ready starting point for Oracle Linux / RHEL-like
servers, not as a final security baseline.

## Target Topology

| Role | Count | vCPU | RAM | SSD | JVM heap |
| --- | ---: | ---: | ---: | ---: | ---: |
| Coordinator | 1 | 8 | 32 GB | 100 GB | 24 GB |
| Worker | 3 | 16 each | 64 GB each | 200 GB each | 52 GB each |

The compose file applies CPU and memory limits for the containers. Disk size is
a host provisioning concern; make sure the Docker data root or mounted volume
for the coordinator has at least 100 GB and each worker has at least 200 GB.

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

- `docker-compose.yml`: coordinator, 3 workers, network, ulimits, healthcheck
- `deploy/coordinator/docker-compose.yml`: coordinator-only compose for the
  coordinator server
- `deploy/worker/docker-compose.yml`: worker-only compose for each worker server
- `etc/coordinator`: coordinator Trino config
- `etc/worker-1`, `etc/worker-2`, `etc/worker-3`: worker Trino configs
- `etc/worker-template`: worker config for separate worker servers
- `etc/catalog`: database connector catalogs
- `.env.example`: environment template for secrets and endpoints
- `scripts/preflight.sh`: host readiness checks

## Local Topology Test

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

## Separate Servers

For the requested production shape, run the coordinator compose file only on the
8 vCPU / 32 GB / 100 GB coordinator server:

```bash
docker compose -f deploy/coordinator/docker-compose.yml up -d
```

Run the worker compose file on each 16 vCPU / 64 GB / 200 GB worker server. Use
a unique `TRINO_NODE_ID` per server and point `TRINO_COORDINATOR_URI` at the
coordinator DNS name or IP address:

```bash
TRINO_NODE_ID=trino-worker-01 TRINO_COORDINATOR_URI=http://coordinator-host:8080 docker compose -f deploy/worker/docker-compose.yml up -d
TRINO_NODE_ID=trino-worker-02 TRINO_COORDINATOR_URI=http://coordinator-host:8080 docker compose -f deploy/worker/docker-compose.yml up -d
TRINO_NODE_ID=trino-worker-03 TRINO_COORDINATOR_URI=http://coordinator-host:8080 docker compose -f deploy/worker/docker-compose.yml up -d
```

Open TCP `8080` from each worker to the coordinator. If HTTPS-only internal
traffic is enabled later, change `TRINO_COORDINATOR_URI` to the `https://...:8443`
endpoint and open TCP `8443`.

## TLS

HTTPS is intentionally left commented until the keystore and authentication
policy are known. To enable it:

1. Mount a keystore under `/etc/trino/certs`.
2. Uncomment the HTTPS properties in `etc/coordinator/config.properties`.
3. Uncomment the `8443` port mapping in `docker-compose.yml`.
4. Store `TRINO_KEYSTORE_PASSWORD` in `.env` or your secret manager.

## Worker Layout

Each worker has a separate config directory and a unique `node.id`. Do not run
multiple workers with the same `node.id`.

The root compose file is useful for local topology testing on one Docker host.
The `deploy/*` compose files fit the requested separate-server layout.

## Production Notes

- Replace placeholder passwords before first run.
- Keep `.env` out of version control.
- Prefer a secret manager for database passwords.
- Confirm firewall rules for coordinator-worker communication.
- Add authentication before exposing Trino outside a trusted network.
- Tune JVM heap and query memory based on actual server RAM.
