{
  config,
  lib,
  phase,
  pkgs,
  username,
  ...
}:

let
  homeDir = "/Users/${username}";
  dotfilesPath = "${homeDir}/ghq/github.com/joaosa/dotfiles";
  link = relativePath: config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/${relativePath}";
  kubectlAliases = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/ahmetb/kubectl-aliases/7549fa45bbde7499b927c74cae13bfb9169c9497/.kubectl_aliases";
    hash = "sha256-Kqb6kk2EZjoX55flZqiuNRLJQDfC2XMgO+F3tyCEnqk=";
  };
  allHomeFiles = {
    ".config/alacritty".source = link "stow/alacritty/.config/alacritty";
    ".config/karabiner/karabiner.json".source = link "stow/karabiner/.config/karabiner/karabiner.json";
    ".config/nvim".source = link "stow/nvim/.config/nvim";
    ".config/opencode".source = link "stow/opencode/.config/opencode";
    ".config/ruff".source = link "stow/ruff/.config/ruff";
    ".config/starship.toml".source = link "stow/starship/.config/starship.toml";
    ".gitconfig".source = link "stow/git/.gitconfig";
    ".gitignore_global".source = link "stow/git/.gitignore_global";
    ".hammerspoon/config".source = link "stow/hammerspoon/.hammerspoon/config";
    ".hammerspoon/init.lua".source = link "stow/hammerspoon/.hammerspoon/init.lua";
    ".hammerspoon/lib".source = link "stow/hammerspoon/.hammerspoon/lib";
    ".hammerspoon/modules".source = link "stow/hammerspoon/.hammerspoon/modules";
    ".kubectl_aliases".source = kubectlAliases;
    ".lightline.conf".source = link "stow/tmux/.lightline.conf";
    ".parallel/will-cite".text = "";
    ".stylua.toml".source = link "stow/stylua/.stylua.toml";
    ".tmux.conf".source = link "stow/tmux/.tmux.conf";
    ".yamllint".source = link "stow/nvim/.yamllint";
  };
in
{
  home.username = username;
  home.homeDirectory = homeDir;
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;
  xdg.enable = true;

  home.packages = import ../packages.nix {
    inherit lib pkgs;
    enabledKeys = phase.homePackageKeys;
  };

  home.sessionPath = lib.mkIf phase.homeShell [
    "${homeDir}/.local/bin"
    "${homeDir}/.cargo/bin"
    "${homeDir}/.go/bin"
    "/opt/homebrew/bin"
    "/opt/homebrew/sbin"
    "/usr/local/bin"
    "/usr/local/sbin"
  ];

  home.sessionVariables = lib.mkIf phase.homeShell {
    BROWSER = "open";
    EDITOR = "nvim";
    VISUAL = "nvim";
    PAGER = "less";
    LANG = "en_US.UTF-8";
    GOPATH = "${homeDir}/.go";
    LESS = "-F -g -i -M -R -S -w -X -z-4";
  };

  home.file =
    lib.filterAttrs (target: _: builtins.elem target phase.homeFileTargets) allHomeFiles
    // lib.optionalAttrs (builtins.elem "docker-buildx" phase.homePackageKeys) {
      ".docker/cli-plugins/docker-buildx" = {
        source = "${pkgs.docker-buildx}/bin/docker-buildx";
        force = true;
      };
    };

  services.ollama = lib.mkIf phase.ollamaService {
    enable = true;
    environmentVariables = {
      OLLAMA_FLASH_ATTENTION = "1";
      OLLAMA_KV_CACHE_TYPE = "q8_0";
    };
  };

  services.syncthing = lib.mkIf phase.syncthingService {
    enable = true;
    overrideDevices = false;
    overrideFolders = false;
  };

  home.activation.syncthingGuiTls = lib.mkIf phase.syncthingGuiTls (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      syncthing_config="${homeDir}/Library/Application Support/Syncthing/config.xml"
      if [ -f "$syncthing_config" ] && ${pkgs.gnugrep}/bin/grep -q '<gui enabled="true" tls="false"' "$syncthing_config"; then
        /usr/bin/sed -i.bak 's/<gui enabled="true" tls="false"/<gui enabled="true" tls="true"/' "$syncthing_config"
        /bin/rm -f "$syncthing_config.bak"
      fi
    ''
  );

  programs.fzf = lib.mkIf phase.homeShell {
    enable = true;
    enableZshIntegration = true;
    defaultCommand = "fd --type f --hidden --follow --exclude .git";
    defaultOptions = [
      "--reverse"
      "--border"
      "--preview 'bat --color=always --style=numbers --line-range=:200 {} 2>/dev/null || ls -1 {}'"
      "--preview-window right:50%:hidden"
      "--bind ?:toggle-preview"
      "--color=bg+:#3c3836,bg:#282828,spinner:#fb4934,hl:#928374"
      "--color=fg:#ebdbb2,header:#928374,info:#8ec07c,pointer:#fb4934"
      "--color=marker:#fb4934,fg+:#ebdbb2,prompt:#fb4934,hl+:#fb4934"
    ];
    fileWidgetCommand = "fd --type f --hidden --follow --exclude .git";
    fileWidgetOptions = [ "--preview-window right:50%" ];
    changeDirWidgetCommand = "fd --type d --hidden --follow --exclude .git";
    changeDirWidgetOptions = [ "--preview 'ls -1 {}'" ];
  };

  programs.zsh = lib.mkIf phase.homeShell {
    enable = true;
    dotDir = config.home.homeDirectory;
    enableCompletion = true;
    autocd = false;

    history = {
      size = 1000000;
      save = 1000000;
      path = "${homeDir}/.zsh_history";
    };

    shellAliases = {
      vi = "nvim";
      vim = "nvim";
      gcod = "git branch | grep dev | xargs git checkout";
      gcom = "git branch | grep main | xargs git checkout";
      gbpm = "git branch --merged | grep -v \"*\" | grep -v develop | grep -v master | xargs -n 1 git branch -d";
      gSp = "git submodule foreach --recursive git checkout master && git submodule foreach --recursive git pull origin master";
      gtx = "git tag -l | xargs git tag -d && git fetch -t";
    };

    prezto = {
      enable = true;
      caseSensitive = true;
      color = true;
      extraModules = [
        "attr"
        "stat"
      ];
      extraFunctions = [
        "zargs"
        "zmv"
      ];
      pmodules = [
        "environment"
        "terminal"
        "editor"
        "history"
        "tmux"
        "ssh"
        "gnu-utility"
        "utility"
        "completion"
        "docker"
        "gpg"
        "git"
        "history-substring-search"
        "syntax-highlighting"
      ];
      editor.keymap = "vi";
      gnuUtility.prefix = "g";
      ssh.identities = [ "id_ecdsa" ];
      syntaxHighlighting.highlighters = [
        "main"
        "brackets"
        "pattern"
        "line"
        "root"
      ];
      tmux.autoStartLocal = false;
    };

    profileExtra = ''
      if [[ "$OSTYPE" == darwin* ]]; then
        export BROWSER='open'
      fi

      export LESS='-F -g -i -M -R -S -w -X -z-4'
      if (( $#commands[(i)lesspipe(|.sh)] )); then
        export LESSOPEN="| /usr/bin/env $commands[(i)lesspipe(|.sh)] %s 2>&-"
      fi

      export GOPATH="${homeDir}/.go"
      export PATH="$PATH:''${GOPATH//://bin:}/bin"
    '';

    initContent = lib.mkMerge [
      (lib.mkOrder 550 ''
        fpath=(${homeDir}/.local/share/zsh/site-functions $fpath)
      '')
      ''
        export KEYTIMEOUT=1

        noop () { }
        zle -N noop
        for keymap in vicmd viins; do
          bindkey -M "$keymap" "$terminfo[kcuu1]" noop
          bindkey -M "$keymap" "$terminfo[kcud1]" noop
          bindkey -M "$keymap" "$terminfo[kcub1]" noop
          bindkey -M "$keymap" "$terminfo[kcuf1]" noop
        done

        docker-aws-login() {
          vault_user="$1"
          ecr_repo="$(aws-vault exec "$vault_user" -- aws ecr get-authorization-token --output text --query 'authorizationData[].proxyEndpoint')"
          login="$(aws-vault exec "$vault_user" -- aws ecr get-login-password)"
          echo "$login" | docker login -u AWS --password-stdin "$ecr_repo"
        }

        function sesh-sessions() {
          {
            exec </dev/tty
            exec <&1
            local session
            session=$(sesh list -t -c | fzf --height 40% --reverse --border-label ' sesh ' --border --prompt 'sesh> ')
            zle reset-prompt >/dev/null 2>&1 || true
            [[ -z "$session" ]] && return
            sesh connect "$session"
          }
        }
        if command -v sesh >/dev/null 2>&1 && command -v fzf >/dev/null 2>&1; then
          zle -N sesh-sessions
          bindkey -M vicmd '^f' sesh-sessions
          bindkey -M viins '^f' sesh-sessions
        fi

        command -v direnv >/dev/null 2>&1 && eval "$(direnv hook zsh)"

        if command -v asdf >/dev/null 2>&1; then
          asdf_prefix="$(dirname "$(dirname "$(command -v asdf)")")"
          if [ -f "$asdf_prefix/etc/profile.d/asdf-prepare.sh" ]; then
            . "$asdf_prefix/etc/profile.d/asdf-prepare.sh"
          elif [ -f "$asdf_prefix/share/asdf-vm/asdf.sh" ]; then
            . "$asdf_prefix/share/asdf-vm/asdf.sh"
          fi
        elif [ -f /opt/homebrew/opt/asdf/libexec/asdf.sh ]; then
          . /opt/homebrew/opt/asdf/libexec/asdf.sh
        elif [ -f "$HOME/.asdf/asdf.sh" ]; then
          . "$HOME/.asdf/asdf.sh"
        fi

        command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"
        command -v starship >/dev/null 2>&1 && eval "$(starship init zsh)"

        [ -f ~/.kubectl_aliases ] && source ~/.kubectl_aliases
        function kubectl() { echo "+ kubectl $@">&2; command kubectl "$@"; }

        [[ -n "$TMUX" ]] && return
        if command -v tmux >/dev/null 2>&1; then
          session=$(tmux list-sessions -F '#{session_name}' -f '#{==:#{session_attached},0}' 2>/dev/null | head -1)
          [[ -n "$session" ]] && exec tmux attach -t "$session" || exec tmux new-session -s "default-$$"
        fi
      ''
    ];
  };
}
