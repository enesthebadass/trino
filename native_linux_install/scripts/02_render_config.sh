#!/usr/bin/env bash
set -euo pipefail

# Kullanim:
# sudo bash 02_render_config.sh coordinator /tmp/trino-coordinator.env
# sudo bash 02_render_config.sh worker /tmp/trino-worker.env

if [ "${EUID}" -ne 0 ]; then
  echo "Bu script root/sudo ile calismali."
  exit 1
fi

if [ "$#" -ne 2 ]; then
  echo "Kullanim: $0 coordinator|worker /path/to/env-file"
  exit 1
fi

ROLE="$1"
ENV_FILE="$2"
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if [ "$ROLE" != "coordinator" ] && [ "$ROLE" != "worker" ]; then
  echo "Role sadece coordinator veya worker olabilir."
  exit 1
fi

if [ ! -f "$ENV_FILE" ]; then
  echo "Env dosyasi bulunamadi: $ENV_FILE"
  exit 1
fi

set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

required=(TRINO_ENVIRONMENT TRINO_COORDINATOR_URI ORACLE_HOST ORACLE_PORT ORACLE_SERVICE ORACLE_USER ORACLE_PASSWORD POSTGRESQL_HOST POSTGRESQL_PORT POSTGRESQL_DATABASE POSTGRESQL_USER POSTGRESQL_PASSWORD)
if [ "$ROLE" = "worker" ]; then
  required+=(TRINO_NODE_ID)
fi

for var in "${required[@]}"; do
  if [ -z "${!var:-}" ]; then
    echo "Eksik env: $var"
    exit 1
  fi
done

mkdir -p /etc/trino/catalog

render() {
  src="$1"
  dst="$2"

  sed \
    -e "s#{{TRINO_ENVIRONMENT}}#${TRINO_ENVIRONMENT}#g" \
    -e "s#{{TRINO_COORDINATOR_URI}}#${TRINO_COORDINATOR_URI}#g" \
    -e "s#{{TRINO_NODE_ID}}#${TRINO_NODE_ID:-}#g" \
    -e "s#{{ORACLE_HOST}}#${ORACLE_HOST}#g" \
    -e "s#{{ORACLE_PORT}}#${ORACLE_PORT}#g" \
    -e "s#{{ORACLE_SERVICE}}#${ORACLE_SERVICE}#g" \
    -e "s#{{ORACLE_USER}}#${ORACLE_USER}#g" \
    -e "s#{{ORACLE_PASSWORD}}#${ORACLE_PASSWORD}#g" \
    -e "s#{{POSTGRESQL_HOST}}#${POSTGRESQL_HOST}#g" \
    -e "s#{{POSTGRESQL_PORT}}#${POSTGRESQL_PORT}#g" \
    -e "s#{{POSTGRESQL_DATABASE}}#${POSTGRESQL_DATABASE}#g" \
    -e "s#{{POSTGRESQL_USER}}#${POSTGRESQL_USER}#g" \
    -e "s#{{POSTGRESQL_PASSWORD}}#${POSTGRESQL_PASSWORD}#g" \
    "$src" > "$dst"
}

render "$BASE_DIR/etc/$ROLE/config.properties" /etc/trino/config.properties
render "$BASE_DIR/etc/$ROLE/node.properties" /etc/trino/node.properties
cp "$BASE_DIR/etc/$ROLE/jvm.config" /etc/trino/jvm.config
cp "$BASE_DIR/etc/$ROLE/log.properties" /etc/trino/log.properties
render "$BASE_DIR/etc/catalog/oracle.properties" /etc/trino/catalog/oracle.properties
render "$BASE_DIR/etc/catalog/postgresql.properties" /etc/trino/catalog/postgresql.properties

chown -R root:trino /etc/trino
chmod 0750 /etc/trino /etc/trino/catalog
chmod 0640 /etc/trino/*.properties /etc/trino/jvm.config /etc/trino/catalog/*.properties

echo "$ROLE configleri /etc/trino altina yazildi."
echo "Kontrol icin: sudo bash $BASE_DIR/scripts/03_validate_config.sh"
