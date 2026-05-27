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
    "ansible"
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
    "colima"
    "coreutils"
    "delve"
    "delta"
    "direnv"
    "dive"
    "docker"
    "docker-buildx"
    "findutils"
    "fluxcd"
    "fortune"
    "fswatch"
    "fzf"
    "gawk"
    "gettext"
    "gh"
    "ghq"
    "git"
    "git-crypt"
    "git-extras"
    "git-filter-repo"
    "git-secret"
    "gitmux"
    "gitleaks"
    "gnu-prefixed-tools"
    "gnugrep"
    "gnupg"
    "gnused"
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
    "lima"
    "lua"
    "luajit"
    "luarocks"
    "miller"
    "mkcert"
    "mtr"
    "neovim"
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
    "tailscale"
    "tesseract"
    "units"
    "tree"
    "uv"
    "vegeta"
    "watch"
    "websocat"
    "wireguard-go"
    "wireguard-tools"
    "yq-go"
    "ykman"
    "zoxide"
    "zsh"
  ];

  # Home Manager-managed dotfiles by target path.
  # Examples: [ ".gitconfig" ".tmux.conf" ".config/nvim" ]
  homeFileTargets = [ ];

  # Replaces shell startup behavior with the Home Manager zsh/prezto config.
  homeShell = false;

  # Runs the Syncthing GUI TLS config migration.
  syncthingGuiTls = false;

  # Provides Nix gettext at the legacy Homebrew opt path for asdf-built Python.
  asdfPythonGettextShim = true;

  # Home Manager-managed launchd services.
  ollamaService = true;
  syncthingService = true;

  # nix-darwin-managed system shell integration and font installation.
  # Examples: [ "git" "zsh" ]
  systemPackageKeys = [ ];
  systemShell = false;
  fonts = false;

  # Declarative Homebrew management. Start empty and add one formula/cask at a time.
  homebrewBrews = [ ];
  homebrewCasks = [
    "gcloud-cli"
    "font-sauce-code-pro-nerd-font"
    "karabiner-elements"
    "hammerspoon"
    "alacritty"
    "obsidian"
    "slack"
    "orcaslicer"
    "spotify"
    "firefox@developer-edition"
    "google-drive"
  ];
}
