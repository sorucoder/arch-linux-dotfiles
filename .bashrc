#!/usr/bin/env bash

#######################################
# INTERACTIVE TERMINAL CONFIGURATIONS #
#######################################

#
# Dotfiles Bootstrapping
#

function bootstrap_dotfiles() {
	local dotfile target link link_dirname

	cd $HOME/.dotfiles
	if [[ $(nmcli --colors no networking connectivity) == 'full' ]]; then
		git pull --quiet origin master
	else
		printf "\e[93m\e[1mwarning: not connected to the internet; not updating dotfiles\e[0m"
		cd "$OLDPWD"
		return 1
	fi

	for dotfile in $(find . -type f -not -path "/.git/*" -not -path "./install/*" -printf "%P\n"); do
		target="$HOME/.dotfiles/$dotfile"
		link="$HOME/$dotfile"
		if [[ ! -h $link ]]; then
			link_dirname=$(dirname $link)
			if [[ ! -d $link_dirname ]]; then
				if [[ -e $link ]]; then
					rm $link_dirname
				fi
				mkdir -p $link_dirname
			fi

			if [[ -e $link ]]; then
				rm $link
			fi
			ln -s $target $link
		fi
	done

	cd "$OLDPWD"

	return 0
}

bootstrap_dotfiles

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
