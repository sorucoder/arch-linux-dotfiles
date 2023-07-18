#!/usr/bin/env bash

function email_message() {
    printf "<h1>Update Failed!</h1>\n"
    printf "<p>Here was the log:</p>\n"
    printf "<pre style=\"background-color: black; color: white\">"
    tail -n 50 /tmp/update.log | ansi2html
    printf "</pre>\n"
}

notify-send --app-name="System Update" --icon=system-software-update --urgency=CRITICAL "System Update" "Beginning system update..."
if ! paru --noconfirm &> /var/log/cron/update.log; then
    email_message | mailx -M "text/html" -s "Update Failed" sorucoder@proton.me
fi
reboot