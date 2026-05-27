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
    "asdf-vm"
    "azure-cli"
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
    "fortune"
    "fswatch"
    "fzf"
    "gawk"
    "gh"
    "ghq"
    "git"
    "git-crypt"
    "git-extras"
    "git-secret"
    "gitmux"
    "gitleaks"
    "gnupg"
    "htop"
    "hyperfine"
    "iftop"
    "imagemagick"
    "inetutils"
    "jless"
    "jq"
    "just"
    "helm"
    "k3d"
    "k9s"
    "kubectl"
    "kubectx"
    "kubeseal"
    "leptonica"
    "libheif"
    "miller"
    "mkcert"
    "mtr"
    "nmap"
    "opencode"
    "parallel"
    "pkg-config"
    "pinentry-mac"
    "pngquant"
    "poppler"
    "prek"
    "procs"
    "pv"
    "pwgen"
    "qrencode"
    "rustup"
    "sccache"
    "shellcheck"
    "sesh"
    "sops"
    "sox"
    "starship"
    "stow"
    "tcptraceroute"
    "terminal-notifier"
    "tesseract"
    "units"
    "uv"
    "vegeta"
    "watch"
    "websocat"
    "wireguard-go"
    "wireguard-tools"
    "yq-go"
    "ykman"
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
