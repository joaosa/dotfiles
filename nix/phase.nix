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
    "asciinema-edit"
    "asdf-vm"
    "azure-cli"
    "bash"
    "bottom"
    "cargo-bloat"
    "cargo-geiger"
    "cargo-llvm-cov"
    "cargo-nextest"
    "cargo-watch"
    "claude-code"
    "codex"
    "colima"
    "coreutils"
    "crane"
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
    "go"
    "gore"
    "google-cloud-sdk"
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
    "mitmproxy"
    "mkcert"
    "mtr"
    "neovim"
    "nodejs"
    "nmap"
    "opencode"
    "openpgp-card-tool-git"
    "openpgp-card-tools"
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
    "tailscale"
    "tcptraceroute"
    "terminal-notifier"
    "tesseract"
    "tmux"
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
  homeFileTargets = [
    ".config/alacritty"
    ".config/karabiner"
    ".config/nvim/init.lua"
    ".config/nvim/lua"
    ".config/ruff"
    ".config/starship.toml"
    ".gitconfig"
    ".gitignore_global"
    ".hammerspoon/config"
    ".hammerspoon/init.lua"
    ".hammerspoon/lib"
    ".hammerspoon/modules"
    ".kubectl_aliases"
    ".local/bin/Obsidian"
    ".local/bin/obsidian"
    ".lightline.conf"
    ".parallel/will-cite"
    ".stylua.toml"
    ".tmux.conf"
    ".zprofile"
    ".zpreztorc"
    ".zprezto"
    ".zshenv"
    ".zshrc"
    ".yamllint"
  ];

  # Replaces shell startup behavior with the Home Manager zsh/prezto config.
  homeShell = false;

  # Runs the Syncthing GUI TLS config migration.
  syncthingGuiTls = false;

  # Provides Nix gettext at the legacy Homebrew opt path for asdf-built Python.
  asdfPythonGettextShim = true;

  # Home Manager-managed launchd services.
  ollamaService = true;
  syncthingService = true;

  # Home Manager-managed model data.
  qwen3AsrModel = true;

  # nix-darwin-managed system launchd services.
  tailscaleService = true;

  # nix-darwin-managed system shell integration and Home Manager-managed fonts.
  # Examples: [ "git" "zsh" ]
  systemPackageKeys = [ ];
  systemShell = false;
  fonts = true;

  # Declarative Homebrew management. Start empty and add one formula/cask at a time.
  homebrewBrews = [ ];
  homebrewCasks = [
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
