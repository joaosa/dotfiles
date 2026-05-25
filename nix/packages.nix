{ lib, pkgs }:

let
  packageIfAvailable =
    name:
    if builtins.hasAttr name pkgs then
      let
        pkg = builtins.tryEval (builtins.getAttr name pkgs);
        available =
          if pkg.success then
            builtins.tryEval (
              lib.meta.availableOn pkgs.stdenv.hostPlatform pkg.value
              && !(pkg.value.meta.broken or false)
            )
          else
            {
              success = false;
              value = false;
            };
      in
      lib.optional (available.success && available.value) pkg.value
    else
      [ ];

  packagesFrom = names: lib.concatMap packageIfAvailable names;

  firstAvailable =
    names:
    let
      found = packagesFrom names;
    in
    lib.optional (found != [ ]) (builtins.head found);
in
packagesFrom [
  "age"
  "ansible"
  "asciinema"
  "asciinema-edit"
  "asdf-vm"
  "bat"
  "bottom"
  "cargo-bloat"
  "cargo-llvm-cov"
  "cargo-nextest"
  "cargo-watch"
  "claude-code"
  "codex"
  "coreutils"
  "crane"
  "delve"
  "delta"
  "direnv"
  "dive"
  "fd"
  "findutils"
  "fswatch"
  "fzf"
  "gh"
  "ghq"
  "git"
  "git-crypt"
  "git-extras"
  "git-secret"
  "gitleaks"
  "gnugrep"
  "gnupg"
  "gnused"
  "gore"
  "htop"
  "hyperfine"
  "imagemagick"
  "jless"
  "jq"
  "just"
  "k3d"
  "k9s"
  "kubectl"
  "kubectx"
  "kubeseal"
  "luarocks"
  "miller"
  "mitmproxy"
  "mkcert"
  "mtr"
  "neovim"
  "nmap"
  "openpgp-card-tool-git"
  "openpgp-card-tools"
  "parallel"
  "pkg-config"
  "pngquant"
  "procs"
  "pv"
  "pwgen"
  "qwen-asr-cli"
  "qrencode"
  "ripgrep"
  "rustup"
  "sccache"
  "shellcheck"
  "sops"
  "sox"
  "starship"
  "stow"
  "tesseract"
  "tmux"
  "uv"
  "vegeta"
  "websocat"
  "wireguard-tools"
  "yq-go"
  "zoxide"
  "zsh"
]
++ firstAvailable [
  "nodejs_22"
  "nodejs"
]
++ firstAvailable [
  "go_1_26"
  "go"
]
++ firstAvailable [
  "python313"
  "python3"
]
++ firstAvailable [
  "du-dust"
  "dust"
]
++ firstAvailable [
  "poppler_utils"
  "poppler"
]
++ firstAvailable [
  "kubernetes-helm"
  "helm"
]
++ firstAvailable [
  "gnu-units"
  "units"
]
++ firstAvailable [
  "azure-cli"
  "azurecli"
]
