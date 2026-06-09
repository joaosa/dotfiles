{
  config,
  lib,
  pkgs,
  username,
  homeDir,
  dotfilesPath,
  ...
}:

let
  link = relativePath: config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/${relativePath}";
  kubectlAliases = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/ahmetb/kubectl-aliases/7549fa45bbde7499b927c74cae13bfb9169c9497/.kubectl_aliases";
    hash = "sha256-Kqb6kk2EZjoX55flZqiuNRLJQDfC2XMgO+F3tyCEnqk=";
  };
  homePackages = import ../packages.nix {
    inherit pkgs;
  };
  qwen3AsrModel = import ./qwen3-asr.nix { inherit pkgs; };
  pkgConfigEnv = pkgs.buildEnv {
    name = "home-pkg-config-path";
    paths = homePackages;
    pathsToLink = [
      "/lib/pkgconfig"
      "/share/pkgconfig"
    ];
  };
  # Config files for cross-platform tools, symlinked out-of-store from this repo
  # so edits take effect without a rebuild. macOS-app configs live in darwin.nix.
  commonFiles = {
    ".config/alacritty/alacritty.toml".source = link "config/alacritty/alacritty.toml";
    ".config/nvim/init.lua".source = link "config/nvim/init.lua";
    ".config/nvim/lua".source = link "config/nvim/lua";
    ".config/git/allowed_signers".source = link "config/git/allowed_signers";
    ".config/ruff/ruff.toml".source = link "config/ruff/ruff.toml";
    ".gitconfig".source = link "config/git/gitconfig";
    ".gitignore_global".source = link "config/git/gitignore_global";
    ".kubectl_aliases" = {
      source = kubectlAliases;
      force = true;
    };
    ".lightline.conf".source = link "config/tmux/lightline.conf";
    ".parallel/will-cite" = {
      text = "";
      force = true;
    };
    ".stylua.toml".source = link "config/stylua/stylua.toml";
    ".tmux.conf".source = link "config/tmux/tmux.conf";
    ".yamllint".source = link "config/yamllint/yamllint";
    # zsh runcoms (.zshrc/.zshenv/.zprofile/.zpreztorc) and prezto are generated
    # by programs.zsh below, not linked from config/.
  };
in
{
  xdg.enable = true;

  home = {
    packages = homePackages;

    sessionPath = [
      "${homeDir}/.local/bin"
      "${homeDir}/.cargo/bin"
      "${homeDir}/.go/bin"
    ];

    sessionVariables = {
      PKG_CONFIG_PATH = lib.concatStringsSep ":" [
        "${pkgConfigEnv}/lib/pkgconfig"
        "${pkgConfigEnv}/share/pkgconfig"
        "${homeDir}/.nix-profile/lib/pkgconfig"
        "${homeDir}/.nix-profile/share/pkgconfig"
        "/run/current-system/sw/lib/pkgconfig"
        "/run/current-system/sw/share/pkgconfig"
      ];
      EDITOR = "nvim";
      VISUAL = "nvim";
      PAGER = "less";
      LANG = "en_US.UTF-8";
      GOPATH = "${homeDir}/.go";
      LESS = "-F -g -i -M -R -S -w -X -z-4";
    };

    file = commonFiles // {
      ".npmrc".text = ''
        prefix=${homeDir}/.local
      '';
      ".docker/cli-plugins/docker-buildx" = {
        source = "${pkgs.docker-buildx}/bin/docker-buildx";
        force = true;
      };
      ".local/share/qwen3-asr/Qwen3-ASR-0.6B" = {
        source = qwen3AsrModel;
        force = true;
      };
    };

    activation.npmPrefix = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      /bin/mkdir -p "${homeDir}/.local/bin" "${homeDir}/.local/lib/node_modules"
    '';

    activation.qwen3AsrModelPath = lib.hm.dag.entryBefore [ "linkGeneration" ] ''
      target="${homeDir}/.local/share/qwen3-asr/Qwen3-ASR-0.6B"
      backup="$target.before-nix"

      if [ -e "$target" ] && [ ! -L "$target" ]; then
        if [ -e "$backup" ]; then
          echo "Refusing to replace $target because $backup already exists"
          exit 1
        fi

        /bin/mv "$target" "$backup"
      fi
    '';
  };

  services = {
    ollama = {
      enable = true;
      environmentVariables = {
        OLLAMA_FLASH_ATTENTION = "1";
        OLLAMA_KV_CACHE_TYPE = "q8_0";
      };
    };

    syncthing = {
      enable = true;
      overrideDevices = false;
      overrideFolders = false;
    };
  };

  programs = {
    home-manager.enable = true;

    fzf = {
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

    direnv = {
      enable = true;
      enableZshIntegration = true;
    };

    zoxide = {
      enable = true;
      enableZshIntegration = true;
    };

    starship = {
      enable = true;
      enableZshIntegration = true;
      settings = builtins.fromTOML (builtins.readFile ../../config/starship/starship.toml);
    };

    gh = {
      enable = true;
      settings = {
        git_protocol = "https";
        aliases.co = "pr checkout";
      };
    };

    gh-dash = {
      enable = true;
      settings = {
        prSections = [
          {
            title = "My Pull Requests";
            filters = "is:pr author:@me state:open archived:false sort:updated-desc";
          }
          {
            title = "Needs My Review";
            filters = "is:open review-requested:@me";
          }
          {
            title = "Merged";
            filters = "is:pr author:@me state:merged archived:false sort:updated-desc";
          }
          {
            title = "Involved";
            filters = "is:open involves:@me -author:@me";
          }
        ];
        issuesSections = [
          {
            title = "My Issues";
            filters = "is:open author:@me";
          }
          {
            title = "Assigned";
            filters = "is:open assignee:@me";
          }
        ];
      };
    };

    zsh = {
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
        gcom = "git checkout main";
        gbpm = "git fetch -p; git branch --merged main | grep -vE '^[*+]| (main|master)$' | xargs -r git branch -d; git branch -vv | awk '/\\[gone\\]/ {print $1}' | grep -vE '^(main|master)$' | xargs -r git branch -D";
        gtx = "git fetch --prune --prune-tags --tags";
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
        # No prezto prompt; starship owns the prompt (see programs.starship above).
        prompt.theme = "off";
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
        if (( $#commands[(i)lesspipe(|.sh)] )); then
          export LESSOPEN="| /usr/bin/env $commands[(i)lesspipe(|.sh)] %s 2>&-"
        fi

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

          _prefer_nix_profile_paths() {
            typeset -gU path
            local -a nix_profile_paths

            [[ -d "/etc/profiles/per-user/${username}/bin" ]] && nix_profile_paths+=("/etc/profiles/per-user/${username}/bin")
            [[ -d "${homeDir}/.nix-profile/bin" ]] && nix_profile_paths+=("${homeDir}/.nix-profile/bin")
            [[ -d /nix/var/nix/profiles/default/bin ]] && nix_profile_paths+=(/nix/var/nix/profiles/default/bin)

            path=($nix_profile_paths $path)
          }

          _prefer_nix_profile_paths
          unfunction _prefer_nix_profile_paths

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
  };
}
