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
# Plasma
#

if [[ -z $DESKTOP_SESSION ]]; then
	export DESKTOP_SESSION=plasma
	dbus-run-session startplasma-wayland
	logout
fi
