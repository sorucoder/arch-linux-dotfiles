#!/usr/bin/env bash

#######################################
# INTERACTIVE TERMINAL CONFIGURATIONS #
#######################################

#
# Dotfiles Bootstrapping
#

source $HOME/.dotfiles/script/bootstrap.sh

#
# Common Configuration
#

source $HOME/.bash

#
# Session Menu
#

if [[ $HOSTNAME != sorucoder-server ]]; then
    while [[ -z $DESKTOP_SESSION ]]; do
        printf "Please select a desktop session:\n"
        printf "\t1. KDE Plasma Desktop\n"
        printf "\t2. Console\n"
        printf "Please enter a number: "
        read -n 1 option
        if [[ -z $option || $option == 1 ]]; then
            exec startx
        elif [[ $option == 2 ]]; then
            export DESKTOP_SESSION=console
            printf "\n"
        else
            printf "\n\e[31mInvalid entry.\e[0m\n"
        fi
    done
fi
