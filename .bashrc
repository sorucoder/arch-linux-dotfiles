#!/usr/bin/env bash

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

#
# Dotfiles Bootstrapping
#
cd ~/.dotfiles

if [[ $(nmcli --colors no networking connectivity) == 'full' ]]; then
	git pull --quiet origin master
else
	echo 'warning: not connected to the internet; not updating dotfiles'
fi

for dotfile in $(find . -type f -not -path './.git/*' -not -path './install/*' -printf '%P\n'); do
	if [[ ! -e ~/$dotfile ]]; then
		dotroot=$(dirname ~/$dotfile)
		if [[ ! -e ~/$dotroot ]]; then
			mkdir -p ~/$dotroot
		fi

		ln -s ~/.dotfiles/$dotfile ~/$dotfile
	fi
done

cd "$OLDPWD"

#
# Shell Options
#

shopt -s extglob

#
# Editor
#

export EDITOR=nano
export VISUAL=$EDITOR

#
# Shell Functions
#

function sudo_alias() {
	if (( $# == 0 )); then
		echo -e "Usage: sudo_alias [-b|--both] PROGRAM=COMMAND"
		echo
		echo -e "Generates alias(es) which require(s) sudo."
		echo
		echo -e "When --both is given, this function will generate one alias with PROGRAM in tact and COMMAND in tact,"
		echo -e "and another alias with PROGRAM prepended with 'su' and COMMAND prepended with 'sudo '. For example:"
		echo
		echo -e "\tsudo_alias -b cp='cp -r'"
		echo
		echo -e "will generate"
		echo
		echo -e "\talias cp='cp -r'"
		echo
		echo -e "and"
		echo
		echo -e "\talias sucp='sudo cp -r'"
		echo
		echo -e "Otherwise, this function will generate the alias with PROGRAM in tact and COMMAND prepended with 'sudo '."

		# Either return if interactive or exit in shell
		if [[ $- == *i* ]]; then
			return 1
		else
			exit 1
		fi
	fi


	if [[ "$1" == '-b' || "$1" == '--both' ]]; then
		shift
		if [[ ! "$1" =~ '=' ]]; then
			command="$1"
			alias $command="$command"
			alias su$command="sudo $command"
		else
			program=$(cut -d '=' -f 1 <<< $1)
			command=$(cut -d '=' -f 2 <<< $1)
			alias $program="$command"
			alias su$program="sudo $command"
		fi
	else
		if [[ ! "$1" =~ '=' ]]; then
			command="$1"
			alias $command="sudo $command"
		else
			program=$(cut -d '=' -f 1 <<< $1)
			command=$(cut -d '=' -f 2 <<< $1)
			alias $program="sudo $command"
		fi
	fi
}

function configuration_alias() {
	if (( $# == 2 )); then
		program="$1"; shift
		file="$1"

		# If file exists, check to see if sudo would be required.
		# Otherwise, warn the user and assume sudo is not needed.
		if [[ ! -e $file ]]; then
			echo "warning: '$file' not does not exist; configuration_alias will assume non-root editing"
			editor=$EDITOR
		elif ! touch -c $file 2>&1 | grep -q 'Permission denied'; then
			editor=$EDITOR
		else
			editor="sudo $EDITOR"
		fi

		alias configure-$program="$editor $file"
	elif (( $# == 3 )); then
		program=$1; shift
		file=$1; shift
		reload=$1

		# If file exists, check to see if sudo would be required.
		# Otherwise, warn the user and assume sudo is not needed.
		if [[ ! -e $file ]]; then
			echo "warning: '$file' not does not exist; configuration_alias will assume non-root editing"
			editor=$EDITOR
		elif ! touch -c $file 2>&1 | grep -q 'Permission denied'; then
			editor=$EDITOR
		else
			editor="sudo $EDITOR"
		fi

		alias configure-$program="$editor $file; echo 'Reloading ${program}...'; $reload"
	elif (( $# == 4 )); then
		program=$1; shift
		file=$1; shift
		reload=$1; shift
		message=$1

		# If file exists, check to see if sudo would be required.
		# Otherwise, warn the user and assume sudo is not needed.
		if [[ ! -e $file ]]; then
			echo "warning: '$file' not does not exist; configuration_alias will assume non-root editing"
			editor=$EDITOR
		elif ! touch -c $file 2>&1 | grep -q 'Permission denied'; then
			editor=$EDITOR
		else
			editor="sudo $EDITOR"
		fi

		alias configure-$program="$editor $file; echo -e $message; $reload"
	else
		echo -e "Usage: configuration_alias PROGRAM FILE [RELOAD [MESSAGE]]"
		echo
		echo -e "Creates an alias that invokes the configured editor for the purpose of configuration, and (optionally)"
		echo -e "reload the program to which the configuration adheres to."
		echo
		echo -e "The name of the generated alias will be 'configure-PROGRAM'. If FILE already exists, the generated alias"
		echo -e "will determine if 'sudo \$EDITOR FILE' is required. Otherwise, it will assume that '\$EDITOR FILE' is"
		echo -e "sufficient."
		echo
		echo -e "By default, this function will generate an alias that will simply edit the configuration file. For example:"
		echo
		echo -e "\tconfiguration_alias hosts /etc/hosts"
		echo
		echo -e "will generate:"
		echo
		echo -e "\talias configure-hosts=\"sudo \$EDITOR /etc/hosts\""
		echo
		echo -e "If RELOAD is given, a message will be echoed and RELOAD will be executed. For example:"
		echo
		echo -e "\tconfiguration_alias bash ~/.bashrc 'source ~/.bashrc'"
		echo
		echo -e "will generate:"
		echo
		echo -e "\talias configure-bash=\"edit ~./bashrc; echo -e 'Reloading Bash configuration...'; source ~/.bashrc\""
		echo
		echo -e "If MESSAGE is given, MESSAGE will be echoed instead."

		if [[ $- == *i* ]]; then
			return 1
		else
			exit 1
		fi
	fi
}

#
# Prompt
#

PS1='\u@\h:\W\$ '

#
# Profile
#

source ~/.profile

#
# Aliases
#

source ~/.aliases
