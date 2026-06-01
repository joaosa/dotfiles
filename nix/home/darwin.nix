{
  config,
  lib,
  pkgs,
  homeDir,
  dotfilesPath,
  ...
}:

let
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  link = relativePath: config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/${relativePath}";
  sauceCodeProNerdFont =
    if builtins.hasAttr "nerd-fonts" pkgs && builtins.hasAttr "sauce-code-pro" pkgs.nerd-fonts then
      pkgs.nerd-fonts.sauce-code-pro
    else
      null;
  obsidianCli = ''
    #!${pkgs.bash}/bin/bash
    exec /Applications/Obsidian.app/Contents/MacOS/Obsidian "$@"
  '';
in
lib.mkIf isDarwin {
  # macOS-only packages (e.g. the pinentry that talks to the macOS keychain).
  home.packages = [
    pkgs.pinentry_mac
  ];

  # `open` is the macOS URL handler; set for all sessions, not just login zsh.
  home.sessionVariables.BROWSER = "open";

  # Homebrew and system paths exist only on macOS; keep them after the
  # cross-platform paths set in common.nix.
  home.sessionPath = lib.mkAfter [
    "/opt/homebrew/bin"
    "/opt/homebrew/sbin"
    "/usr/local/bin"
    "/usr/local/sbin"
  ];

  # Configs for macOS-only apps (Karabiner, Hammerspoon) and the Obsidian.app
  # launcher wrappers.
  home.file = {
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

  home.activation.sauceCodeProNerdFont = lib.mkIf (sauceCodeProNerdFont != null) (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      font_src="${sauceCodeProNerdFont}/share/fonts/truetype/NerdFonts/SauceCodePro"
      font_dst="${homeDir}/Library/Fonts"

      /bin/mkdir -p "$font_dst"
      /usr/bin/find "$font_dst" -maxdepth 1 -type f -name 'SauceCodeProNerdFont*.ttf' -delete
      ${pkgs.rsync}/bin/rsync -acL --chmod=u+w "$font_src"/SauceCodeProNerdFont*.ttf "$font_dst"/
    ''
  );
}
