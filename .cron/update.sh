#!/usr/bin/env bash

function email_message() {
    printf "<h1>Update Failed!</h1>\n"
    printf "<p>Here was the log:</p>\n"
    printf "<pre style=\"background-color: black; color: white\">"
    tail -n 50 /tmp/update.log | ansi2html
    printf "</pre>\n"
}

printf "Beginning update on $(date -Ins)...\n" >> /var/log/cron/update.log
notify-send --app-name="System Update" --icon=system-software-update --urgency=CRITICAL "System Update" "Beginning system update..."
if ! paru --noconfirm | sed -e 's/\x1b\[[0-9;]*m//g' >> /var/log/cron/update.log 2>&1; then
    notify-send --app-name="System Update" --icon=system-software-update --urgency=CRITICAL "System Update" "Daily backup failed."
    email_message | mailx -M "text/html" -s "Update Failed" sorucoder@proton.me
fi
reboot
