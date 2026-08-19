# OPS-013 — Manual Configuration Inventory

**Status:** Approved
**Version:** 1.1
**Owner:** Platform Team
**Last Updated:** 2026-08-20

Dokumen ini adalah inventaris canonical untuk nilai, credential, dan state
runtime yang sengaja tidak disimpan di Git. `platform-production` tetap berada
di GitHub; server hanya menerima hasil sinkronisasi deployment dan tidak
memerlukan permanent clone.

## 1. Otomatis vs manual

| Area | Otomatis | Manual / out-of-band |
|---|---|---|
| User, key installation, base package, Docker, Compose, rclone binary | `bootstrap.sh provision` | root/provider console untuk transfer awal |
| SSH hardening | `bootstrap.sh harden` setelah operator verifikasi akses | keputusan operator untuk menjalankan fase harden |
| Hostname/node identity | `--hostname` pada bootstrap | memilih nama node dan mencatatnya |
| Directory, journald, logrotate, UFW | bootstrap | verifikasi hasil |
| Shared Docker networks | component `networks` melalui GitHub Actions | emergency path saja |
| Platform config sync, preparation, Compose apply, health check | GitHub Actions | trigger awal/manual redeploy |
| Application compose manifest sync, image deployment, health check | application GitHub Actions + GHCR | membuat direktori dan runtime `.env` pertama kali |
| Backup encryption/upload/retention | `infrastructure/backup/` + cron | key, OAuth, runtime config |
| Runtime secrets and persistent state | tidak pernah dikirim dari Git | operator memasang dan memulihkan |
| DNS, TLS domain, UI accounts/integrations | tidak dikelola workflow | operator/provider/GitHub settings |

Manual configuration bukan alasan untuk mengedit file tracked langsung di VPS.
Perubahan konfigurasi harus masuk Git dan dideploy melalui workflow.

## 2. Identitas server dan SSH

Siapkan dua key pair yang berbeda:

- `admin`: key pribadi operator; akun memiliki sudo dan dipakai untuk
  administrasi/emergency.
- `deploy`: key khusus GitHub Actions; akun tanpa password dan tanpa general
  sudo, tetapi anggota Docker group. Docker group memberi kemampuan
  root-equivalent melalui Docker daemon dan bukan boundary privilege yang kuat.

Jangan simpan private key di `/srv`, commit, issue, workflow log, atau chat.
Ikuti [OPS-001](OPS-001-server-provisioning.md) untuk transfer dan urutan
provision/harden.

Setelah harden, verifikasi host key dari provider console:

```bash
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
```

Bandingkan fingerprint tersebut dengan hasil `ssh-keyscan` dari workstation
terpercaya. Simpan entry `known_hosts` yang sudah diverifikasi sebagai secret:

```text
PROD_HOST=<ip-or-hostname>
PROD_DEPLOY_USER=deploy
PROD_DEPLOY_KEY=<private-ci-key>
PROD_KNOWN_HOSTS=<verified-host-key-entry>
```

Secret di atas diperlukan pada `platform-production` dan setiap application
repository yang deploy ke VPS. Saat rebuild/migrasi, update `PROD_KNOWN_HOSTS`
hanya setelah fingerprint host baru diverifikasi secara out-of-band.

## 3. Runtime platform files

Buat dan isi file berikut di VPS; workflow rsync tidak menimpa atau menghapusnya:

```text
/srv/platform/traefik/.env
/srv/platform/monitoring/.env
/srv/platform/backup/backup.env
/srv/platform/backup/backup.key
/home/deploy/.config/rclone/rclone.conf
/srv/platform/traefik/dynamic/dashboard-users.htpasswd
```

Gunakan contoh tracked masing-masing komponen, lalu:

```bash
sudo chown deploy:deploy /srv/platform/traefik/.env \
  /srv/platform/monitoring/.env /srv/platform/backup/backup.env \
  /srv/platform/backup/backup.key
sudo chmod 600 /srv/platform/traefik/.env \
  /srv/platform/monitoring/.env /srv/platform/backup/backup.env \
  /srv/platform/backup/backup.key /home/deploy/.config/rclone/rclone.conf
```

`backup.key`, rclone OAuth/config, dan generated htpasswd harus memiliki salinan
recovery terpisah. Jangan pernah menyalin file tersebut dari Git.

## 4. Application onboarding

Untuk aplikasi baru, operator hanya membuat runtime target dan memasang `.env`:

```bash
sudo -u deploy mkdir -p /srv/apps/<app-name>/volumes
sudo -u deploy editor /srv/apps/<app-name>/.env
sudo chmod 600 /srv/apps/<app-name>/.env
```

Application workflow kemudian mengirim `compose.yaml` saja secara atomik ke
`/srv/apps/<app-name>/compose.yaml`, mempertahankan `.env` dan `volumes/`,
mengisi `IMAGE_TAG=<commit-sha>`, menjalankan `docker compose config`, pull,
up, dan bounded health verification. Source code, `.git`, `node_modules`,
vendor, build tree, secret, dan volume tidak pernah dikirim ke VPS.

Variabel umum yang diisi operator:

- `IMAGE_TAG` (workflow akan mengelola nilai commit SHA);
- `PLATFORM_DOMAIN` dan domain aplikasi;
- database credentials dan application secrets;
- external API/OAuth/SMTP/object-storage credentials.

## 5. Backup dan monitoring

Authentication Google Drive dilakukan manual sebagai `deploy`:

```bash
sudo -u deploy -H rclone config
sudo -u deploy -H rclone listremotes
sudo -u deploy -H rclone lsd gdrive-backup:
/srv/platform/backup/backup-doctor.sh
```

Monitoring UI bootstrap accounts, Beszel agent registration, dan Uptime Kuma
monitors dibuat melalui UI/integrasi setelah platform deployment. Profile
monitoring bersifat opsional; monitoring tidak menjadi dependency aplikasi.

## 6. Yang tidak boleh dilakukan manual rutin

- `git clone`, `git pull`, atau `docker build` untuk source di production;
- membuat shared network jika component `networks` dapat dideploy;
- menghapus `certs/`, `*-data/`, `staging/`, atau volume saat redeploy;
- memasukkan secret, private key, OAuth, atau populated `.env` ke Git;
- mengganti commit-SHA image dengan `latest`.

Emergency change harus dicatat dan direconcile kembali ke Git setelah incident.

## 7. Checklist

- [ ] Separate admin/deploy key pairs installed and tested.
- [ ] `PROD_KNOWN_HOSTS` contains a console-verified host key.
- [ ] SSH hardening verified; root/password SSH disabled.
- [ ] `platform-doctor.sh host` passes; Docker access works as `deploy`.
- [ ] Runtime `.env`, backup key, rclone config, and generated credentials are
      mode `600` and have recovery copies where applicable.
- [ ] `backup-doctor.sh` passes and a manual backup is visible in Drive.
- [ ] `Deploy Platform` completed with networks before dependents.
- [ ] Application manifest sync and application health checks pass.
- [ ] DNS, TLS, UI login, database, uploads/jobs, and monitoring tested.

## 8. Referensi

- [OPS-001 — Server Provisioning](OPS-001-server-provisioning.md)
- [OPS-002 — Deploy Application](OPS-002-deploy-application.md)
- [OPS-004 — Backup](OPS-004-backup.md)
- [OPS-005 — Restore](OPS-005-restore.md)
- [OPS-011 — Deploy Platform Service](OPS-011-deploy-platform-service.md)
- [OPS-012 — Migrate VPS Provider](OPS-012-migrate-vps-provider.md)
- [STD-005 — Environment Variables](../03-standards/STD-005-environment-variables.md)
- [STD-010 — Security Standard](../03-standards/STD-010-security-standard.md)
