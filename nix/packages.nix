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
    "colima"
    "coreutils"
    "crane"
    "delve"
    "delta"
    "direnv"
    "dive"
    "docker"
    "docker-buildx"
    "fd"
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
    "gnugrep"
    "gnupg"
    "gnused"
    "gore"
    "htop"
    "hyperfine"
    "iftop"
    "imagemagick"
    "inetutils"
    "jless"
    "jq"
    "just"
    "k3d"
    "k9s"
    "kubectl"
    "kubectx"
    "kubeseal"
    "leptonica"
    "libheif"
    "lima"
    "lua"
    "luarocks"
    "miller"
    "mitmproxy"
    "mkcert"
    "mtr"
    "neovim"
    "nmap"
    "opencode"
    "openpgp-card-tool-git"
    "openpgp-card-tools"
    "parallel"
    "pkg-config"
    "pngquant"
    "prek"
    "procs"
    "pv"
    "pwgen"
    "qwen-asr-cli"
    "qrencode"
    "ripgrep"
    "rustup"
    "sccache"
    "shellcheck"
    "sesh"
    "sops"
    "sox"
    "starship"
    "stow"
    "tesseract"
    "tcptraceroute"
    "terminal-notifier"
    "tmux"
    "tree"
    "uv"
    "vegeta"
    "watch"
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
      "poppler-utils"
      "poppler"
    ];
    pinentry-mac = [
      "pinentry_mac"
    ];
    ykman = [
      "yubikey-manager"
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

  extraOutputs = {
    libheif = [
      pkgs.libheif.dev
    ];
  };

  extraPackages = {
    "luajit" = [
      (pkgs.runCommand "luajit-bin" { } ''
                mkdir -p "$out/bin"
                cat > "$out/bin/luajit" <<EOF
        #!${pkgs.runtimeShell}
        exec "${pkgs.luajit}/bin/luajit" "\$@"
        EOF
                chmod +x "$out/bin/luajit"
      '')
    ];

    "gnu-prefixed-tools" = [
      (pkgs.runCommand "gnu-prefixed-tools" { } ''
                mkdir -p "$out/bin"

                for dir in \
                  ${pkgs.coreutils}/bin \
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
  };
in
packagesFrom (builtins.filter enabled packageNames)
++ lib.concatMap firstAvailable (
  lib.attrValues (lib.filterAttrs (key: _: enabled key) alternatives)
)
++ lib.concatMap (key: extraOutputs.${key}) (
  builtins.filter enabled (builtins.attrNames extraOutputs)
)
++ lib.concatMap (key: extraPackages.${key}) (
  builtins.filter enabled (builtins.attrNames extraPackages)
)
