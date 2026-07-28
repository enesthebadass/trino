#!/usr/bin/env bash
set -euo pipefail

# Kullanim:
# bash 04_smoke_test.sh http://coordinator-host:8080

if [ "$#" -ne 1 ]; then
  echo "Kullanim: $0 http://coordinator-host:8080"
  exit 1
fi

SERVER="$1"

echo "Coordinator info kontrol ediliyor..."
curl -fsS "$SERVER/v1/info"
echo

echo "Cluster node listesi kontrol ediliyor..."
curl -fsS "$SERVER/v1/node"
echo

echo "Smoke test tamam."
