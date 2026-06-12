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

  environment.pathsToLink = [ "/share/zsh" ];
  environment.shells = [ pkgs.zsh ];
  # System zsh integration left off so nix-darwin does not manage /etc/zshrc;
  # Home Manager owns the user-level zsh config (~/.zshrc, plugins, starship).
  programs.zsh.enable = false;

  # Stock SauceCodePro patched with the Legacy Computing glyphs chafa needs;
  # see the derivation for why a separate fallback font cannot work here.
  fonts.packages = [
    (pkgs.callPackage ../packages/sauce-code-pro-legacy-glyphs.nix { })
  ];
}
