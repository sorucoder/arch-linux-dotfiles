#!/usr/bin/env bash

declare -A applications

function quit() {
    unset applications
    exit $1
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

function install_package() {
    local package=$1; shift
	local name=$1

    if check_application paru; then
		if ! paru -Qs "^$package\$" &> /dev/null; then
			printf "\e[2mInstalling package $name...\e[0m "
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

function install_dotfile() {
	local source=$1; shift
	local destination=$1; shift
    local name=$1

    if ! check_application rm || ! check_application ln; then
        printf "\e[31merror: rm and/or ln is not available\e[0m\n"
        printf "\e[3mAre you running this on an Arch Linux system?\e[0m\n"
        return 1
    fi

	if [[ ! -h $destination ]]; then
		printf "\e[2mInstalling $name...\e[0m"; fi
		if [[ -e $destination ]]; then
            rm $destination;
        fi
		ln -s $source $destination
	fi
}

install_package konsole "Konsole" && \
install_package powerline "Powerline" && \
install_package 3270-fonts "IBM 3270 fonts" && \
install_package ansi2html "ansi2html" && \
install_dotfile $HOME/.konsole/konsolerc $HOME/.config/konsolerc "Konsole general configuration" && \
install_dotfile $HOME/.konsole/Oldschool.profile $HOME/.local/share/konsole/Oldschool.profile "Konsole profile" && \
install_dotfile $HOME/.konsole/Pure.colorscheme $HOME/.local/share/konsole/Pure.colorscheme "Konsole color scheme"
