{
  config,
  inputs,
  lib,
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

  # sudo's env_reset drops NIX_SSL_CERT_FILE, so nix under `make switch` falls
  # back to the stale default-profile bundle; drop once nixpkgs #570263 lands.
  security.sudo.extraConfig = ''
    Defaults env_keep += "NIX_SSL_CERT_FILE"
  '';

  users.users.${username} = {
    name = username;
    home = "/Users/${username}";
  };

  environment = {
    # Apple's curl/git/python3/openssl read /etc/ssl/cert.pem and skip revocation,
    # so point it at the filtered bundle; the hash is Apple's 15.8.1 file, and an
    # OS update restoring it fails activation until its new hash is added here.
    etc."ssl/cert.pem" = {
      inherit (config.environment.etc."ssl/certs/ca-certificates.crt") source;
      knownSha256Hashes = [ "9dae8d76e55cb08991f2b672d58999ea15560d910759c16b544f843bdffbb994" ];
    };
    # pkgconfig dirs exposed so /etc/profiles/per-user/${username} carries the
    # .pc files at a stable path; PKG_CONFIG_PATH (common.nix) points there
    # instead of at a per-generation store path that GC invalidates.
    pathsToLink = [
      "/share/zsh"
      "/lib/pkgconfig"
      "/share/pkgconfig"
    ];
    shells = [ pkgs.zsh ];
  };
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

  # fontd keeps resolving families to files the rsync above deleted and only
  # rescans on restart (launchd label com.apple.xtyped; atsutil is gone since
  # macOS 14). /run/current-system is still the previous generation here.
  system.activationScripts.fonts.text = lib.mkAfter ''
    if ! [ /run/current-system/Library/Fonts -ef "$systemConfig/Library/Fonts" ]; then
      printf >&2 'fonts changed, restarting fontd for ${username}; relaunch open terminals\n'
      launchctl kickstart -k "gui/$(id -u ${username})/com.apple.xtyped" \
        || printf >&2 'could not restart fontd; relaunch GUI apps once logged in\n'
    fi
  '';
}
