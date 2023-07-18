#!/usr/bin/env bash

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

function install_package() {
    local package=$1; shift
	local name=$1

    if ! check_application paru; then
		printf "\e[31merror: paru is not available\e[0m\n"
		printf "\e[3mGo to https://github.com/Morganamilo/paru for installation instructions.\e[0m\n"
		return 1
    fi
        
    if ! paru -Qs "^$package\$" &> /dev/null; then
        printf "\e[1mInstalling package $name...\e[0m "
        paru -S --noconfirm $package &> /dev/null
        printf "\e[32mInstalled\e[0m\n"
    fi
}

function employ_service() {
    local service=$1; shift
    local name=$1

    local response

    if ! sudo systemctl --quiet is-enabled $service.service; then
        printf "\e[1mEnabling service $name...\e[0m "
        if sudo systemctl enable $service.service &> /dev/null; then
            printf "\e[32mEnabled\e[0m\n"

            printf "Would you like to start service $name now? \e[1m[Y/n]\e[0m "
            read -n 1 response
            if [[ -n $response ]]; then
                if [[ $response != Y || $response != y ]]; then
                    printf "\n"
                    printf "\e[3mMake sure to run this script again to complete installation.\e[0m\n"
                    return 255
                fi
            fi
        else
            printf "\e[31mNot Enabled\e[0m\n"
            printf "\e[31merror: cannot enable service $name\e[0m\n"
            return 2
        fi
    fi

    if ! sudo systemctl is-active $service.service &> /dev/null; then
        printf "\e[1mStarting service $name...\e[0m "
        if sudo systemctl start $service.service; then
            printf "\e[32mStarted\e[0m\n"
        else
            printf "\e[31mNot Enabled\e[0m\n"
            printf "\e[31merror: cannot enable service $name\e[0m\n"
            return 3
        fi
    else
        printf "\e[1mReloading or restarting service $name...\e[0m "
        if sudo systemctl reload-or-restart $service.service &> /dev/null; then
            printf "\e[32mDone\e[0m\n"
        else
            printf "\e[31mNot Enabled\e[0m\n"
            printf "\e[31merror: cannot enable service $name\e[0m\n"
            return 4
        fi
    fi
}

function initialize_cronie() {
    printf "\e[1mApplying crontab...\e[0m "
    if ! fcrontab $HOME/.cron/crontab &> /dev/null; then
        printf "\e[31mFailed\e[0m\n"
        return 3
    fi
    printf "\e[32mDone\e[0m\n"
}

install_package fcron "fcron" && \
initialize_cronie && \
employ_service fcron "fcron"