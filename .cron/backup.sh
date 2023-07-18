#!/usr/bin/env bash

function email_message() {
    printf "<h1>Backup Failed!</h1>\n"
    printf "<p>Here was the log:</p>\n"
    printf "<pre style=\"background-color: black; color: white\">"
    cat /tmp/backup.log | ansi2html
    printf "</pre>\n"
}

printf "Beginning backup at $(date -Ins)..." >> /var/log/cron/backup.log
notify-send --app-name=Backup --icon=preferences-system-backup --urgency=CRITICAL "Backup" "Beginning backup..."
if $HOME/.dotfiles/script/backup.sh >> /var/log/cron/backup.log 2>&1; then
    notify-send --app-name=Backup --icon=preferences-system-backup "Backup" "Daily backup succeeded."
else
    notify-send --app-name=Backup --icon=preferences-system-backup --urgency=CRITICAL "Backup" "Daily backup failed."
    email_message | mailx -M "text/html" -s "Backup Failed" sorucoder@proton.me
fi