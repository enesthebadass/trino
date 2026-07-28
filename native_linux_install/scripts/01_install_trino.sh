#!/usr/bin/env bash
set -euo pipefail

# Kullanim:
# sudo bash 01_install_trino.sh /tmp/trino-server-470.tar.gz

if [ "${EUID}" -ne 0 ]; then
  echo "Bu script root/sudo ile calismali."
  exit 1
fi

if [ "$#" -ne 1 ]; then
  echo "Kullanim: $0 /path/to/trino-server-470.tar.gz"
  exit 1
fi

ARCHIVE="$1"

if [ ! -f "$ARCHIVE" ]; then
  echo "Trino archive bulunamadi: $ARCHIVE"
  exit 1
fi

# Trino icin non-login system user.
if ! id trino >/dev/null 2>&1; then
  useradd --system --home /var/lib/trino --shell /sbin/nologin trino
fi

mkdir -p /opt/trino /etc/trino/catalog /var/lib/trino /var/log/trino

# Eski binary varsa korumak icin once backup al.
if [ -x /opt/trino/bin/launcher ]; then
  backup="/opt/trino.backup.$(date +%Y%m%d%H%M%S)"
  mv /opt/trino "$backup"
  mkdir -p /opt/trino
  echo "Mevcut /opt/trino su dizine tasindi: $backup"
fi

tar -xzf "$ARCHIVE" -C /opt/trino --strip-components=1

chown -R root:root /opt/trino /etc/trino
chown -R trino:trino /var/lib/trino /var/log/trino
chmod 0755 /opt/trino /etc/trino

# Config dosyalarini render ettikten sonra /etc/trino altinda owner root kalabilir.
# Parola iceren catalog dosyalari icin 0640 tercih edilir.

echo "Trino binary /opt/trino altina kuruldu."
echo "Simdi 02_render_config.sh ile coordinator veya worker configlerini olustur."
