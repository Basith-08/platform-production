# OPS-014 — First Platform Deployment

**Status:** Approved

**Version:** 1.0

**Owner:** Platform Team

**Last Updated:** 2026-08-20

Runbook ini adalah jalur praktis dari VPS kosong sampai platform aktif.
Untuk detail provisioning, lihat [OPS-001](OPS-001-server-provisioning.md).

## 1. Prinsip

```text
GitHub Actions → /srv/platform → Docker Compose → VPS
```

Production tidak menyimpan source code aplikasi.
Production tidak melakukan `git clone` atau `docker build`.

## 2. Buat dua SSH key

Jalankan di workstation terpercaya:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/prod-sby-01-admin
ssh-keygen -t ed25519 -f ~/.ssh/prod-sby-01-deploy
```

| Akun | Pemakaian |
|---|---|
| `admin` | SSH operator, sudo, emergency |
| `deploy` | GitHub Actions dan Docker deployment |

Private key tidak boleh masuk VPS, Git, atau Actions log.

## 3. Provision dan harden

Gunakan Ubuntu 24.04 LTS dan `linux/amd64`.

Transfer bootstrap, dua public key, dan doctor ke direktori root-only.

Jalankan sebagai `root`:

```bash
/root/bootstrap/bootstrap.sh provision \
  --hostname prod-sby-01 \
  --admin-key /root/bootstrap/prod-sby-01-admin.pub \
  --deploy-key /root/bootstrap/prod-sby-01-deploy.pub
```

Tes dua akun dari terminal baru:

```bash
ssh -i ~/.ssh/prod-sby-01-admin admin@<server-ip>
ssh -i ~/.ssh/prod-sby-01-deploy deploy@<server-ip> 'docker compose version'
```

Setelah keduanya berhasil, jalankan dari console root:

```bash
/root/bootstrap/bootstrap.sh harden
```

Bootstrap memvalidasi `sshd` sebelum me-reload `ssh.service`.

## 4. Set GitHub Actions secrets

Dari provider console, catat fingerprint host key:

```bash
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
```

Dari workstation, ambil dan verifikasi entry host key:

```bash
ssh-keyscan -t ed25519 <server-ip>
```

Buat empat secrets di repository `platform-production`:

```text
PROD_HOST=103.180.165.150
PROD_DEPLOY_USER=deploy
PROD_DEPLOY_KEY=<private deploy key>
PROD_KNOWN_HOSTS=<verified known_hosts line>
```

`PROD_DEPLOY_KEY` adalah private key CI.
`PROD_KNOWN_HOSTS` adalah public host key VPS.

## 5. Siapkan DNS dan runtime files

Gunakan domain terpisah saat testing.

Contoh record DNS:

```text
asfinebasith.web.id → 103.180.165.150
traefik.asfinebasith.web.id → 103.180.165.150
beszel.asfinebasith.web.id → 103.180.165.150
status.asfinebasith.web.id → 103.180.165.150
```

Record `status` hanya diperlukan untuk Uptime Kuma.

Di VPS, sebagai `deploy`, buat runtime files satu kali:

```bash
cp -n /srv/platform/traefik/.env.example /srv/platform/traefik/.env
cp -n /srv/platform/monitoring/.env.example /srv/platform/monitoring/.env
cp -n /srv/platform/backup/backup.env.example /srv/platform/backup/backup.env
chmod 600 /srv/platform/traefik/.env \
  /srv/platform/monitoring/.env \
  /srv/platform/backup/backup.env
```

Traefik `.env`:

```env
PLATFORM_DOMAIN=asfinebasith.web.id
ACME_EMAIL=admin@example.com
```

Monitoring `.env`:

```env
PLATFORM_DOMAIN=asfinebasith.web.id
```

Runtime `.env` tidak pernah dikirim dari GitHub.

## 6. Deploy platform

Buka **Actions → Deploy Platform → Run workflow**.

Untuk deployment pertama:

1. Pilih branch `main`.
2. Biarkan `component` kosong.
3. Centang `skip_backup` jika backup belum siap.
4. Klik **Run workflow**.

Workflow selalu membuat `networks` lebih dahulu.

Traefik dan monitoring berjalan setelah network berhasil.

`skip_backup` hanya berlaku pada manual workflow.
`Re-run` tidak dapat menerima input manual.

## 7. Konfigurasi Traefik

Buat credential dashboard di VPS:

```bash
apt-get update
apt-get install -y apache2-utils
cd /srv/platform/traefik
htpasswd -nB admin > dynamic/dashboard-users.htpasswd
chmod 600 dynamic/dashboard-users.htpasswd
docker compose up -d --force-recreate traefik
```

Buka:

```text
https://traefik.asfinebasith.web.id/dashboard/
```

Gunakan trailing slash pada `/dashboard/`.
Jika `.env` berubah, gunakan `--force-recreate`.

## 8. Konfigurasi Beszel

Beszel memakai Compose profiles.

Untuk menjalankan Hub, isi monitoring `.env`:

```env
COMPOSE_PROFILES=beszel
```

Deploy component `monitoring`.

Buka `https://beszel.asfinebasith.web.id`.

Pilih **Add System** dan isi:

```text
Name: prod-sby-01
Host / IP: 103.180.165.150
```

Salin key dan token agent dari Beszel.

Tambahkan ke `.env`:

```env
COMPOSE_PROFILES=beszel,agent
BESZEL_AGENT_KEY=<generated key>
BESZEL_AGENT_TOKEN=<generated token>
```

Deploy `monitoring` lagi.
Jangan menjalankan Compose file agent dari UI secara terpisah.

Uptime Kuma bersifat optional:

```env
COMPOSE_PROFILES=uptime
```

## 9. Konfigurasi backup

Siapkan tiga file:

```text
/srv/platform/backup/backup.env
/srv/platform/backup/backup.key
/home/deploy/.config/rclone/rclone.conf
```

Nama remote rclone harus sama dengan `RCLONE_REMOTE`.

Untuk Google Drive headless, gunakan `rclone config` di VPS.
Pilih `n` untuk browser lokal.
Gunakan OAuth client ID milik sendiri.

Verifikasi:

```bash
/srv/platform/backup/backup-doctor.sh
```

Setelah lulus, jalankan workflow tanpa `skip_backup`.

## 10. Verifikasi

Jalankan sebagai `deploy` atau `root`:

```bash
/srv/platform/automation/platform-doctor.sh full
docker ps
```

Tes Traefik:

```bash
curl -I http://127.0.0.1:80
```

Port 80 harus redirect ke HTTPS.
Sertifikat domain harus berasal dari Let’s Encrypt.

## 11. Host lama

Platform deployment tidak membuat user atau mengubah sudo.

Buat dan tes `admin` melalui provider console.

Setelah login admin dan sudo berhasil, hapus sudo dari `deploy`:

```bash
gpasswd -d deploy sudo
```

Jangan menghapus sudo `deploy` sebelum akses admin teruji.

## 12. Failure handling

`Missing required runtime file` berarti file belum dibuat di VPS.

`monitoring containers (profiles disabled)` adalah warning optional.

`backup` boleh ditunda dengan `skip_backup` pada manual run.

`No platform components changed` berarti push hanya mengubah automation atau docs.

Gunakan manual workflow untuk initial deployment.

## 13. Referensi

- [OPS-001 — Server Provisioning](OPS-001-server-provisioning.md)
- [OPS-004 — Backup](OPS-004-backup.md)
- [OPS-007 — Monitoring](OPS-007-monitoring.md)
- [OPS-011 — Deploy Platform Service](OPS-011-deploy-platform-service.md)
- [OPS-013 — Manual Configuration Inventory](OPS-013-manual-configuration-inventory.md)
