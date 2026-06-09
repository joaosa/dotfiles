{
  config,
  lib,
  pkgs,
  dotfilesPath,
  ...
}:

let
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  link = relativePath: config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/${relativePath}";
  obsidianCli = ''
    #!${pkgs.bash}/bin/bash
    exec /Applications/Obsidian.app/Contents/MacOS/Obsidian "$@"
  '';
in
lib.mkIf isDarwin {
  home = {
    # macOS-only packages (e.g. the pinentry that talks to the macOS keychain).
    packages = [
      pkgs.pinentry_mac
    ];

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
      ".local/bin/Obsidian" = {
        text = obsidianCli;
        executable = true;
      };
      ".local/bin/obsidian" = {
        text = obsidianCli;
        executable = true;
      };
    };
  };
}
