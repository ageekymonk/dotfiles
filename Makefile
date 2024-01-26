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
	@make emacs-setup
	@make emacs
	@make python-setup
	@make tmux-setup
	@make zsh

	@echo "Remember to import your gpg keys"
	@echo "Install Intellij Idea"
	@echo "Updated the Alfred license manually"
	@echo "Install docker for mac manually"

azure:: ## Configure azure
	@echo "Installing Azure cli"
	@echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $(shell lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/azure-cli.list
	@curl -L https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
	@sudo apt-get install -y apt-transport-https && sudo apt-get update && sudo apt-get install azure-cli

brew:: ## Configure brew Settings
	@echo "Installing brew"
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	(echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> ~/.zprofile
	@echo "Installing all sw via brew"
	# @brew tap homebrew/bundle
	# @brew bundle --file=brew/Brewfile

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

emacs-setup:: ## Configure emacs for fresh laptop
	@echo "Setting up emacs"
ifeq ($(OS),Linux)
	@sudo apt install -y emacs
endif
ifneq ("$(wildcard $(HOME)/.emacs.d)","")
	@echo "Backing up existing emacs configs"
	@mv $(HOME)/.emacs.d $(HOME)/.emacs.d_bkup
endif
	@echo "Installing spacemacs"
	@git clone -b develop https://github.com/syl20bnr/spacemacs ~/.emacs.d

emacs:: ## Configure emacs Settings
	@ln $(LN_FLAGS) $(CONFIG_ROOT)/emacs/spacemacs ${HOME}/.spacemacs
	@ln $(LN_FLAGS) $(CONFIG_ROOT)/emacs/layers/org-trello ${HOME}/.emacs.d/private/org-trello
	@echo emacs configuration completed

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

hammerspoon:: ## Configure hammerspoon
	@echo "Setting up Hammerspoon"
	@mkdir -p hammerspoon/Spoons
	@wget -O hammerspoon/Spoons/Ki.zip https://github.com/andweeb/ki/releases/download/v1.6.3/Ki.spoon.zip
	@unzip hammerspoon/Spoons/Ki.zip -d hammerspoon/Spoons/
	@wget -O hammerspoon/Spoons/miro.zip https://github.com/miromannino/miro-windows-manager/archive/1.1.zip
	@unzip hammerspoon/Spoons/miro.zip -d hammerspoon/Spoons/
	@mv hammerspoon/Spoons/miro-windows-manager-1.1/MiroWindowsManager.spoon hammerspoon/Spoons/
	@rm -Rf hammerspoon/Spoons/miro-windows-manager-1.1
	@wget -O hammerspoon/undocumented.tar.gz https://github.com/asmagill/hammerspoon_asm.undocumented/releases/download/v0.1/undocumented-v0.1.tar.gz
	@cd hammerspoon && tar -xzvf undocumented.tar.gz && cd ..
	@ln $(LN_FLAGS) $(CONFIG_ROOT)/hammerspoon ${HOME}/.hammerspoon

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

nix:: ## Install nix pkg mgr
	@echo "Installing nix"
	@curl -fsSL -o /tmp/nix.sh https://nixos.org/nix/install
	@bash /tmp/nix.sh --no-daemon
	@rm -Rf /tmp/nix.sh
	@source ${HOME}/.nix-profile/etc/profile.d/nix.sh
ifeq ($(OS),Linux)
	@mkdir -p ${HOME}/.config/nixpkgs
	@ln $(LN_FLAGS) $(CONFIG_ROOT)/nix/home.nix.linux ${HOME}/.config/nixpkgs/home.nix
	@echo "export SHELL=zsh" >> ~/.bashrc
	@echo "export EDITOR=vim" >> ~/.bashrc
	@source ${HOME}/.bashrc
	@nix-channel --add https://github.com/rycee/home-manager/archive/release-20.03.tar.gz home-manager
	@nix-channel --update
	@nix-shell '<home-manager>' -A install
	@home-manager switch
endif
ifeq ($(OS),Darwin)
	@mkdir -p ${HOME}/.config/nixpkgs
	@ln $(LN_FLAGS) $(CONFIG_ROOT)/nix/darwin-configuration.nix ${HOME}/.nixpkgs/darwin-configuration.nix
	@ln $(LN_FLAGS) $(CONFIG_ROOT)/nix/home.nix ${HOME}/.config/nixpkgs/home.nix
	@nix-build https://github.com/LnL7/nix-darwin/archive/master.tar.gz -A installer
	@./result/bin/darwin-installer
	@find /nix/store -name "*-set-environment" -exec echo ". {}" \; >> ${CONFIG_ROOT}/zsh/zshrc
	@echo "export SHELL=zsh" >> ${CONFIG_ROOT}/zsh/zshrc
	@echo "export EDITOR=vim" >> ${CONFIG_ROOT}/zsh/zshrc
	@source ${HOME}/.zshrc
	@nix-channel --add https://github.com/rycee/home-manager/archive/release-20.03.tar.gz home-manager
	@nix-channel --update
	@nix-shell '<home-manager>' -A install
	@source ${HOME}/.zshrc
	@home-manager switch
endif

node-setup:: ## Setting up node in a fresh laptop
	@echo "Configuring node"

osx:: ## Configure osx settings
	@bash scripts/osx-setup.sh
	@echo "osx configuration is completed"

python-setup:: ##Setting up python in a fresh laptop
ifeq ($(OS),Linux)
ifeq ("$(wildcard $(HOME)/.pyenv)","")
	git clone https://github.com/pyenv/pyenv.git ~/.pyenv
endif
endif
	@echo "Configuring python"
	@pyenv install 3.6.3
	@pyenv global 3.6.3
	@pip install awscli Pygments

ruby-setup:: ## Setting up ruby in a fresh laptop
	@echo "Configuring ruby"
	@echo "Installing RVM"
	@curl -sSL -o install_ruby.sh https://get.rvm.io
	@bash install_ruby.sh
	@source $(HOME)/.rvm/scripts/rvm
	@rvm install 2.4
	@rvm use 2.4 --default

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

nvm-setup:: ## nvm setup
	@echo "Setting up nvm"
	@mkdir -p ${HOME}/.nvm
	@npm install -g tern js-beautify eslint

zsh:: ## Configure zsh Settings
	@sh -c "$(curl -fsSL https://raw.githubusercontent.com/zdharma/zinit/master/doc/install.sh)"
	@ln $(LN_FLAGS) $(CONFIG_ROOT)/zsh/zshenv ${HOME}/.zshenv
	@ln $(LN_FLAGS) $(CONFIG_ROOT)/zsh/zshrc ${HOME}/.zshrc
	@ln $(LN_FLAGS) $(CONFIG_ROOT)/zsh/p10k.zsh ${HOME}/.p10k.zsh
	@mkdir -p $(HOME)/.aws/cli
	@ln $(LN_FLAGS) $(CONFIG_ROOT)/aws/alias ${HOME}/.aws/cli/alias
	@git clone https://github.com/ageekymonk/bash-my-aws.git ${REPO_ROOT}/bash-my-aws
	@ln $(LN_FLAGS) ${REPO_ROOT}/bash-my-aws ${HOME}/.bash-my-aws

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

rest:: ## Other misc softwares
	@curl -L -s https://kevinschoon.github.io/pomo/install.sh | bash /dev/stdin
	@mv pomo /usr/local/bin/pomo
	@chmod +x /usr/local/bin/pomo

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
