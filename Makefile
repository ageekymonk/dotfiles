.DEFAULT_GOAL := help
SHELL					:=	/bin/bash
GIT						:= $(shell which git)
CONFIG_ROOT   := $(HOME)/projects/sw/repos/personal/dotfiles
REPO_ROOT     := $(HOME)/projects/sw/repos/personal
LN_FLAGS			= -sfn
OS := $(shell uname -s)

.PHONY: help zsh kubernetes


kubernetes: ## Deploy ansible playbook for kubernetes
	echo "Deploying zsh playbook"
	ansible-playbook -i $(CONFIG_ROOT)/ansible/hosts $(CONFIG_ROOT)/ansible/dotfiles.yml --ask-become-pass --tags kubernetes

zsh: ## Deploy ansible playbook for zsh
	echo "Deploying zsh playbook"
	ansible-playbook -i $(CONFIG_ROOT)/ansible/hosts $(CONFIG_ROOT)/ansible/dotfiles.yml --ask-become-pass --tags zsh


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
