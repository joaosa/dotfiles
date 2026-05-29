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
  sauceCodeProNerdFont =
    if builtins.hasAttr "nerd-fonts" pkgs && builtins.hasAttr "sauce-code-pro" pkgs.nerd-fonts then
      pkgs.nerd-fonts.sauce-code-pro
    else
      null;
  kubectlAliases = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/ahmetb/kubectl-aliases/7549fa45bbde7499b927c74cae13bfb9169c9497/.kubectl_aliases";
    hash = "sha256-Kqb6kk2EZjoX55flZqiuNRLJQDfC2XMgO+F3tyCEnqk=";
  };
  obsidianCli = ''
    #!${pkgs.bash}/bin/bash
    exec /Applications/Obsidian.app/Contents/MacOS/Obsidian "$@"
  '';
  homePackages = import ../packages.nix {
    inherit lib pkgs;
    enabledKeys = phase.homePackageKeys;
  };
  pkgConfigEnv = pkgs.buildEnv {
    name = "home-pkg-config-path";
    paths = homePackages;
    pathsToLink = [
      "/lib/pkgconfig"
      "/share/pkgconfig"
    ];
  };
  allHomeFiles = {
    ".config/alacritty".source = link "stow/alacritty/.config/alacritty";
    ".config/karabiner" = {
      source = link "stow/karabiner/.config/karabiner";
      force = true;
    };
    ".config/nvim/init.lua".source = link "stow/nvim/.config/nvim/init.lua";
    ".config/nvim/lua".source = link "stow/nvim/.config/nvim/lua";
    ".config/opencode".source = link "stow/opencode/.config/opencode";
    ".config/ruff".source = link "stow/ruff/.config/ruff";
    ".config/starship.toml".source = link "stow/starship/.config/starship.toml";
    ".gitconfig".source = link "stow/git/.gitconfig";
    ".gitignore_global".source = link "stow/git/.gitignore_global";
    ".hammerspoon/config".source = link "stow/hammerspoon/.hammerspoon/config";
    ".hammerspoon/init.lua".source = link "stow/hammerspoon/.hammerspoon/init.lua";
    ".hammerspoon/lib".source = link "stow/hammerspoon/.hammerspoon/lib";
    ".hammerspoon/modules".source = link "stow/hammerspoon/.hammerspoon/modules";
    ".kubectl_aliases" = {
      source = kubectlAliases;
      force = true;
    };
    ".lightline.conf".source = link "stow/tmux/.lightline.conf";
    ".local/bin/Obsidian" = {
      text = obsidianCli;
      executable = true;
    };
    ".local/bin/obsidian" = {
      text = obsidianCli;
      executable = true;
    };
    ".parallel/will-cite" = {
      text = "";
      force = true;
    };
    ".stylua.toml".source = link "stow/stylua/.stylua.toml";
    ".tmux.conf".source = link "stow/tmux/.tmux.conf";
    ".yamllint".source = link "stow/nvim/.yamllint";
    ".zprofile".source = link "stow/zsh/.zprofile";
    ".zpreztorc".source = link "stow/zsh/.zpreztorc";
    ".zprezto".source = "${pkgs.zsh-prezto}/share/zsh-prezto";
    ".zshenv" = {
      source = link "stow/zsh/.zshenv";
      force = true;
    };
    ".zshrc".source = link "stow/zsh/.zshrc";
  };
in
{
  home.username = username;
  home.homeDirectory = homeDir;
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;
  xdg.enable = true;

  home.packages = homePackages;

  home.sessionPath = lib.mkIf phase.homeShell [
    "${homeDir}/.local/bin"
    "${homeDir}/.cargo/bin"
    "${homeDir}/.go/bin"
    "/opt/homebrew/bin"
    "/opt/homebrew/sbin"
    "/usr/local/bin"
    "/usr/local/sbin"
  ];

  home.sessionVariables = {
    PKG_CONFIG_PATH = lib.concatStringsSep ":" [
      "${pkgConfigEnv}/lib/pkgconfig"
      "${pkgConfigEnv}/share/pkgconfig"
      "${homeDir}/.nix-profile/lib/pkgconfig"
      "${homeDir}/.nix-profile/share/pkgconfig"
      "/run/current-system/sw/lib/pkgconfig"
      "/run/current-system/sw/share/pkgconfig"
    ];
  }
  // lib.optionalAttrs phase.homeShell {
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

  home.activation.asdfPythonGettextShim = lib.mkIf phase.asdfPythonGettextShim (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      gettext_opt="/opt/homebrew/opt/gettext"

      if [ -e "$gettext_opt" ] && [ ! -L "$gettext_opt" ]; then
        echo "Skipping $gettext_opt because it exists and is not a symlink"
      else
        /bin/mkdir -p /opt/homebrew/opt
        /bin/ln -sfn "${pkgs.gettext}" "$gettext_opt"
      fi
    ''
  );

  home.activation.sauceCodeProNerdFont = lib.mkIf (phase.fonts && sauceCodeProNerdFont != null) (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      font_src="${sauceCodeProNerdFont}/share/fonts/truetype/NerdFonts/SauceCodePro"
      font_dst="${homeDir}/Library/Fonts"

      /bin/mkdir -p "$font_dst"
      /usr/bin/find "$font_dst" -maxdepth 1 -type f -name 'SauceCodeProNerdFont*.ttf' -delete
      ${pkgs.rsync}/bin/rsync -acL --chmod=u+w "$font_src"/SauceCodeProNerdFont*.ttf "$font_dst"/
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

        _prefer_nix_profile_paths() {
          typeset -gU path
          local -a nix_profile_paths

          [[ -d "/etc/profiles/per-user/${username}/bin" ]] && nix_profile_paths+=("/etc/profiles/per-user/${username}/bin")
          [[ -d "${homeDir}/.nix-profile/bin" ]] && nix_profile_paths+=("${homeDir}/.nix-profile/bin")
          [[ -d /nix/var/nix/profiles/default/bin ]] && nix_profile_paths+=(/nix/var/nix/profiles/default/bin)

          path=($nix_profile_paths $path)
        }

        _prefer_nix_profile_paths

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
        _prefer_nix_profile_paths
        unfunction _prefer_nix_profile_paths

        command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"
        command -v starship >/dev/null 2>&1 && eval "$(starship init zsh)"

        [ -f ~/.kubectl_aliases ] && source ~/.kubectl_aliases
        function kubectl() { echo "+ kubectl $@">&2; command kubectl "$@"; }

        function tmux() {
          if [[ -n "$TMUX" && ( "$1" == "a" || "$1" == "attach" || "$1" == "attach-session" ) ]]; then
            shift
            if (( $# == 0 )); then
              local session
              session=$(command tmux list-sessions -F '#{session_name}' -f '#{==:#{session_attached},0}' 2>/dev/null | head -1)
              [[ -n "$session" ]] && command tmux switch-client -t "$session" || command tmux switch-client
            else
              command tmux switch-client "$@"
            fi
          else
            command tmux "$@"
          fi
        }

        if [[ -z "$TMUX" && -t 0 && -t 1 ]] && command -v tmux >/dev/null 2>&1; then
          session=$(tmux list-sessions -F '#{session_name}' -f '#{==:#{session_attached},0}' 2>/dev/null | head -1)
          if [[ -n "$session" ]]; then
            tmux attach -t "$session" || true
          else
            tmux new-session -s "default-$$" || true
          fi
        fi
      ''
    ];
  };
}
