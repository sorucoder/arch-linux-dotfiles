#!/usr/bin/env bash

#
# Shell Options
#

shopt -s extglob

#
# Editor
#

export EDITOR="nano --rcfile $HOME/.nano/user.nanorc"
export VISUAL=$EDITOR
export SUDO_EDITOR="sudo nano --restricted --rcfile $HOME/.nano/root.nanorc"

#
# Shell Functions
#

function print_warning() {
	printf "\e[93m\e[1mwarning: $@\e[0m\n"
}

function print_advisory() {
    printf "\e[3m$@\e[0m\n"
}

#
# Prompt
#

export PS1="\u@\h:\W\$ "

#
# Shell Integrations
#

source $HOME/.shell_integrations

#
# Aliases
#

source $HOME/.aliases
