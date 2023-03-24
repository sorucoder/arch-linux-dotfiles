#/usr/bin/env bash

# Powerline integration
if [[ $TERM == xterm-256color ]]; then
	powerline-daemon -q
	POWERLINE_BASH_CONTINUATION=1
	POWERLINE_BASH_SELECT=1
	source /usr/share/powerline/bindings/bash/powerline.sh
fi

# direnv Integration
if which direnv &> /dev/null; then
	eval "$(direnv hook bash)"
fi

# Go integration
export GOPATH=$HOME/.go
export PATH=$PATH:$GOPATH/bin

# CEdev integration
export PATH=$PATH:$HOME/.CEdev/bin

# AngularJS integration
if which ng &> /dev/null; then
	source <(ng completion script)
fi

# .NET Tools integration
if [[ -e ~/.dotnet/tools ]]; then
	export PATH=$PATH:$HOME/.dotnet/tools
fi

# Microsoft SQL integration
if [[ -e /opt/mssql ]]; then
	export PATH=$PATH:/opt/mssql/bin
fi

# Microsoft SQL tools integration
if [[ -e /opt/mssql-tools ]]; then
	export PATH=$PATH:/opt/mssql-tools/bin
fi

# Hererocks integration
export HEREROCKS=$HOME/.hererocks

# Node Version Manager integration
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# Wine integration
export WINEDLLOVERRIDES=winemenubuilder.exe=d
