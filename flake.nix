{
  description = "Joao's dotfiles";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    # Pinned tap contents for nix-homebrew's declarative taps.
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nix-darwin,
      home-manager,
      nix-homebrew,
      ...
    }:
    let
      # One entry per machine. Adding a host is adding an attrset here.
      hosts = {
        Mac = {
          username = "joao-sousa-andrade";
          system = "aarch64-darwin";
        };
      };

      # Build a nix-darwin system from a host entry.
      mkDarwinHost =
        hostname:
        { username, system }:
        nix-darwin.lib.darwinSystem {
          specialArgs = {
            inherit
              inputs
              username
              hostname
              system
              ;
          };
          modules = [
            ./nix/hosts/${hostname}.nix
            ./nix/darwin
            nix-homebrew.darwinModules.nix-homebrew
            home-manager.darwinModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                backupFileExtension = "hm-backup";
                extraSpecialArgs = {
                  inherit
                    inputs
                    username
                    hostname
                    system
                    ;
                };
                users.${username} = import ./nix/home;
              };
            }
          ];
        };

      # Systems we produce per-system outputs (checks, devShells, packages,
      # formatter) for. Derived from the hosts above so a new platform is free.
      systems = nixpkgs.lib.unique (map (h: h.system) (builtins.attrValues hosts));
      forAllSystems =
        f:
        nixpkgs.lib.genAttrs systems (
          system:
          f {
            inherit system;
            pkgs = import nixpkgs {
              inherit system;
              config.allowUnfree = true;
            };
          }
        );
    in
    {
      darwinConfigurations = nixpkgs.lib.mapAttrs mkDarwinHost hosts;

      checks = forAllSystems (
        { system, ... }:
        # `nix flake check` evaluates and builds every host system for this
        # platform, catching eval breakage and missing/renamed packages before
        # activation. Derived from `hosts`, so a new host is checked for free.
        nixpkgs.lib.mapAttrs' (
          hostname: _:
          nixpkgs.lib.nameValuePair "darwin-build-${hostname}" self.darwinConfigurations.${hostname}.system
        ) (nixpkgs.lib.filterAttrs (_: host: host.system == system) hosts)
      );

      devShells = forAllSystems (
        { pkgs, ... }:
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.nixfmt
              pkgs.statix
              pkgs.deadnix
              pkgs.prek
            ];
          };
        }
      );

      packages = forAllSystems (
        { pkgs, system }:
        {
          darwin-rebuild = nix-darwin.packages.${system}.darwin-rebuild;
          home-manager = home-manager.packages.${system}.home-manager;
          ripgrep = pkgs.ripgrep;
        }
      );

      formatter = forAllSystems ({ pkgs, ... }: pkgs.nixfmt-tree);
    };
}
