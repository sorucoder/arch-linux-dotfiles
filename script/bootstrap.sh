#!/usr/bin/env bash

function bootstrap_dotfiles() {
	cd $HOME/.dotfiles

	if [[ $(nmcli --colors no networking connectivity) == 'full' ]]; then
		git pull --quiet origin master
	else
		printf "\e[93m\e[1mwarning: not connected to the internet; not updating dotfiles\e[0m\n"
		cd "$OLDPWD"
		return 1
	fi

    local dotfile target target_directory link link_directory
	for dotfile in $(find $HOME/.dotfiles -type f -exec realpath --relative-base $HOME/.dotfiles {} \;); do
        target="$HOME/.dotfiles/$dotfile"
        target_directory=$(dirname $target)
        if [[ ! (\
            $target_directory =~ ^$HOME/.dotfiles/.git || \
            $target_directory =~ ^$HOME/.dotfiles/install || \
            $target_directory =~ ^$HOME/.dotfiles/script || \
            $target == $HOME/.dotfiles/.gitignore \
        ) ]]; then
            link="$HOME/$dotfile"
            if [[ ! -h $link ]]; then
                link_directory=$(dirname $link)
                if [[ ! -d $link_directory ]]; then
                    if [[ -e $link ]]; then
                        rm $link_directory
                    fi
                    mkdir -p $link_directory
                fi

                if [[ -e $link ]]; then
                    rm $link
                fi
                ln -s $target $link
            fi
        fi
	done

	cd "$OLDPWD"

	return 0
}

bootstrap_dotfiles
