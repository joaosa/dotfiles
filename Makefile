# Dotfiles tasks - run `make` or `make help` to see all recipes
NIX := /nix/var/nix/profiles/default/bin/nix
# Host entry from flake.nix to build/switch; override with `make switch HOST=...`
HOST ?= Mac
# GitHub organization mounted by the fleet devcontainer targets.
ORG ?=
export ORG

.DEFAULT_GOAL := help

## help: List available recipes
.PHONY: help
help:
	@grep -E '^## ' $(MAKEFILE_LIST) | sed -e 's/## //' | awk -F': ' '{printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

## switch: Apply the nix-darwin + Home Manager flake
.PHONY: switch
switch:
	sudo -H $(NIX) --extra-experimental-features "nix-command flakes" run .#darwin-rebuild -- switch --flake .#$(HOST)

## build: Build the system without activating it
.PHONY: build
build:
	$(NIX) build .#darwinConfigurations.$(HOST).system --no-link

## check: Run flake checks and formatting check
.PHONY: check
check:
	$(NIX) flake check
	$(NIX) fmt -- --fail-on-change

## hooks: Install the prek git hooks (run once per clone)
.PHONY: hooks
hooks:
	$(NIX) develop -c prek install
	$(NIX) develop -c prek install --hook-type pre-push

## devc-rebuild: Apply config, rebuild the fleet devcontainer, and enter it (ORG=<org>)
.PHONY: devc-rebuild
devc-rebuild:
	@test -n "$$ORG" || { echo "usage: make devc-rebuild ORG=<github-org>" >&2; exit 2; }
	$(MAKE) switch
	zsh -lic 'agent-fleet-rebuild "$$ORG"'
