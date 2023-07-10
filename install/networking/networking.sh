#!/usr/bin/env bash

declare tailscale_up tailscale_peers
declare -a tailscale_addresses tailscale_names
declare -A applications

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

function quit() {
    unset hostname tailscale_up tailscale_peers tailscale_names tailscale_addresses applications
    exit $1
}

function install_package() {
    local package=$1; shift
	local name=$1

    if check_application paru; then
		if ! paru -Qs "^$package\$" &> /dev/null; then
			printf "\e[1mInstalling package $name...\e[0m "
			paru -S --noconfirm $package &> /dev/null
            printf "\e[32mInstalled\e[0m\n"
		fi
        return 0
	else
	    printf "\e[31merror: paru is not available\e[0m\n"
		printf "\e[3mGo to https://github.com/Morganamilo/paru for installation instructions.\e[0m\n"
		return 1
	fi
}

function employ_service() {
    local service=$1; shift
    local name=$1

    local response

    if ! check_application systemctl || ! check_application grep; then
        printf "\e[31merror: systemctl and/or grep is not available\e[0m\n"
        printf "\e[3mAre you running this on an Arch Linux system?\e[0m\n"
        return 1
    fi

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
    fi

    return 0
}

function initialize_tailscale() {
    if ! check_application tailscale; then
        printf "\e[31merror: tailscale was not properly installed.\e[0m\n"
		printf "\e[3mPlease try removing tailscale and try this script again.\e[0m\n"
		return 1
    elif ! check_application tr || ! check_application cut; then
        printf "\e[31merror: systemctl, uname and/or grep is not available\e[0m\n"
        printf "\e[3mAre you running this on an Arch Linux system?\e[0m\n"
        return 1
    fi

    if [[ -z $tailscale_up ]]; then
        printf "\e[1mEstablishing connection to Tailscale..."
        sudo tailscale up
        if (( $? != 0 )); then
            printf "\e[31merror: cannot establish connection to Tailscale\e[0m\n"
            print "\e[3mPlease try again later.\e[0m\n"
            tailscale_up=false
            return 2
        fi
        printf "\e[0m\e[32mDone\e[0m\n"

        for host in $(tailscale status | grep -Ev '^(#.*)?$'| tr -s " " "," | cut -f 1,2); do
            tailscale_addresses+=("$(cut -d , -f 1 <<< $host)")
            tailscale_names+=("$(cut -d , -f 2 <<< $host)")
        done
        tailscale_peers=${#tailscale_addresses[@]}

        taiscale_up=true
    fi
    return 0
}

function update_hosts() {
    if ! $tailscale_up; then
        printf "\e[31merror: tailscale was not properly initialized.\e[0m\n"
		printf "\e[3mPlease try this script again.\e[0m\n"
        return 1
    fi

    printf "\e[1mUpdating /etc/hosts...\e[0m "
    printf "# Localhost\n" > /tmp/hosts
    printf "127.0.0.1\tlocalhost\n\n" >> /tmp/hosts
    printf "# Tailscale Hosts\n" >> /tmp/hosts
    local index address name
    for (( index = 0; index < tailscale_peers; index++ )); do
        address=${tailscale_addresses[$index]}
        name=${tailscale_names[$index]}
        if [[ $name != $HOSTNAME ]]; then
            printf "%s\t%s\n" $address $name >> /tmp/hosts
        fi
    done
    sudo cp /tmp/hosts /etc/hosts
    printf "\e[32mDone\e[0m\n"
}

function update_ssh() {
    if ! $tailscale_up; then
        printf "\e[31merror: tailscale was not properly initialized.\e[0m\n"
		printf "\e[3mPlease try this script again.\e[0m\n"
        return 1
    elif ! check_application ssh_keygen; then
        printf "\e[31merror: ssh was not properly installed.\e[0m\n"
		printf "\e[3mPlease try removing ssh and try this script again.\e[0m\n"
		return 1
    elif ! check_application cp || ! check_application mkdir; then
        printf "\e[31merror: cp and/or mkdir is not available\e[0m\n"
        printf "\e[3mAre you running this on an Arch Linux system?\e[0m\n"
        return 1
    fi

    if [[ ! -d $HOME/.ssh ]]; then
        printf "\e[1mMaking $HOME/.ssh directory...\e[0m "
        mkdir -p $HOME/.ssh
        printf "\e[32mDone\e[0m\n"
    fi

    if [[ ! -r $HOME/.ssh/$HOSTNAME ]]; then
        printf "\e[1mGenerating public and private SSH keys...\e[0m "
        ssh-keygen -t ed25519 -C "$USER@$HOSTNAME" -f $HOME/.ssh/$HOSTNAME -N ""
        eval "$(ssh-agent -s)"
        ssh-add $HOME/.ssh/$HOSTNAME
        printf "\e[32mDone\e[0m\n"
    fi

    if [[ ! -r $HOME/.gnupg/$HOSTNAME.key ]]; then
        printf "\e[1mGenerating public and private GPG keys...\e[0m "
        gpg --full-gen-key
        gpg --output $HOME/.gnupg/$HOSTNAME.key --armor --export sorucoder@proton.me
        printf "\e[32mDone\e[0m\n"
    fi

    printf "\e[1mGenerating client configuation...\e[0m "
    printf "# Github\n" > $HOME/.ssh/config
    printf "Host github.com\n" >> $HOME/.ssh/config
    printf "\tUser git\n" >> $HOME/.ssh/config
    printf "\tIdentityFile %s\n\n" $HOME/.ssh/$HOSTNAME >> $HOME/.ssh/config
    printf "# Tailscale Hosts\n" >> $HOME/.ssh/config
    local index name
    for (( index = 0; index < tailscale_peers; index++ )); do
        name=${tailscale_names[$index]}
        if [[ $name != $HOSTNAME ]]; then
            printf "Host %s\n" $name >> $HOME/.ssh/config
            printf "\tHostname %s\n" $name >> $HOME/.ssh/config
            printf "\tUser %s\n" $USER >> $HOME/.ssh/config
            printf "\tIdentityFile %s\n\n" $HOME/.ssh/$HOSTNAME >> $HOME/.ssh/config
        fi
    done
    printf "\e[32mDone\e[0m\n"

    printf "\e[1mCopying daemon configuation...\e[0m "
    if [[ -e /etc/ssh/sshd_config ]]; then
        sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
    fi
    sudo cp $HOME/.dotfiles/install/networking/sshd_config /etc/ssh/sshd_config
    printf "\e[32mDone\e[0m\n"

    printf "\e[1mRestarting daemon...\e[0m "
    if ! sudo systemctl restart sshd; then
        printf "\e[31mFailed\e[0m\n"
        return 2
    fi
    printf "\e[32mDone\e[0m\n"
}

install_package networkmanager "NetworkManager" && \
employ_service NetworkManager "NetworkManager"
if (( $? != 0 )); then
    quit $?
fi

if [[ $DESKTOP_SESSION == "plasma" ]]; then
    install_package plasma-nm "Plasma Network Manager Configuation"
fi

install_package tailscale "Tailscale" && \
employ_service tailscaled "Tailscale" && \
initialize_tailscale && \
update_hosts
if (( $? != 0 )); then
    quit $?
fi

install_package openssh "Secure Shell" && \
employ_service sshd "Secure Shell" && \
update_ssh
quit $?