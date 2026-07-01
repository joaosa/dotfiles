{
  pkgs,
}:

let
  # The installed inventory. These are direct references, so a package renamed
  # or dropped in nixpkgs is a hard eval error (surfaced by `nix flake check`)
  # rather than a tool that silently disappears from the environment. Packages
  # whose nixpkgs attribute name varies by version are pinned to the preferred
  # alias here (e.g. go_1_26, nodejs_22); if that alias is dropped the error
  # tells us to bump it, instead of silently falling back to a different one.
  packages = [
    pkgs.age
    pkgs.ansible
    pkgs.asciinema
    pkgs.asciinema-agg
    pkgs.azure-cli
    pkgs.bacon
    pkgs.bash
    pkgs.bat
    pkgs.bottom
    pkgs.cargo-audit
    pkgs.cargo-bloat
    pkgs.cargo-cyclonedx
    pkgs.cargo-deny
    pkgs.cargo-expand
    pkgs.cargo-geiger
    pkgs.cargo-insta
    pkgs.cargo-llvm-cov
    pkgs.cargo-machete
    pkgs.cargo-nextest
    pkgs.cargo-outdated
    pkgs.cargo-vet
    pkgs.chafa
    # claude-code and codex are installed via npm for faster upstream cadence;
    # add them here (pkgs.claude-code, pkgs.codex) to install them via Nix instead.
    pkgs.colima
    pkgs.coreutils
    # g-prefixed coreutils (gls, gdate, ...) for scripts that expect the
    # Homebrew-style names; the unprefixed GNU tools above already come first
    # on PATH. The remaining GNU tools without a prefixed nixpkgs variant get
    # wrappers below.
    pkgs.coreutils-prefixed
    pkgs.crane
    pkgs.delve
    pkgs.delta
    # devcontainer CLI, driven by the pinned `devc` wrapper below.
    pkgs.devcontainer
    pkgs.direnv
    pkgs.dive
    pkgs.docker
    pkgs.docker-buildx
    pkgs.dust
    pkgs.fd
    pkgs.findutils
    pkgs.fluxcd
    pkgs.fortune
    pkgs.fswatch
    pkgs.fzf
    pkgs.gawk
    pkgs.gettext
    pkgs.ghq
    pkgs.git
    pkgs.git-crypt
    pkgs.git-extras
    pkgs.git-filter-repo
    pkgs.git-secret
    pkgs.gitmux
    pkgs.gitleaks
    pkgs.gnugrep
    pkgs.gnupg
    pkgs.gnused
    pkgs.go_1_26
    pkgs.gore
    pkgs.htop
    pkgs.hyperfine
    pkgs.iftop
    pkgs.imagemagick
    pkgs.inetutils
    pkgs.jless
    pkgs.jq
    pkgs.just
    pkgs.k3d
    pkgs.k9s
    pkgs.kubectl
    pkgs.kubectx
    pkgs.kubernetes-helm
    pkgs.kubeseal
    pkgs.leptonica
    pkgs.libheif
    pkgs.lua
    pkgs.luarocks
    pkgs.mcp-server-filesystem
    pkgs.miller
    pkgs.mitmproxy
    pkgs.mkcert
    pkgs.mtr
    pkgs.neovim
    # Nix LSP and formatter, used by the neovim config (mason only manages
    # tools it can download itself; these come from nixpkgs).
    pkgs.nil
    pkgs.nixfmt
    pkgs.nmap
    pkgs.nodejs_22
    pkgs.opencode
    pkgs.openpgp-card-tools
    pkgs.parallel
    pkgs.pkg-config
    pkgs.pngquant
    pkgs.poppler-utils
    pkgs.prek
    pkgs.procs
    pkgs.pv
    pkgs.pwgen
    pkgs.qrencode
    pkgs.ripgrep
    pkgs.rustup
    pkgs.scc
    pkgs.sccache
    pkgs.shellcheck
    pkgs.sesh
    pkgs.sops
    pkgs.sox
    pkgs.starship
    pkgs.tailscale
    pkgs.tesseract
    pkgs.tcptraceroute
    pkgs.terminal-notifier
    pkgs.tmux
    pkgs.tree
    pkgs.tree-sitter
    pkgs.units
    pkgs.uv
    pkgs.vegeta
    pkgs.watch
    pkgs.wasm-pack
    pkgs.websocat
    pkgs.wireguard-go
    pkgs.wireguard-tools
    pkgs.yq-go
    pkgs.yubikey-manager
    pkgs.zoxide
    pkgs.zsh

    # Headers needed by tools that build against libheif.
    pkgs.libheif.dev

    # Local derivations for tools missing from nixpkgs at the version we want.
    (pkgs.callPackage ./packages/devc.nix { })
    (pkgs.callPackage ./packages/ollmcp.nix { })
    (pkgs.callPackage ./packages/openpgp-card-tool-git.nix { })
    (pkgs.callPackage ./packages/qwen-asr-cli.nix { })
    (pkgs.callPackage ./packages/serena.nix { })

    (pkgs.google-cloud-sdk.withExtraComponents [
      pkgs.google-cloud-sdk.components.gke-gcloud-auth-plugin
    ])

    (pkgs.python313.withPackages (pythonPackages: [
      pythonPackages.pip
    ]))

    (pkgs.runCommand "luajit-bin" { } ''
              mkdir -p "$out/bin"
              cat > "$out/bin/luajit" <<EOF
      #!${pkgs.runtimeShell}
      exec "${pkgs.luajit}/bin/luajit" "\$@"
      EOF
              chmod +x "$out/bin/luajit"
    '')

    (pkgs.runCommand "gnu-prefixed-tools" { } ''
              mkdir -p "$out/bin"

              for dir in \
                ${pkgs.findutils}/bin \
                ${pkgs.gnugrep}/bin \
                ${pkgs.gnused}/bin
              do
                for tool in "$dir"/*; do
                  name="$(basename "$tool")"
                  cat > "$out/bin/g$name" <<EOF
      #!${pkgs.runtimeShell}
      exec "$tool" "\$@"
      EOF
                  chmod +x "$out/bin/g$name"
                done
              done
    '')
  ];
in
packages
