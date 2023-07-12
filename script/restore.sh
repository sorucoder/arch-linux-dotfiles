#!/usr/bin/env bash

declare -A applications
declare option remote

function quit() {
    unset applications option remote
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

function pretty_print_date() {
    local date=$1
    if [[ -n $date ]]; then
        date --date "$date" "+%A, %B %_d, %Y"
    else
        date "+%A, %B %_d, %Y"
    fi
}

function print_usage() {
    printf "Usage: $0 [OPTIONS] <DATE>\n\n"
    
    printf "Restores a compressed, redundant, incremental (daily), encrypted, daily backup.\n"
    printf "First, this script will try to restore with local backups, then remote.\n\n"
    
    printf "OPTIONS:\n"
    printf "\t-h, --help\t\tPrint this message.\n"
    printf "\t-l, --list\t\tOnly list the files to be backed up this.\n"
    printf "\t-r, --remote\t\tOnly attempt a restore with a remote backup.\n"
    printf "\t-R, --local\t\tOnly attempt a restore with a local backup.\n"
    printf "\t-c, --copy [YYYY-MM]\tOnly copy this (or the specified) month's backup from the remote host.\n"
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
            printf "\e[31mNot Found\e[0m\n"
            printf "\e[3mRun $HOME/.dotfiles/script/backup.sh to generate a backup.\e[0m\n" > /dev/stderr
            return 3
        fi
        printf "\e[32mDone\e[0m\n"
    else
        printf "\e[31merror: not connected to the internet\e[0m\n" > /dev/stderr
        return 1
    fi
}

function check_remote_backup_files() {
    local month=$1
    if [[ -z $month ]]; then
        month=$(date +%Y-%m)
    fi

    if ! check_applications nmcli ssh; then
        printf "\e[31merror: nmcli and/or ssh are not available\e[0m\n" > /dev/stderr
        printf "\e[3mRun $HOME/.dotfiles/install/networking.sh to ensure networking and SSH are properly configured.\e[0m\n" > /dev/stderr
        return 255
    fi

    if [[ $(nmcli --colors no networking connectivity) == "full" ]]; then
        printf "\e[1mChecking remote backup files for %s...\e[0m " "$(pretty_print_month $month)"
        if ! ssh $BACKUP_HOST "(find \$HOME/.restore/$HOSTNAME/ -name '$month-*.tar.gz.gpg' -or -name '$month.snar')" 1> /tmp/ssh 2> /dev/null; then
            printf "\e[31mFailed\e[0m\n"
            printf "\e[3mRun $HOME/.dotfiles/install/networking to ensure SSH is correctly configured.\e[0m\n" > /dev/stderr
            return 2
        elif [[ -z $(cat /tmp/ssh) ]]; then
            printf "\e[31mNot Found\e[0m\n"
            return 3
        fi
        printf "\e[32mDone\e[0m\n"
    else
        printf "\e[31merror: not connected to the internet\e[0m\n" > /dev/stderr
        return 1
    fi
}

function check_local_backup_files() {
    local month=$1
    if [[ -z $month ]]; then
        month=$(date +%Y-%m)
    fi

    printf "\e[1mChecking local backup files for %s...\e[0m " "$(pretty_print_month $month)"
    if [[ -z $(find $BACKUP -name "$month-*.tar.gz.gpg" -or -name "$month.snar") ]]; then
        printf "\e[31mNot Found\e[0m\n"
        return 1
    fi
    printf "\e[32mDone\e[0m\n"
}

function check_local_backup_archive() {
    printf "\e[1mChecking local backup files for %s...\e[0m " "$(pretty_print_date $date)"
    if [[ ! -r $BACKUP/$date.tar.gz ]]; then
        printf "\e[31mNot Found\e[0m\n"
        return 1
    fi
    printf "\e[32mDone\e[0m\n"
}

function copy_backup_files_from_remote() {
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
        printf "\e[1mReceiving %s backup files remotely...\e[0m\n" "$(pretty_print_month $month)"
        if ! scp -BC $BACKUP_HOST:/home/sorucoder/.restore/$HOSTNAME/$month-*.tar.gz.gpg $BACKUP; then
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

function decrypt_backup_files() {
    local month=$1
    if [[ -z $month ]]; then
        month=$(date +%Y-%m)
    fi

    if ! check_application gpg; then
        printf "\e[31merror: gpg is not available\e[0m\n" > /dev/stderr
        printf "\e[3mRun $HOME/.dotfiles/install/networking to ensure GPG is properly configured.\e[0m\n" > /dev/stderr
        return 255
    elif [[ ! -e $HOME/.gnupg/$HOSTNAME.key ]]; then
        printf "\e[31merror: $HOME/.gnupg/$HOSTNAME.key does not exist\e[0m\n" > /dev/stderr
        printf "\e[3mRun $HOME/.dotfiles/install/networking to ensure GPG is properly configured.\e[0m\n" > /dev/stderr
        return 254
    fi

    printf "\e[1mDecrypting backup archives...\e[0m\n"
    local backup
    for backup in $(ls $BACKUP/*.tar.gz.gpg | sort); do
        printf "$backup -> "
        if ! gpg --quiet --batch --yes --recipient sorucoder@proton.me --trust-model always --output ${backup%.gpg} --decrypt $backup; then
            printf "\e[32mFailed\e[0m\n"
            return 1
        fi
        printf "${backup%.gpg}\n"
    done
    printf "\e[32mDone\e[0m\n"
}

function decompress_backup_file() {
    local date=$1
    if [[ -z $day ]]; then
        date=$(date +%Y-%m-%d)
    fi

    if ! check_local_backup_archive; then
        return 1
    fi

    printf "\e[1mDecompressing incremental backup archives...\e[0m "
    local backup
    for backup in "$(ls $BACKUP/*.tar.gz | sort)"; do
        if [[ $backup != $BACKUP/$date.tar.gz ]]; then
            if ! tar --extract --gunzip --directory $HOME --file $backup --listed-incremental /dev/null; then
                printf "\e[31mFailed\e[0m\n"
                return 2
            fi
        else
            break
        fi
    done
    printf "\e[32mDone\e[0m\n"
}

function remove_unencrypted_files() {
    printf "\e[1mRemoving unencrypted backup files...\e[0m "
    if ! rm $BACKUP/*.tar.gz; then
        printf "\e[31mFailed\e[0m\n"
        return 1
    fi
    printf "\e[32mDone\e[0m\n"
}

function restore_remote() {
    local date=$1

    if [[ -z $date ]]; then
        date=$(date +%Y-%m-%d)
    fi
    local month=${date%-*}

    if ! check_remote_backup_directory; then
        return 1
    fi

    if ! check_remote_backup_files $month; then
        return 2
    fi

    if ! copy_backup_files_from_remote $month; then
        return 3
    fi

    if ! decrypt_backup_files $month; then
        return 4
    fi

    if ! decompress_backup_file $date; then
        return 5
    fi
}

function restore_local() {
    local date=$1

    if [[ -z $date ]]; then
        date=$(date +%Y-%m-%d)
    fi
    local month=${date%-*}

    if ! check_local_backup_files $month; then
        return 1
    fi

    if ! decrypt_backup_files $month; then
        return 2
    fi

    if ! decompress_backup_file $date; then
        return 3
    fi
}

function restore() {
    if [[ -z $remote ]]; then
        if ! restore_remote; then
            if ! restore_local; then
                return 1
            fi
        fi
    elif $remote; then
        if ! restore_remote; then
            return 1
        fi
    else
        if ! restore_local; then
            return 1
        fi
    fi
}

function retrieve_pre_restore_files() {
    printf "\e[1mRetrieving pre-restore list...\e[0m "
    local include_paths
    if [[ -r $BACKUP/include.txt ]]; then
        local include_path
        while read -r include_path; do
            include_paths+="$HOME/$include_path "
        done < $BACKUP/include.txt
    else
        include_paths=$HOME
    fi
    find $include_paths -regextype posix-extended -type f ! -path '.*/*' ! -path '*/.*' > /tmp/restore_before_list.txt
    if [[ -r $BACKUP/exclude.txt ]]; then
        grep -vf $BACKUP/exclude.txt /tmp/restore_before_list.txt > $BACKUP/restore_before_list.txt
    else
        cp /tmp/restore_before_list.txt $BACKUP/restore_before_list.txt
    fi
    printf "\e[32mDone\e[0m\n"
}

function retrieve_post_restore_files() {
    local date=$1
    if [[ -z $day ]]; then
        date=$(date +%Y-%m-%d)
    fi

    if ! check_local_backup_archive; then
        return 1
    fi

    printf "\e[1mRetrieving post-restored file list...\e[0m "
    local backup
    cp $BACKUP/restore_before_list.txt $BACKUP/restore_after_list.txt
    for backup in $(ls $BACKUP/*.tar.gz | sort); do
        if [[ $backup != $BACKUP/$date.tar.gz ]]; then
            if ! tar --list --gunzip --directory $HOME --file $backup --listed-incremental /dev/null 1> /tmp/restore_after_extract_list.txt; then
                printf "\e[31mFailed\e[0m\n"
                return 2
            fi
            diff -u $BACKUP/restore_after_list.txt /tmp/restore_after_extract_list.txt | patch $BACKUP/restore_after_list.txt
        else
            break
        fi
    done
    printf "\e[32mDone\e[0m\n"
}

function view_files() {
    local date=$1

    if [[ -z $date ]]; then
        date=$(date +%Y-%m-%d)
    fi
    local month=${date%-*}

    if ! check_local_backup_files $month; then
        return 1
    fi

    if ! decrypt_backup_files $month; then
        return 2
    fi

    if ! retrieve_pre_restore_files $date; then
        return 3
    fi
    
    if ! retrieve_post_restore_files $date; then
        return 4
    fi

    if check_application tree; then
        tree --fromfile $BACKUP/restore_before_list.txt > $BACKUP/restore_before_tree.txt
        tree --fromfile $BACKUP/restore_after_list.txt > $BACKUP/restore_after_tree.txt
        diff --side-by-side $BACKUP/restore_before_tree.txt $BACKUP/restore_after_tree.txt
    else
        diff --side-by-side $BACKUP/restore_before_list.txt $BACKUP/restore_after_list.txt
    fi
}

while [[ $1 =~ ^--? ]]; do
    option=$1
    if [[ $option == -h || $option == --help ]]; then
        print_usage
        quit 0
    elif [[ $option == -l || $option == --list ]]; then
        # TODO: Verify this works
        view_files
        quit 0
    elif [[ $option == -r || $option == --remote ]]; then
        remote=true
    elif [[ $option == -l || $option == --local ]]; then
        remote=false
    fi
    shift
done

restore
quit $?