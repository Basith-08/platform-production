# Production backup component

This component creates GPG-symmetric encrypted backups of production
applications and non-regenerable platform state, then uploads the encrypted
archive to a private Telegram chat through the Telegram Bot API.

The scheduled backup runs as the `deploy` user. A private Telegram bot can
also trigger the same backup manually with `/backup`.

## Backup contents

For every application with a PostgreSQL `db` service:

- `db.sql` — PostgreSQL logical dump created with `pg_dump`.
- `volumes/` — non-database persistent volumes; `db-data/` is excluded.
- `.env` — application runtime configuration, protected inside the encrypted
  archive.

Platform backup includes existing non-regenerable state:

- `/srv/platform/traefik/.env`
- `/srv/platform/monitoring/.env`
- Beszel/Uptime Kuma persistent data when present.

The archive is created as:

```text
<app>-<UTC timestamp>.tar.gz.gpg
```

Plaintext staging is removed after encryption. The encrypted archive is sent
to Telegram and removed locally only after a successful upload.

## Encryption

Archives use symmetric GPG encryption with AES-256 and the passphrase stored
in:

```text
/srv/platform/backup/backup.key
```

`backup.key` is never included in the archive and must have a separate secure
recovery copy.

## Telegram configuration

Create a Telegram bot with `@BotFather`. Provision these runtime values in:

```text
/srv/platform/backup/backup.env
```

using `backup.env.example` as the template:

```env
TELEGRAM_BOT_TOKEN=...
TELEGRAM_CHAT_ID=...
TELEGRAM_API_BASE=https://api.telegram.org
BACKUP_MIN_FREE_GB=3
TELEGRAM_RETRIES=3
TELEGRAM_RETRY_DELAY_SECONDS=10
TELEGRAM_MAX_FILE_MB=49
```

`TELEGRAM_CHAT_ID` is an allowlist: the bot accepts commands only from this
chat ID and sends backup files to that chat.

Do not commit `backup.env`, the bot token, or `backup.key`.

## Scheduled backup

The deploy user's crontab runs:

```text
0 3 * * * /srv/platform/backup/run-backup.sh >> /var/log/platform/backup.log 2>&1
```

This is 03:00 UTC every day.

## Telegram bot

The bot uses long polling; no public webhook endpoint is required.

Systemd unit:

```text
telegram-backup-bot.service
```

Install after the backup component has been deployed:

```bash
sudo install -m 0644 \
  /srv/platform/backup/telegram-backup-bot.service \
  /etc/systemd/system/telegram-backup-bot.service

sudo systemctl daemon-reload
sudo systemctl enable --now telegram-backup-bot.service
sudo systemctl status telegram-backup-bot.service
```

Commands:

```text
/start
/help
/status
/backup
/backup <app-name>
```

Only the configured `TELEGRAM_CHAT_ID` can use these commands.

## Manual CLI

```bash
/srv/platform/backup/backup-doctor.sh
/srv/platform/backup/run-backup.sh
/srv/platform/backup/run-backup.sh invoice-api
```

The backup lock prevents concurrent backup runs.

## Failure behavior

If encryption succeeds but Telegram upload fails, the encrypted archive is
left in the staging directory for diagnosis/retry. Plaintext staging is
removed by the exit trap.

If the Telegram upload succeeds, the local encrypted archive is removed.

There is intentionally no rclone/Google Drive dependency in this component.

## Restore

The encrypted archive must first be recovered from Telegram and decrypted
using the separately retained `backup.key`. Restore procedures should be
documented and tested separately before relying on the backup for disaster
recovery.
