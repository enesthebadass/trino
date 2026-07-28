#!/usr/bin/env bash
set -euo pipefail

# Basit dosya ve placeholder kontrolu.
# Trino'yu baslatmadan once calistir.

required_files=(
  /etc/trino/config.properties
  /etc/trino/node.properties
  /etc/trino/jvm.config
  /etc/trino/log.properties
  /etc/trino/catalog/oracle.properties
  /etc/trino/catalog/postgresql.properties
)

for file in "${required_files[@]}"; do
  if [ ! -s "$file" ]; then
    echo "Eksik veya bos dosya: $file"
    exit 1
  fi

done

if grep -R '{{' /etc/trino >/dev/null 2>&1; then
  echo "Placeholder kalmis gorunuyor. /etc/trino dosyalarini kontrol et."
  grep -R '{{' /etc/trino || true
  exit 1
fi

if ! grep -Eq '^coordinator=(true|false)$' /etc/trino/config.properties; then
  echo "config.properties icinde coordinator=true/false bulunamadi."
  exit 1
fi

if ! grep -Eq '^node.id=' /etc/trino/node.properties; then
  echo "node.properties icinde node.id bulunamadi."
  exit 1
fi

if ! grep -Eq '^discovery.uri=http' /etc/trino/config.properties; then
  echo "discovery.uri http/https ile baslamali."
  exit 1
fi

echo "Config dosyalari temel kontrolden gecti."
