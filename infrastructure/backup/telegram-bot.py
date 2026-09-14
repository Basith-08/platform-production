#!/usr/bin/env python3
"""Minimal private Telegram backup bot.

The bot only accepts commands from TELEGRAM_CHAT_ID and invokes the existing
run-backup.sh script as the deploy user. It uses Telegram long polling, so no
public webhook endpoint is required.
"""

import json
import os
import subprocess
import time
import urllib.parse
import urllib.request

TOKEN = os.environ["TELEGRAM_BOT_TOKEN"]
ALLOWED_CHAT_ID = int(os.environ["TELEGRAM_CHAT_ID"])
API_BASE = os.environ.get("TELEGRAM_API_BASE", "https://api.telegram.org").rstrip("/")
BACKUP_SCRIPT = "/srv/platform/backup/run-backup.sh"
POLL_TIMEOUT = 30


def api(method, params=None):
    params = params or {}
    data = urllib.parse.urlencode(params).encode()
    req = urllib.request.Request(
        f"{API_BASE}/bot{TOKEN}/{method}",
        data=data,
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=POLL_TIMEOUT + 15) as response:
        payload = json.load(response)
    if not payload.get("ok"):
        raise RuntimeError(f"Telegram API error: {payload}")
    return payload["result"]


def send_message(chat_id, text):
    return api("sendMessage", {"chat_id": chat_id, "text": text})


def handle_message(message):
    chat = message.get("chat", {})
    chat_id = chat.get("id")
    if chat_id != ALLOWED_CHAT_ID:
        return

    text = (message.get("text") or "").strip()
    if not text:
        return

    command = text.split()[0].split("@", 1)[0].lower()
    parts = text.split(maxsplit=1)
    argument = parts[1].strip() if len(parts) == 2 else ""

    if command in ("/start", "/help"):
        send_message(
            chat_id,
            "Production Backup Bot\n\n"
            "/backup - backup semua aplikasi + platform state\n"
            "/backup <app-name> - backup satu aplikasi\n"
            "/status - lihat backup doctor\n"
        )
        return

    if command == "/status":
        result = subprocess.run(
            ["/srv/platform/backup/backup-doctor.sh"],
            capture_output=True,
            text=True,
            timeout=120,
        )
        output = (result.stdout + result.stderr).strip()
        if len(output) > 3500:
            output = output[-3500:]
        send_message(
            chat_id,
            ("✅ Backup system ready\n\n" if result.returncode == 0
             else "❌ Backup system not ready\n\n") + output,
        )
        return

    if command == "/backup":
        if argument and not all(c.isalnum() or c == "-" for c in argument):
            send_message(chat_id, "❌ Invalid application name.")
            return

        target = argument
        send_message(
            chat_id,
            "⏳ Backup started..."
            + (f"\nTarget: {target}" if target else "\nTarget: all applications"),
        )

        cmd = [BACKUP_SCRIPT]
        if target:
            cmd.append(target)

        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=3600,
            )
            output = (result.stdout + result.stderr).strip()
        except subprocess.TimeoutExpired:
            send_message(chat_id, "❌ Backup timed out after 60 minutes.")
            return

        if len(output) > 3500:
            output = output[-3500:]

        if result.returncode == 0:
            send_message(chat_id, "✅ Backup completed successfully.\n\n" + output)
        else:
            send_message(chat_id, "❌ Backup failed.\n\n" + output)
        return

    send_message(chat_id, "Unknown command. Use /help.")


def main():
    offset = 0
    while True:
        try:
            updates = api(
                "getUpdates",
                {"offset": offset, "timeout": POLL_TIMEOUT},
            )
            for update in updates:
                offset = update["update_id"] + 1
                message = update.get("message")
                if message:
                    try:
                        handle_message(message)
                    except Exception as exc:
                        # Never expose the bot token or environment contents.
                        try:
                            send_message(
                                ALLOWED_CHAT_ID,
                                f"❌ Bot error: {type(exc).__name__}",
                            )
                        except Exception:
                            pass
        except Exception:
            time.sleep(5)


if __name__ == "__main__":
    main()
