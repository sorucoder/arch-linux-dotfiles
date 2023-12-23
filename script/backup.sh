#!/usr/bin/env bash

declare -A applications
declare option
logging=false
logfile=

function quit() {
    unset applications option logging logfile
    exit $1
}

function print_debug_message() {
    if ! $logging; then
        printf "\e[1m$@\e[0m"
    else
        printf "[$(date -Ins)] $@" >> $logfile
    fi
}

function print_success_message() {
    if ! $logging; then
        printf "\e[32m$@\e[0m\n"
    else
        printf "$@\n" >> $logfile
    fi
}

function print_failure_message() {
    if ! $logging; then
        printf "\e[31m$@\e[0m\n"
    else
        printf "$@\n" >> $logfile
    fi
}

function print_usage() {
    printf "Usage: $0 [OPTIONS]\n\n"
    
    printf "Generates a daily, encrypted, compressed, redundant, incremental backup.\n\n"
    
    printf "OPTIONS:\n"
    printf "\t-h, --help\t\tPrint this message.\n"
    printf "\t-l, --list\t\tOnly list the files that will be checked for backup.\n"
    printf "\t-c, --copy [YYYY-MM]\tOnly copy this (or the specified) month's backup to the remote host.\n"
    printf "\t-o, --output <file>\tOutput to a log file.\n"
}

function check_application() {
    local application=$1

    if [[ -z ${applications[$application]} ]]; then
        if which $application &> /dev/null; then
            applications[$application]=true
        else
            applications[$application]=false
        fi
    fi

    ${applications[$application]}
    return $?
}

function check_applications() {
    while [[ -n $1 ]]; do
        local application=$1

        if ! check_application $application; then
            return 1
        fi

        shift
    done
}

function search_files() {
    print_debug_message "Searching for files to backup..."

    local include_paths
    if [[ -r $BACKUP/include.txt ]]; then
        local include_path
        while read -r include_path; do
            include_paths+="$HOME/$include_path "
        done < $BACKUP/include.txt
    else
        include_paths=$HOME
    fi

    local find_pipe=$BACKUP/find_pipe
    if [[ -e $find_pipe ]]; then
        rm $find_pipe
    fi
    mkfifo $find_pipe
    find $include_paths -type f ! -path '.*/*' ! -path '*/.*' > $find_pipe &
    if [[ -r $BACKUP/exclude.txt ]]; then
        grep -vf $BACKUP/exclude.txt < $find_pipe > $BACKUP/list.txt
    else
        cat $find_pipe > $BACKUP/list.txt
    fi
    rm $find_pipe
    
    print_success_message "Found"
}

function compress_files() {
    if ! check_application tar; then
        print_debug_message "error: tar is not available\n"
        return 255
    fi

    print_debug_message "Compressing an incremental archive...\n"

    local success
    if ! $logging; then
        tar --create --gzip --absolute-names --verbatim-files-from --verbose --directory / --file $BACKUP/$(date +%Y-%m-%d).tar.gz --listed-incremental $BACKUP/$(date +%Y-%m).snar --files-from $BACKUP/list.txt
        success=$?
    else
        tar --create --gzip --absolute-names --verbatim-files-from --verbose --directory / --file $BACKUP/$(date +%Y-%m-%d).tar.gz --listed-incremental $BACKUP/$(date +%Y-%m).snar --files-from $BACKUP/list.txt >> $logfile
        success=$?
    fi
    if (( $success != 0 )); then
        print_failure_message "Failed"
        return 1
    fi

    print_success_message "Archived"
}

function encrypt_files() {
    if ! check_application gpg; then
        print_debug_message "error: gpg is not available\n"
        return 255
    fi

    print_debug_message "Encrypting the archive...\n"

    local success
    if ! $logging; then
        printf "$BACKUP/$(date +%Y-%m-%d).tar.gz -> "
    else
        printf "$BACKUP/$(date +%Y-%m-%d).tar.gz -> " >> $logfile
    fi
    gpg --quiet --batch --yes --recipient $BACKUP_GPG_RECIPIENT --trust-model always --output $BACKUP/$(date +%Y-%m-%d).tar.gz.gpg --encrypt $BACKUP/$(date +%Y-%m-%d).tar.gz 2>&1
    if (( $? == 0 )); then
        if ! $logging; then
            printf "$BACKUP/$(date +%Y-%m-%d).tar.gz.gpg\n"
        else
            printf "$BACKUP/$(date +%Y-%m-%d).tar.gz.gpg\n" >> $logfile
        fi
    else
        if ! $logging; then
            printf "\n"
        else
            printf "\n" >> $logfile
        fi
        print_failure_message "Failed"
        return 1
    fi

    print_success_message "Encrypted"
}

function check_remote_backup_directory() {
    if ! check_applications nmcli ssh; then
        print_debug_message "error: nmcli and/or ssh are not available\n"
        return 255
    fi

    if [[ $(nmcli --colors no networking connectivity) == "full" ]]; then
        print_debug_message "Checking remote backup directory..."

        ssh $BACKUP_HOST "(if [[ -d \$HOME/.restore/$HOSTNAME ]]; then echo 'exists'; fi)" 1> /tmp/ssh 2> /dev/null
        if (( $? != 0 )); then
            print_failure_message "Failed"
            return 1
        elif [[ -z $(cat /tmp/ssh) ]]; then
            print_success_message "Done"
            
            print_debug_message "Creating backup directory..."

            ssh $BACKUP_HOST "(mkdir -p \$HOME/.restore/$HOSTNAME)" &> /dev/null
            if (( $? != 0 )); then
                print_failure_message "Failed"
                return 2
            fi
        fi

        print_success_message "Done"
    else
        print_debug_message "error: not connected to the internet\n"
        return 128
    fi
}

function check_local_backup_files() {
    local month=$1
    if [[ -n $month ]]; then
        month=$(date +%Y-%m)
    fi

    if [[ -z $(find $BACKUP -name "$month-*.tar.gz.gpg" -or -name "$month.snar") ]]; then
        return 1
    fi
}

function copy_backup_files() {
    local month=$1
    if [[ -z $month ]]; then
        month=$(date +%Y-%m)
    fi

    if ! check_applications nmcli scp; then
        print_debug_message "error: nmcli and/or scp are not available\n"
        return 255
    fi

    if [[ $(nmcli --colors no networking connectivity) == "full" ]]; then
        print_debug_message "Copying $(date --date $month-01 '+%B, %Y') backup files to $BACKUP_HOST...\n"

        local success
        if ! $logging; then
            scp -BC $BACKUP/$month-*.tar.gz.gpg $BACKUP_HOST:/home/sorucoder/.restore/$HOSTNAME
            success=$?
        else
            scp -BC $BACKUP/$month-*.tar.gz.gpg $BACKUP_HOST:/home/sorucoder/.restore/$HOSTNAME >> $logfile
            success=$?
        fi
        if (( $success != 0 )); then
            print_failure_message "Failed"
            return 1
        fi

        print_success_message "Done"
    else
        print_debug_message "error: not connected to the internet\n"
        return 128
    fi
}

function remove_unencrypted_files() {
    print_debug_message "Removing unencrypted backup files..."
    
    if [[ -n $(ls $BACKUP/*.tar.gz) ]]; then
        rm $BACKUP/*.tar.gz
    fi

    print_success_message "Done"
}

function send_backups() {
    local month=$1
    if [[ -z $month ]]; then
        month=$(date +%Y-%m)
    fi

    if check_local_backup_files $month; then
        check_remote_backup_directory && \
        copy_backup_files $month && \
        remove_unencrypted_files
    fi
}

function backup() {
    search_files && \
    compress_files && \
    encrypt_files
    if [[ -n $BACKUP_HOST ]]; then
        send_backups
    fi
}

function view_files() {
    search_files
    if check_application tree; then
        tree --fromfile $BACKUP/list.txt | less
    else
        less $BACKUP/list.txt
    fi
}

while [[ $1 =~ ^--? ]]; do
    option=$1
    if [[ $option == -h || $option == --help ]]; then
        print_usage
        quit 0
    elif [[ $option == -l || $option == --list ]]; then
        view_files
        quit 0
    elif [[ $option == -c || $option == --copy ]]; then
        shift
        if [[ -n $1 ]]; then
            if [[ $1 =~ [0-9]{4}-[0-9]{2} ]]; then
                send_backups $1
            else
                print "\e[31merror: incorrect format for month (must be YYYY-MM)\e[0m\n" > /dev/stderr
            fi
        else
            send_backups
        fi 
        quit $?
    elif [[ $option == -o || $option == --output ]]; then
        logging=true
        shift; logfile=$1
        if [[ -z $logfile ]]; then
            printf "\e[31merror: option \"output\" requires a file path\e[0m\n"
            print_usage
        fi
    else
        printf -- "\e[31merror: unknown option %s\e[0m\n" $option > /dev/stderr
        print_usage > /dev/stderr
        quit 1
    fi
done

if [[ -z $BACKUP ]]; then
    print_debug_message "Setting \$BACKUP to $HOME/.backup..."
    export BACKUP=$HOME/.backup
    print_success_message "Set"
fi

if [[ ! -d $BACKUP ]]; then
    print_debug_message "Creating \$BACKUP directory..."
    if [[ -e $BACKUP ]]; then
        rm $BACKUP
        if (( $? != 0 )); then
            print_failure_message "Failed"
            print_debug_message "Cannot remove non-directory \"$BACKUP\"\n"
        fi
    fi

    mkdir -p $BACKUP
    if (( $? != 0 )); then
        print_failure_message "Failed"
        print_debug_message "Cannot create directory \"$BACKUP\"\n"
    fi
fi

backup
quit $?