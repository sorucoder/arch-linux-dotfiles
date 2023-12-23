#!/usr/bin/env bash

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

install_package nano "Nano Editor"
if (( $? != 0 )); then
    quit 1
fi

if [[ $DESKTOP_SESSION == plasma ]]; then
    install_package code "Visual Studio Code - Open Source Software" && \
    install_package code-features "Visual Studio Code Features" && \
    install_package ttf-firacode "FiraCode Font" && \
    install_package okteta "Okteta Hex Editor"
    quit $?
fi