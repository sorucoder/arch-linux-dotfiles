#!/usr/bin/env bash

declare -A applications
declare option

function quit() {
    unset applications option
    exit $1
}

function pretty_print_month() {
    local date=$1
    if [[ -n $date ]]; then
        date --date "$date-01" "+%B, %Y"
    else
        date "+%B, %Y"
    fi
}

function print_usage() {
    printf "Usage: $0 [OPTIONS]\n\n"
    
    printf "Generates a compressed, redundant, incremental (daily), encrypted, daily backup.\n\n"
    
    printf "OPTIONS:\n"
    printf "\t-h, --help\t\tPrint this message.\n"
    printf "\t-l, --list\t\tOnly list the files to be backed up today.\n"
    printf "\t-c, --copy [YYYY-MM]\tOnly copy this (or the specified) month's backup to the remote host.\n"
}

function check_application() {
    local application=$1

    if [[ -z ${application[$application]} ]]; then
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
    printf "\e[1mSearching for all files to backup...\e[0m "
    local include_paths
    if [[ -r $BACKUP/include.txt ]]; then
        local include_path
        while read -r include_path; do
            include_paths+="$HOME/$include_path "
        done < $BACKUP/include.txt
    else
        include_paths=$HOME
    fi
    find $include_paths -regextype posix-extended -type f ! -path '.*/*' ! -path '*/.*' -exec realpath --relative-to $HOME {} \; > /tmp/backup_list.txt
    if [[ -r $BACKUP/exclude.txt ]]; then
        grep -vf $BACKUP/exclude.txt /tmp/backup_list.txt > $BACKUP/backup_list.txt
    else
        cp /tmp/backup_list.txt $BACKUP/backup_list.txt
    fi
    printf "\e[32mDone\e[0m\n"
}

function compress_backup_files() {
    printf "\e[1mCompressing incremental backup archive...\e[0m "
    if ! tar --create --gzip --directory $HOME --file $BACKUP/$(date +%Y-%m-%d).tar.gz --listed-incremental $BACKUP/$(date +%Y-%m).snar --files-from $BACKUP/backup_list.txt &> /dev/null; then
        printf "\e[31mFailed\e[0m\n"
        return 1
    fi
    printf "\e[32mDone\e[0m\n"
}

function encrypt_backup_files() {
    if ! check_application gpg; then
        printf "\e[31merror: gpg is not available\e[0m\n" > /dev/stderr
        printf "\e[3mRun $HOME/.dotfiles/install/networking to ensure GPG is properly configured.\e[0m\n" > /dev/stderr
        return 255
    elif [[ ! -e $HOME/.gnupg/$HOSTNAME.key ]]; then
        printf "\e[31merror: $HOME/.gnupg/$HOSTNAME.key does not exist\e[0m\n" > /dev/stderr
        printf "\e[3mRun $HOME/.dotfiles/install/networking to ensure GPG is properly configured.\e[0m\n" > /dev/stderr
        return 254
    fi

    printf "\e[1mEncrypting backup archive...\e[0m\n"
    printf "$BACKUP/$(date +%Y-%m-%d).tar.gz -> "
    if ! gpg --quiet --batch --yes --recipient sorucoder@proton.me --trust-model always --output $BACKUP/$(date +%Y-%m-%d).tar.gz.gpg --encrypt $BACKUP/$(date +%Y-%m-%d).tar.gz; then
        printf "\e[32mFailed\e[0m\n"
        return 1
    fi
    printf "$BACKUP/$(date +%Y-%m-%d).tar.gz.gpg\n"
    backup=$backup.gpg
    printf "\e[32mDone\e[0m\n"
}

function prepare_files() {
    search_files
    if ! compress_backup_files; then
        return 1
    elif ! encrypt_backup_files; then
        return 2
    fi
}

function check_remote_backup_directory() {
    if ! check_applications nmcli ssh; then
        printf "\e[31merror: nmcli and/or ssh are not available\e[0m\n" > /dev/stderr
        printf "\e[3mRun $HOME/.dotfiles/install/networking.sh to ensure networking and SSH are properly configured.\e[0m\n" > /dev/stderr
        return 255
    fi

    if [[ $(nmcli --colors no networking connectivity) == "full" ]]; then
        printf "\e[1mChecking remote backup directory...\e[0m "
        if ! ssh $BACKUP_HOST "(if [[ -d \$HOME/.restore/$HOSTNAME ]]; then echo 'exists'; fi)" 1> /tmp/ssh 2> /dev/null; then
            printf "\e[31mFailed\e[0m\n"
            printf "\e[3mRun $HOME/.dotfiles/install/networking to ensure SSH is correctly configured.\e[0m\n" > /dev/stderr
            return 2
        elif [[ -z $(cat /tmp/ssh) ]]; then
            printf "\e[32mDone\e[0m\n"
            printf "\e[1mCreating backup directory...\e[0m "
            if ! ssh $BACKUP_HOST "(mkdir -p \$HOME/.restore/$HOSTNAME)" &> /dev/null; then
                printf "\e[31mFailed\e[0m\n"
                printf "\e[3mRun $HOME/.dotfiles/install/networking to ensure SSH is correctly configured.\e[0m\n" > /dev/stderr
                return 3
            fi
        fi
        printf "\e[32mDone\e[0m\n"
    else
        printf "\e[31merror: not connected to the internet\e[0m\n" > /dev/stderr
        return 1
    fi
}

function check_backup_files() {
    local month=$1
    if [[ -n $month ]]; then
        month=$(date +%Y-%m)
    fi

    if [[ -z $(find $BACKUP -name "$month-*.tar.gz.gpg" -or -name "$month.snar") ]]; then
        return 1
    fi
}

function copy_backup_files_to_remote() {
    local month=$1
    if [[ -z $month ]]; then
        month=$(date +%Y-%m)
    fi

    if ! check_applications nmcli scp; then
        printf "\e[31merror: nmcli and/or scp are not available\e[0m\n" > /dev/stderr
        printf "\e[3mRun $HOME/.dotfiles/install/networking.sh to ensure networking and SSH are properly configured.\e[0m\n" > /dev/stderr
        return 255
    fi

    if [[ $(nmcli --colors no networking connectivity) == "full" ]]; then
        printf "\e[1mSending %s backup files remotely...\e[0m\n" "$(pretty_print_month $month)"
        if ! scp -BC $BACKUP/$month-*.tar.gz.gpg $BACKUP_HOST:/home/sorucoder/.restore/$HOSTNAME; then
            printf "\e[31mFailed\e[0m\n"
            printf "\e[3mRun $HOME/.dotfiles/install/networking to ensure SSH is correctly configured.\e[0m\n" > /dev/stderr
            return 2
        fi
        printf "\e[32mDone\e[0m\n"
    else
        printf "\e[31merror: not connected to the internet\e[0m\n" > /dev/stderr
        return 1
    fi
}

function remove_unencrypted_files() {
    printf "\e[1mRemoving unencrypted backup files...\e[0m "
    if [[ -n $(ls $BACKUP/*.tar.gz) ]]; then
        rm $BACKUP/*.tar.gz
    fi
    printf "\e[32mDone\e[0m\n"
}

function send_backups() {
    local month=$1
    if [[ -z $month ]]; then
        month=$(date +%Y-%m)
    fi

    if ! check_applications nmcli ssh scp; then
        printf "\e[31merror: nmcli, ssh, scp and/or cat are not available\e[0m\n" > /dev/stderr
        printf "\e[3mRun $HOME/.dotfiles/install/networking.sh to ensure networking and SSH are properly configured.\e[0m\n" > /dev/stderr
        return 255
    fi

    if check_backup_files $month; then
        if ! check_remote_backup_directory; then
            return 3
        fi

        if ! copy_backup_files_to_remote $month; then
            return 4
        fi

        if ! remove_unencrypted_files; then
            return 5
        fi
    fi
}

function backup() {
    if prepare_files; then
        send_backups
    fi
}

function view_files() {
    search_files
    if check_application tree; then
        tree --fromfile $BACKUP/backup_list.txt > $BACKUP/backup_tree.txt
        less $BACKUP/backup_tree.txt
    else
        less $BACKUP/backup_list.txt
    fi
}

# Ensure backup directory
if [[ ! -d $BACKUP ]]; then
    if [[ -e $BACKUP ]]; then
        rm $BACKUP
    fi
    mkdir -p $BACKUP
fi

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
                printf "\e[31merror: incorrect format for month (must be YYYY-MM)\e[0m\n" > /dev/stderr
            fi
        else
            send_backups
        fi 
        quit $?
    else
        printf -- "\e[31merror: unknown option %s\e[0m\n" $option > /dev/stderr
        print_usage > /dev/stderr
        quit 1
    fi
done

backup
quit $?