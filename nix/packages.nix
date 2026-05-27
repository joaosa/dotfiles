{
  enabledKeys ? null,
  lib,
  pkgs,
}:

let
  enabled = key: enabledKeys == null || builtins.elem key enabledKeys;

  packageIfAvailable =
    name:
    if builtins.hasAttr name pkgs then
      let
        pkg = builtins.tryEval (builtins.getAttr name pkgs);
        available =
          if pkg.success then
            builtins.tryEval (
              lib.meta.availableOn pkgs.stdenv.hostPlatform pkg.value && !(pkg.value.meta.broken or false)
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

  packageNames = [
    "age"
    "ansible"
    "asciinema"
    "asciinema-edit"
    "asdf-vm"
    "bash"
    "bat"
    "bottom"
    "cargo-bloat"
    "cargo-geiger"
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
    "fluxcd"
    "fswatch"
    "fzf"
    "gawk"
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
    "wireguard-go"
    "wireguard-tools"
    "yq-go"
    "zoxide"
    "zsh"
  ];

  alternatives = {
    agg = [
      "asciinema-agg"
    ];
    nodejs = [
      "nodejs_22"
      "nodejs"
    ];
    go = [
      "go_1_26"
      "go"
    ];
    python = [
      "python313"
      "python3"
    ];
    dust = [
      "du-dust"
      "dust"
    ];
    poppler = [
      "poppler_utils"
      "poppler"
    ];
    helm = [
      "kubernetes-helm"
      "helm"
    ];
    units = [
      "gnu-units"
      "units"
    ];
    azure-cli = [
      "azure-cli"
      "azurecli"
    ];
  };
in
packagesFrom (builtins.filter enabled packageNames)
++ lib.concatMap firstAvailable (
  lib.attrValues (lib.filterAttrs (key: _: enabled key) alternatives)
)
