#!/usr/bin/env bash

function email_message() {
    printf "<h1>Backup Failed!</h1>\n"
    printf "<p>Here was the log:</p>\n"
    printf "<pre style=\"background-color: black; color: white\">"
    cat /tmp/backup.log | ansi2html
    printf "</pre>\n"
}

notify-send --app-name=Backup --icon=preferences-system-backup --urgency=CRITICAL "Backup" "Beginning backup..."
if $HOME/.dotfiles/script/backup.sh &> /tmp/backup.log; then
    notify-send --app-name=Backup --icon=preferences-system-backup "Backup" "Daily backup succeeded."
else
    notify-send --app-name=Backup --icon=preferences-system-backup --urgency=CRITICAL "Backup" "Daily backup failed."
    email_message | mailx -M "text/html" -s "Backup Failed" sorucoder@proton.me
fi