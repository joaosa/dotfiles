{
  # Conservative defaults for phasing in nix-darwin/Home Manager.
  # Add one item at a time, rebuild, then activate when the diff is understood.

  # Home Manager packages from nix/packages.nix by package key.
  # Examples: [ "ripgrep" "fd" "tmux" "nodejs" ]
  homePackageKeys = [
    "ripgrep"
    "fd"
    "bat"
    "dust"
    "agg"
    "age"
    "asciinema"
    "bash"
    "bottom"
    "cargo-bloat"
    "cargo-geiger"
    "cargo-llvm-cov"
    "cargo-nextest"
    "cargo-watch"
    "delve"
    "delta"
    "direnv"
    "dive"
    "fluxcd"
    "fswatch"
    "fzf"
    "gawk"
    "gh"
    "ghq"
    "git-crypt"
    "git-extras"
    "git-secret"
    "gitleaks"
    "htop"
    "hyperfine"
    "jless"
    "jq"
    "just"
    "helm"
    "k3d"
    "k9s"
    "kubectx"
    "kubeseal"
    "miller"
    "mkcert"
    "nmap"
    "parallel"
    "pkg-config"
    "pngquant"
    "procs"
    "pv"
    "pwgen"
    "qrencode"
    "rustup"
    "sccache"
    "shellcheck"
    "sops"
    "sox"
    "starship"
    "stow"
    "units"
    "uv"
    "vegeta"
    "websocat"
    "wireguard-go"
    "wireguard-tools"
    "yq-go"
    "zoxide"
  ];

  # Home Manager-managed dotfiles by target path.
  # Examples: [ ".gitconfig" ".tmux.conf" ".config/nvim" ]
  homeFileTargets = [ ];

  # Replaces shell startup behavior with the Home Manager zsh/prezto config.
  homeShell = false;

  # Runs the Syncthing GUI TLS config migration.
  syncthingGuiTls = false;

  # nix-darwin-managed system shell integration and font installation.
  # Examples: [ "git" "zsh" ]
  systemPackageKeys = [ ];
  systemShell = false;
  fonts = false;

  # Declarative Homebrew management. Start empty and add one formula/cask at a time.
  homebrewBrews = [ ];
  homebrewCasks = [ ];
}
