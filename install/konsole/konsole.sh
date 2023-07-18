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

function initialize_konsole() {
    printf "\e[1mCopying configuration files for Konsole...\e[0m "
    if ! cp $HOME/.dotfiles/install/konsole/konsolerc $HOME/.config/konsolerc/; then
        printf "\e[31mFailed\e[0m\n"
        return 1
    fi
    if ! cp $HOME/.dotfiles/install/konsole/Oldschool.profile $HOME/.local/share/konsole/; then
        printf "\e[31mFailed\e[0m\n"
        return 2
    fi
    if ! cp $HOME/.dotfiles/install/konsole/Pure.colorscheme $HOME/.local/share/konsole/; then
        printf "\e[31mFailed\e[0m\n"
        return 2
    fi
    printf "\e[32mDone\e[0m\n"
}

install_package konsole "Konsole" && \
install_package powerline "Powerline" && \
install_package 3270-fonts "IBM 3270 fonts" && \
install_package ansi2html "ansi2html" && \
initialize_konsole
quit $?
