# Dotfiles tasks - run `make` or `make help` to see all recipes
NIX := /nix/var/nix/profiles/default/bin/nix

.DEFAULT_GOAL := help

## help: List available recipes
.PHONY: help
help:
	@grep -E '^## ' $(MAKEFILE_LIST) | sed -e 's/## //' | awk -F': ' '{printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

## nix-switch: Apply the nix-darwin + Home Manager flake
.PHONY: nix-switch
nix-switch:
	sudo -H $(NIX) --extra-experimental-features "nix-command flakes" run .#darwin-rebuild -- switch --flake .#Mac

## nix-build: Build the system without activating it
.PHONY: nix-build
nix-build:
	$(NIX) build .#darwinConfigurations.Mac.system --no-link

## check: Run flake checks and formatting check
.PHONY: check
check:
	$(NIX) flake check
	$(NIX) fmt -- --fail-on-change
