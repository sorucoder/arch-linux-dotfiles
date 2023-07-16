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
# Desktop Session
#

if [[ -z $DESKTOP_SESSION ]]; then
	printf "Please select what you would like to launch:\n"
	printf "\t1. Arch Linux (default)\n"
	printf "\t2. Arch Linux with KDE Plasma\n"
	printf "\n"
	printf "Enter a number: "
	read -n 1 option
	printf "\n"
	case $option in
		1)
            unset option
            export DESKTOP_SESSION=none
            ;;
		2)
            unset option
            export DESKTOP_SESSION=plasma
            dbus-run-session startplasma-wayland
            logout
            ;;
	esac
fi
