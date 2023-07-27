#!/usr/bin/env bash

function email_message() {
    printf "<h1>Backup Failed!</h1>\n"
    printf "<p>Here was the log:</p>\n"
    printf "<pre style=\"background-color: black; color: white\">"
    cat /tmp/backup.log | ansi2html
    printf "</pre>\n"
}

printf "Beginning backup at $(date -Is)...\n" >> /var/log/cron/backup.log
if $HOME/.dotfiles/script/backup.sh -o /var/log/cron/backup.log; then
    printf "Backup succeeeded" >> /var/log/cron/backup.log
else
	printf "Backup failed" >> /var/log/cron/backup.log
    email_message | mailx -M "text/html" -s "Backup Failed" sorucoder@proton.me
fi
