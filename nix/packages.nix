{
  pkgs,
}:

# The installed inventory. These are direct references, so a package renamed
# or dropped in nixpkgs is a hard eval error (surfaced by `nix flake check`)
# rather than a tool that silently disappears from the environment. Packages
# whose nixpkgs attribute name varies by version are pinned to the preferred
# alias here (e.g. go_1_26, nodejs_22); if that alias is dropped the error
# tells us to bump it, instead of silently falling back to a different one.
[
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
  pkgs.cargo-mutants
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
  # Shadows Apple's curl, whose LibreSSL ignores the bundle's distrust markers
  # (security.pki.caCertificateBlacklist); this one reads NIX_SSL_CERT_FILE.
  pkgs.curl
  pkgs.delta
  pkgs.delve
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
  pkgs.infisical
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
  pkgs.oras
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
  pkgs.sesh
  pkgs.shellcheck
  pkgs.sops
  pkgs.sox
  pkgs.starship
  pkgs.tailscale
  pkgs.tcptraceroute
  pkgs.tesseract
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
  (pkgs.callPackage ./packages/context7-mcp.nix { })
  (pkgs.callPackage ./packages/devc.nix { })
  (pkgs.callPackage ./packages/ollmcp.nix { })
  (pkgs.callPackage ./packages/openpgp-card-tool-git.nix { })
  (pkgs.callPackage ./packages/qpdf.nix { })
  (pkgs.callPackage ./packages/qwen-asr-cli.nix { })
  (pkgs.callPackage ./packages/serena.nix { })

  (pkgs.google-cloud-sdk.withExtraComponents [
    pkgs.google-cloud-sdk.components.gke-gcloud-auth-plugin
  ])

  (pkgs.python313.withPackages (pythonPackages: [
    pythonPackages.pip
  ]))

  # Only the luajit binary; the full package also ships a `lua` clashing with pkgs.lua.
  (pkgs.writeShellScriptBin "luajit" ''exec ${pkgs.luajit}/bin/luajit "$@"'')

  (pkgs.runCommand "gnu-prefixed-tools" { } ''
    mkdir -p "$out/bin"
    for tool in ${pkgs.findutils}/bin/* ${pkgs.gnugrep}/bin/* ${pkgs.gnused}/bin/*; do
      ln -s "$tool" "$out/bin/g$(basename "$tool")"
    done
  '')
]
