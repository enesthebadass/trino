# Docker Olmadan Linux Sunucuya Trino Kurulumu

Bu klasor, Docker'a izin verilmeyen kurum ortamlarinda Trino'yu dogrudan Linux
sunuculara kurmak icin hazirlandi.

Hedef topoloji:

```text
1 coordinator
3 worker
```

Kaynak plani:

```text
Coordinator: 8 vCPU, 32 GB RAM, 100 GB SSD
Worker-1:    16 vCPU, 64 GB RAM, 200 GB SSD
Worker-2:    16 vCPU, 64 GB RAM, 200 GB SSD
Worker-3:    16 vCPU, 64 GB RAM, 200 GB SSD
```

## Klasor Icerigi

```text
native_linux_install/
|-- README.md
|-- env/
|   |-- coordinator.env.example
|   `-- worker.env.example
|-- etc/
|   |-- catalog/
|   |   |-- oracle.properties
|   |   `-- postgresql.properties
|   |-- coordinator/
|   |   |-- config.properties
|   |   |-- jvm.config
|   |   |-- log.properties
|   |   `-- node.properties
|   `-- worker/
|       |-- config.properties
|       |-- jvm.config
|       |-- log.properties
|       `-- node.properties
|-- scripts/
|   |-- 00_preflight.sh
|   |-- 01_install_trino.sh
|   |-- 02_render_config.sh
|   |-- 03_validate_config.sh
|   `-- 04_smoke_test.sh
`-- systemd/
    `-- trino.service
```

## Genel Mantik

Docker kurulumunda config dosyalarini container icine mount ediyorduk. Native
Linux kurulumunda ayni dosyalar dogrudan `/etc/trino` altina kopyalanir.

```text
Docker:
./etc/coordinator/config.properties -> /etc/trino/config.properties

Native Linux:
/etc/trino/config.properties dosyasi direkt sunucuda bulunur
```

Trino binary ise `/opt/trino` altina kurulur:

```text
/opt/trino/bin/launcher
/opt/trino/lib
/opt/trino/plugin
```

Runtime dizinleri:

```text
/etc/trino       Config dosyalari
/opt/trino       Trino binary kurulumu
/var/lib/trino   Node data dir
/var/log/trino   Log dizini
```

## 1. Sunucu On Kosullarini Kontrol Et

Her sunucuda calistir:

```bash
bash native_linux_install/scripts/00_preflight.sh
```

Fail veren maddeler icin sistem ekibinden duzeltme iste.

## 2. Trino Paketini Hazirla

Trino server paketini indir:

```text
trino-server-470.tar.gz
```

Bu dosyayi her sunucuda gecici bir dizine koy. Ornek:

```text
/tmp/trino-server-470.tar.gz
```

## 3. Coordinator Kurulumu

Coordinator sunucusunda:

```bash
sudo bash native_linux_install/scripts/01_install_trino.sh /tmp/trino-server-470.tar.gz
```

Ornek env dosyasi olustur:

```bash
cp native_linux_install/env/coordinator.env.example /tmp/trino-coordinator.env
```

`/tmp/trino-coordinator.env` icindeki placeholder degerleri doldur.

Config dosyalarini render et:

```bash
sudo bash native_linux_install/scripts/02_render_config.sh coordinator /tmp/trino-coordinator.env
```

Servisi yukle:

```bash
sudo cp native_linux_install/systemd/trino.service /etc/systemd/system/trino.service
sudo systemctl daemon-reload
sudo systemctl enable trino
sudo systemctl start trino
sudo systemctl status trino
```

## 4. Worker Kurulumu

Her worker sunucusunda:

```bash
sudo bash native_linux_install/scripts/01_install_trino.sh /tmp/trino-server-470.tar.gz
cp native_linux_install/env/worker.env.example /tmp/trino-worker.env
```

Her worker icin `/tmp/trino-worker.env` icinde farkli `TRINO_NODE_ID` yaz:

```text
Worker-1: TRINO_NODE_ID=trino-worker-01
Worker-2: TRINO_NODE_ID=trino-worker-02
Worker-3: TRINO_NODE_ID=trino-worker-03
```

Ayni dosyada coordinator adresini yaz:

```text
TRINO_COORDINATOR_URI=http://<coordinator-host>:8080
```

Config render et:

```bash
sudo bash native_linux_install/scripts/02_render_config.sh worker /tmp/trino-worker.env
```

Servisi baslat:

```bash
sudo cp native_linux_install/systemd/trino.service /etc/systemd/system/trino.service
sudo systemctl daemon-reload
sudo systemctl enable trino
sudo systemctl start trino
sudo systemctl status trino
```

## 5. Dogrulama

Coordinator sunucusunda veya kendi makinenizden:

```bash
curl http://<coordinator-host>:8080/v1/info
curl http://<coordinator-host>:8080/v1/node
```

Trino CLI ile:

```bash
trino --server http://<coordinator-host>:8080 --catalog oracle --schema <schema>
```

Ornek SQL:

```sql
SHOW CATALOGS;
SHOW SCHEMAS FROM oracle;
SHOW SCHEMAS FROM postgresql;
```

## 6. Log Takibi

```bash
sudo journalctl -u trino -f
sudo tail -f /var/log/trino/server.log
sudo tail -f /var/log/trino/http-request.log
```

## 7. Production Notlari

- Trino root kullanicisi ile calistirilmamalidir.
- DB parolalari dosyada tutulacaksa dosya izinleri sikilastirilmalidir.
- Uzun vadede parolalar secret manager ile yonetilmelidir.
- TLS ve authentication karari production oncesi kapatilmalidir.
- Loglar merkezi log/SIEM sistemine gonderilmelidir.
- Trino version upgrade icin rollback plani hazir olmalidir.
