.DEFAULT_GOAL := help
SHELL					:=	/bin/bash
GIT						:= $(shell which git)
CONFIG_ROOT   := $(HOME)/projects/sw/repos/personal/dotfiles
REPO_ROOT     := $(HOME)/projects/sw/repos/personal
LN_FLAGS			= -sfn
OS := $(shell uname -s)

.PHONY: help brew emacs git ssh zsh zsh-setup

setup-common:: ## Setup common configs
	@echo "Setting up directory structure"
	@mkdir -p ~/projects/sw/repos/opensource
	@mkdir -p ~/projects/sw/repos/personal
	@mkdir -p ~/projects/sw/sandbox
	@mkdir -p ~/projects/sw/gospace

ifeq ("$(wildcard $(HOME)/projects/sw/repos/personal/dotfiles)","")
	@echo "Downloading the config repository"
	@git clone https://github.com/ageekymonk/dotfiles.git $(HOME)/projects/sw/repos/personal/dotfiles
	@echo "Jump to $(HOME)/projects/sw/repos/personal/dotfile and run make all"
endif

setup-mac:: ## Setup mac
	@cd $(CONFIG_ROOT)
ifeq ($(OS),Darwin)
	@make brew
	@make osx
endif

setup-linux:: ## Setup Linux
	@cd $(CONFIG_ROOT)
	@ln $(LN_FLAGS) $(CONFIG_ROOT)/xmodmap/defaults ${HOME}/.xmodmap
	@ln $(LN_FLAGS) $(CONFIG_ROOT)/xmodmap/xinitrc ${HOME}/.xinitrc
	@make zsh

setup:: setup-common setup-mac ## Configure the laptop for fresh installation
	@echo "Pulling in other submodules"
	@git submodule init
	@git submodule update

	@make git
	@make ssh-setup
	@make zsh

	@echo "Remember to import your gpg keys"
	@echo "Updated the Alfred license manually"

azure:: ## Configure azure
	@echo "Installing Azure cli"
	@echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $(shell lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/azure-cli.list
	@curl -L https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
	@sudo apt-get install -y apt-transport-https && sudo apt-get update && sudo apt-get install azure-cli

brew:: ## Configure brew Settings
	@echo "Installing brew"
	curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh
	echo 'PATH=$$PATH:/opt/homebrew/bin/' >> ~/.bashrc
	source ~/.bashrc
	@echo "Installing all sw via brew"
	@brew bundle --file=brew/Brewfile
	mas install 1475387142

linux:: ## Configure Linux Settings
	@sudo apt install -y build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev python-pip tmux unzip
	@sudo snap install --classic go
	@wget https://github.com/ogham/exa/releases/download/v0.8.0/exa-linux-x86_64-0.8.0.zip
	@unzip exa-linux-x86_64-0.8.0.zip
	@sudo mv exa-linux-x86_64 /usr/local/bin/exa
	@rm -Rf exa-linux-x86_64-0.8.0.zip
	@wget https://github.com/clvv/fasd/archive/1.0.1.zip
	@unzip 1.0.1.zip
	@rm -Rf 1.0.1.zip
	@sudo mv fasd-1.0.1/fasd /usr/local/bin/fasd

gcloud:: ## Install gcloud
	@echo "Installing google cloud sdk"
	@curl https://sdk.cloud.google.com | bash

git:: ## Configure git Settings

ifeq ($(OS),Linux)
		sudo apt install git
endif
	@echo "Setting up git"
	@ln $(LN_FLAGS) $(CONFIG_ROOT)/git/gitignore ${HOME}/.gitignore
ifeq ($(OS),Linux)
	@ln $(LN_FLAGS) $(CONFIG_ROOT)/git/gitconfig.linux ${HOME}/.gitconfig
endif
ifeq ($(OS),Darwin)
	@ln $(LN_FLAGS) $(CONFIG_ROOT)/git/gitconfig ${HOME}/.gitconfig
endif

	@mkdir -p ~/.git-template
	@git config user.name "ageekymonk"
	@git config user.email "ramzthecoder@gmail.com"
	@echo git configuration completed

go:: ## Configure Golang Setttings
ifeq ($(OS),Linux)
	@sudo apt install -y golang
endif
	@go get -u github.com/alecthomas/gometalinter
	@go get golang.org/x/tools/gopls

iterm:: ## Configure iterm
	@echo "setting up iterm"
	@cp iterm2/com.googlecode.iterm2.plist $(HOME)/Library/Preferences/com.googlecode.iterm2.plist
	@git clone https://github.com/dracula/iterm.git iterm2/themes/dracula

karabiner:: ## Install karabiner configs
	@echo "You might need to install karabiner manually. Since brew for karabiner is broken"
	@echo "Setting up karabiner"
	@mkdir -p "${HOME}/Library/Application Support/Karabiner"
	@ln $(LN_FLAGS) $(CONFIG_ROOT)/karabiner/private.xml "${HOME}/Library/Application Support/Karabiner/private.xml"
	@echo "karabiner configuration completed. Add https://github.com/Vonng/Capslock"


osx:: ## Configure osx settings
	@bash scripts/osx-setup.sh
	@echo "osx configuration is completed"

ssh-setup:: ## Setting up ssh for the first time
	@echo "Setting up ssh"
	@mkdir -p $(HOME)/.ssh
	@chmod 700 ${HOME}/.ssh
	@touch ${HOME}/.ssh/authorized_keys
	@chmod 600 ${HOME}/.ssh/authorized_keys
	@ln $(LN_FLAGS) $(CONFIG_ROOT)/ssh/default/config ${HOME}/.ssh/config
ifeq ($(OS),Linux)
	@ln $(LN_FLAGS) $(CONFIG_ROOT)/ssh/default/config.linux ${HOME}/.ssh/config
endif
ifeq ($(OS),Darwin)
	@ln $(LN_FLAGS) $(CONFIG_ROOT)/ssh/default/config ${HOME}/.ssh/config
endif
	@echo "ssh configuration completed"

tmux-setup:: ## Setting up tmux for th first time
	@echo "Setting up tmux"
	@echo "Setting up powerline"
	@pip install powerline-status
	@ln $(LN_FLAGS) $(CONFIG_ROOT)/tmux/tmux.conf ${HOME}/.tmux.conf
	@ln $(LN_FLAGS) $(CONFIG_ROOT)/tmux/tmux.conf.local ${HOME}/.tmux.conf.local
	@mkdir -p ${HOME}/.tmux/plugins
	@git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
	@echo "tmux configuration completed"

zsh:: ## Configure zsh Settings
	@sh -c "$(curl -fsSL https://raw.githubusercontent.com/zdharma/zinit/master/doc/install.sh)"
	@ln $(LN_FLAGS) $(CONFIG_ROOT)/zsh/zshenv ${HOME}/.zshenv
	@ln $(LN_FLAGS) $(CONFIG_ROOT)/zsh/zshrc ${HOME}/.zshrc
	@ln $(LN_FLAGS) $(CONFIG_ROOT)/zsh/p10k.zsh ${HOME}/.p10k.zsh
	@mkdir -p $(HOME)/.aws/cli
	@ln $(LN_FLAGS) $(CONFIG_ROOT)/aws/alias ${HOME}/.aws/cli/alias

ifeq ($(OS),Linux)
	@sudo apt install -y zsh
endif
ifeq ("$(wildcard $(CONFIG_ROOT)/zsh/themes/powerlevel10k)","")
	@echo "Installing powerlevel10k theme"
	@git clone https://github.com/romkatv/powerlevel10k.git $(CONFIG_ROOT)/zsh/themes/powerlevel10k
endif
ifeq ($(OS),Darwin)
	@echo "Setting up iterm2 Shell Integrations"
	@curl -L -o $(HOME)/.iterm2_shell_integration.zsh https://iterm2.com/shell_integration/zsh
	@echo "Changing the default shell to zsh"
	@sudo dscl . -create /Users/$(USER) UserShell /usr/local/bin/zsh
endif
	@echo "Installing oh my zsh"
	@curl -fsSL -o /tmp/install_zsh.sh https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh
	@sh /tmp/install_zsh.sh
	@rm /tmp/install_zsh.sh

# Help text
define HELP_TEXT
Usage: make [TARGET]... [MAKEVAR1=SOMETHING]...

Mandatory variables:

Optional variables:

Available targets:
endef
export HELP_TEXT

# A help target including self-documenting targets (see the awk statement)
help: ## This help target
	$(banner)
	@echo "$$HELP_TEXT"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / \
		{printf "\033[36m%-30s\033[0m  %s\n", $$1, $$2}' $(MAKEFILE_LIST)
