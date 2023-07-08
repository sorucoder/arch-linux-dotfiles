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
export SUDO_EDITOR="nano --restricted --rcfile $HOME/.nano/root.nanorc"

#
# Shell Functions
#

function print_warning() {
	printf "\e[93m\e[1mwarning: $@\e[0m\n"
}

function print_advisory() {
    printf "\e[3m$@\e[0m\n"
}

function sudo_alias() {
	if (( $# == 0 )); then
		printf "Usage: sudo_alias [-b|--both] PROGRAM=COMMAND\n\n"

		printf "Generates alias(es) which require(s) sudo.\n\n"

		printf "When --both is given, this function will generate one alias with PROGRAM in tact and COMMAND in tact,\n"
		printf "and another alias with PROGRAM prepended with \"su\" and COMMAND prepended with \"sudo \". For example:\n\n"

		printf "\tsudo_alias -b cp=\"cp -r\"\n\n"

		printf "will generate:\n\n"

		printf "\talias cp=\"cp -r\"\n\n"

		printf "and\n\n"

		printf "\talias sucp=\"sudo cp -r\"\n\n"

		printf "Otherwise, this function will generate the alias with PROGRAM in tact and COMMAND prepended with \"sudo \".\n"

		if [[ $- == *i* ]]; then
			return 1
		else
			exit 1
		fi
	fi

	local both command program

	both=false
	if [[ $1 == "-b" || $1 == "--both" ]]; then
		both=true
		shift
	fi

	command=$1
	if [[ $command =~ "=" ]]; then
		program=$(cut -d "=" -f 1 <<< $command)
		command=$(cut -d "=" -f 2- <<< $command)
	else
		program=$command
	fi

	if $both; then
		alias $program="$command"
		alias su$program="sudo $command"
	else
		alias $program="sudo $command"
	fi

	if [[ $- == *i* ]]; then
		return 0
	else
		exit 0
	fi
}

function configuration_alias() {
    if (( $# < 2 )); then
        printf "Usage: configuration_alias PROGRAM FILE [RELOAD_COMMAND [RELOAD_MESSAGE]]\n\n"

		printf "Creates an alias that invokes the configured editor for the purposes of configuration, and (optionally)\n"
		printf "reload the program/service to which the configuration controls.\n\n"

		printf "The name of the generated alias will be \"configure-PROGRAM\". If FILE already exists, the generated alias\n"
		printf "will determine if \"\$SUDO_EDITOR FILE\" is required. Otherwise, it will assume that \"\$EDITOR FILE\" is\n"
		printf "sufficient.\n\n"

		printf "By default, this function will generate an alias that will simply edit the configuration file. For example:\n\n"

		printf "\tconfiguration_alias hosts /etc/hosts\n\n"

		printf "will generate:\n\n"

		printf "\talias configure-hosts=\"sudo \$EDITOR /etc/hosts\"\n\n"

		printf "If RELOAD_COMMAND is given, a generic message will be echoed and RELOAD_COMMAND will be executed. For example:\n\n"

		printf "\tconfiguration_alias bash $HOME/.bashrc \"source $HOME/.bashrc\"\n\n"

		printf "will generate:\n\n"

		printf "\talias configure-bash=\"edit ~./bashrc; printf \"Reloading bash...\\n\"; source $HOME/.bashrc\"\n\n"

		printf "If RELOAD_MESSAGE is given, RELOAD_MESSAGE with a newline will be printed instead.\n"

		if [[ $- == *i* ]]; then
			return 1
		else
			exit 1
		fi
    fi

    local program file reload_command reload_message editor

    program=$1; shift
    file=$1; shift
    reload_command=$1; shift
    reload_message=$1

    editor=$EDITOR
    if touch -c $file 2>&1 | grep -q "Permission denied"; then
    	editor=$SUDO_EDITOR
    elif [[ ! -e $file ]]; then
    	print_warning "\"$file\" does not exist; configuration_alias will assume unpriviledged editing"
	fi

	if [[ -z $reload_command ]]; then
		alias configure-$program="$editor $file"
	elif [[ -z $reload_message ]]; then
		alias configure-$program="$editor $file; printf \"Reloading $program...\n\"; $reload_command"
	else
		alias configure-$program="$editor $file; printf \"$reload_message\n\"; $reload_command"
	fi

	if [[ $- == *i* ]]; then
		return 0
	else
		exit 0
	fi
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
