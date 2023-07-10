#!/usr/bin/env bash

#################################
# LOGIN TERMINAL CONFIGURATIONS #
#################################

#
# Dotfiles Bootstrapping
#

function bootstrap_dotfiles() {
	local exclude_paths dotfile target link link_directory_path

	cd $HOME/.dotfiles

	if [[ $(nmcli --colors no networking connectivity) == 'full' ]]; then
		git pull --quiet origin master
	else
		printf "\e[93m\e[1mwarning: not connected to the internet; not updating dotfiles\e[0m"
		cd "$OLDPWD"
		return 1
	fi

    exclude_paths=$(printf $HOME/.dotfiles/{.git,install,script})

	for dotfile in $(find $HOME/.dotfiles -type f -exec realpath --relative-base $HOME/.dotfiles {} \; $(printf -- " -o -path %s -prune" $exclude_paths)); do
        target="$HOME/.dotfiles/$dotfile"
		link="$HOME/$dotfile"
		if [[ ! -h $link ]]; then
			link_directory_path=$(dirname $link)
			if [[ ! -d $link_directory_path ]]; then
				if [[ -e $link ]]; then
					rm $link_directory_path
				fi
				mkdir -p $link_directory_path
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
