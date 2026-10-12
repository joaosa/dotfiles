{
  inputs,
  pkgs,
  username,
  system,
  ...
}:

{
  imports = [
    ./defaults.nix
    ./homebrew.nix
    ./tailscale.nix
  ];

  nixpkgs.hostPlatform = system;
  nixpkgs.config.allowUnfree = true;

  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      trusted-users = [
        "@admin"
        username
      ];
    };

    # Tracking unstable grows the store quickly; prune old generations weekly
    # (launchd schedule from the module defaults) and deduplicate the store.
    gc = {
      automatic = true;
      options = "--delete-older-than 30d";
    };
    optimise.automatic = true;
  };

  system = {
    primaryUser = username;
    configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;
    stateVersion = 6;
  };

  users.users.${username} = {
    name = username;
    home = "/Users/${username}";
  };

  # pkgconfig dirs exposed so /etc/profiles/per-user/${username} carries the
  # .pc files at a stable path; PKG_CONFIG_PATH (common.nix) points there
  # instead of at a per-generation store path that GC invalidates.
  environment.pathsToLink = [
    "/share/zsh"
    "/lib/pkgconfig"
    "/share/pkgconfig"
  ];
  environment.shells = [ pkgs.zsh ];
  # nix-darwin owns /etc/zshenv, which puts the Nix profiles on PATH and sets
  # NIX_PROFILES for every zsh; /etc/zshrc is kept inert since Home Manager
  # owns the interactive config (~/.zshrc, plugins, starship).
  programs.zsh = {
    enable = true;
    enableCompletion = false;
    enableBashCompletion = false;
    enableGlobalCompInit = false;
    # /etc/zshrc sets SAVEHIST from this; a shell that skips ~/.zshrc would
    # otherwise rewrite the shared history file truncated to 2000 entries.
    histSize = 1000000;
    # Same shared-file hazard: without timestamps, such a shell rewrites every
    # entry plain and the next ~/.zshrc shell restamps them all to "now".
    interactiveShellInit = "setopt EXTENDED_HISTORY";
  };

  # Stock SauceCodePro patched with the Legacy Computing glyphs chafa needs;
  # see the derivation for why a separate fallback font cannot work here.
  fonts.packages = [
    (pkgs.callPackage ../packages/sauce-code-pro-legacy-glyphs.nix { })
  ];

  # fontd keeps resolving families to font files the fonts rsync deleted and
  # only rescans on restart (atsutil is gone since macOS 14; the launchd label
  # is com.apple.xtyped). /run/current-system is still the previous generation
  # at this point, so the comparison only fires when the fonts closure changed.
  system.activationScripts.postActivation.text = ''
    if [ "$(readlink -f /run/current-system/Library/Fonts)" != "$(readlink -f "$systemConfig/Library/Fonts")" ]; then
      printf >&2 'fonts changed, restarting fontd for ${username}...\n'
      launchctl kickstart -k "gui/$(id -u ${username})/com.apple.xtyped" \
        || printf >&2 'could not restart fontd; relaunch GUI apps once logged in\n'
    fi
  '';
}
