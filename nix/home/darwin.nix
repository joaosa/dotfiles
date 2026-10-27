{
  config,
  lib,
  pkgs,
  dotfilesPath,
  ...
}:

let
  link = relativePath: config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/${relativePath}";
  ollamaPackage = pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "ollama-bin";
    version = "0.32.9";

    src = pkgs.fetchurl {
      url = "https://github.com/ollama/ollama/releases/download/v${finalAttrs.version}/ollama-darwin.tgz";
      hash = "sha256-F6WwltRRXQCmQVAS24R6KzU7OJ7XqzPQJeO5jC8FtJw=";
    };

    sourceRoot = ".";

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/bin" "$out/libexec"
      cp -R . "$out/libexec/ollama"
      ln -s ../libexec/ollama/ollama "$out/bin/ollama"

      runHook postInstall
    '';

    # Preserve the upstream binary bytes and relocatable runtime layout.
    dontFixup = true;

    meta = {
      description = "Get up and running with large language models locally";
      homepage = "https://ollama.com";
      changelog = "https://github.com/ollama/ollama/releases/tag/v${finalAttrs.version}";
      license = lib.licenses.mit;
      sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
      platforms = lib.platforms.darwin;
      mainProgram = "ollama";
    };
  });
  obsidianCli = ''
    #!${pkgs.bash}/bin/bash
    exec /Applications/Obsidian.app/Contents/MacOS/Obsidian "$@"
  '';
in
lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
  # Store/retrieve key passphrases in the macOS keychain when the agent
  # loads keys (pairs with AddKeysToAgent in common.nix).
  programs.ssh.settings."*".UseKeychain = "yes";

  # AirPlay Receiver listens on *:5000/*:7000; off by default, `airplay on`
  # when needed. AirDrop is unaffected.
  targets.darwin.currentHostDefaults."com.apple.controlcenter".AirplayReceiverEnabled = false;

  programs.zsh.initContent = ''
    # zsh's `log` builtin (the watch login report) shadows /usr/bin/log; Apple's
    # stock /etc/zshrc disabled it, but nix-darwin's replacement does not.
    disable log

    # ControlCenter only applies the receiver setting when it restarts.
    airplay() {
      case "$1" in
        on | off)
          defaults -currentHost write com.apple.controlcenter AirplayReceiverEnabled -bool "$([[ $1 == on ]] && echo true || echo false)"
          killall ControlCenter
          ;;
        "" | status)
          if lsof -nP -iTCP:7000 -sTCP:LISTEN >/dev/null 2>&1; then echo on; else echo off; fi
          ;;
        *)
          echo "usage: airplay [on|off|status]" >&2
          return 1
          ;;
      esac
    }
  '';

  # Muse Glimmer requires a newer Ollama than the main nixpkgs pin currently
  # carries. Keep the official macOS release independently pinned so updating
  # Ollama does not upgrade the rest of the workstation.
  services.ollama.package = ollamaPackage;

  home = {
    # `open` is the macOS URL handler; set for all sessions, not just login zsh.
    sessionVariables.BROWSER = "open";

    # Homebrew and system paths exist only on macOS; keep them after the
    # cross-platform paths set in common.nix.
    sessionPath = lib.mkAfter [
      "/opt/homebrew/bin"
      "/opt/homebrew/sbin"
      "/usr/local/bin"
      "/usr/local/sbin"
    ];

    # Configs for macOS-only apps (Karabiner, Hammerspoon) and the Obsidian.app
    # launcher wrappers.
    file = {
      # Apple-Silicon-specific local model; the Ollama service itself remains
      # cross-platform in common.nix.
      ".config/opencode/opencode.json".source = link "config/opencode/opencode.json";
      # Karabiner-Elements rewrites karabiner.json at runtime, so the repo copy
      # tracks the app's last write (expect git churn). It is kept under version
      # control deliberately, as a backup/restore point for the key remaps.
      ".config/karabiner/karabiner.json" = {
        source = link "config/karabiner/karabiner.json";
        force = true;
      };
      ".hammerspoon/config".source = link "config/hammerspoon/config";
      ".hammerspoon/init.lua".source = link "config/hammerspoon/init.lua";
      ".hammerspoon/lib".source = link "config/hammerspoon/lib";
      ".hammerspoon/modules".source = link "config/hammerspoon/modules";
      # Audited third-party spoon, pinned and stripped of binary blobs (see
      # the derivation); loaded by modules/vim.lua.
      ".hammerspoon/Spoons/VimMode.spoon".source = pkgs.callPackage ../packages/vimmode-spoon.nix { };
      # The volume is case-insensitive, so this also answers to `obsidian`.
      ".local/bin/Obsidian" = {
        text = obsidianCli;
        executable = true;
      };
    };
  };

  # waitForNixStore = false starts each agent through a launcher named after it
  # instead of the /bin/sh wait4path wrapper, so Login Items lists it by name
  # rather than as "sh". They start at login, after the boot job mounts /nix.
  launchd.agents = {
    # Extend Home Manager's Ollama launch agent rather than declaring a second
    # service that would compete for localhost:11434.
    ollama = {
      waitForNixStore = false;
      config = {
        StandardOutPath = "${config.home.homeDirectory}/Library/Logs/ollama.log";
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/ollama.log";
      };
    };
    syncthing.waitForNixStore = false;
    syncthing-init.waitForNixStore = false;
  };

  # The pinned Home Manager invokes `launchctl bootout --wait`, but macOS 15's
  # launchctl does not support that flag. Unload a changed or stale Ollama job
  # with the compatible syntax and remove its plist so setupLaunchAgents can
  # bootstrap the new definition without trying the unsupported command.
  # This also removes the service's former nix-darwin-owned launch agent.
  home.activation.prepareOllamaLaunchAgent = lib.hm.dag.entryBefore [ "setupLaunchAgents" ] ''
    legacyAgent="${config.home.homeDirectory}/Library/LaunchAgents/com.ollama.serve.plist"
    if [ -e "$legacyAgent" ]; then
      run /bin/launchctl bootout "gui/$UID/com.ollama.serve" 2>/dev/null || true
      run /bin/rm -f "$legacyAgent"
    fi

    agentName="org.nix-community.home.ollama"
    currentAgent="${config.home.homeDirectory}/Library/LaunchAgents/$agentName.plist"
    nextAgent="$newGenPath/LaunchAgents/$agentName.plist"
    loadedAgent=$(/bin/launchctl print "gui/$UID/$agentName" 2>/dev/null || true)

    if [ -e "$currentAgent" ] && {
      [ ! -e "$nextAgent" ] \
        || ! /usr/bin/cmp -s "$nextAgent" "$currentAgent" \
        || [[ "$loadedAgent" != *"${ollamaPackage}/bin/ollama serve"* ]]
    }; then
      run /bin/launchctl bootout "gui/$UID/$agentName" 2>/dev/null || true
      run /bin/rm -f "$currentAgent"
    fi
  '';
}
