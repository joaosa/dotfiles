{
  inputs,
  pkgs,
  username,
  system,
  ...
}:

let
  sauceCodeProNerdFont =
    if builtins.hasAttr "nerd-fonts" pkgs && builtins.hasAttr "sauce-code-pro" pkgs.nerd-fonts then
      [ pkgs.nerd-fonts.sauce-code-pro ]
    else
      [ ];
in
{
  imports = [
    ./defaults.nix
    ./homebrew.nix
    ./tailscale.nix
  ];

  nixpkgs.hostPlatform = system;
  nixpkgs.config.allowUnfree = true;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.settings.trusted-users = [
    "@admin"
    username
  ];

  # Tracking unstable grows the store quickly; prune old generations weekly
  # (launchd schedule from the module defaults) and deduplicate the store.
  nix.gc = {
    automatic = true;
    options = "--delete-older-than 30d";
  };
  nix.optimise.automatic = true;

  system.primaryUser = username;
  system.configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;
  system.stateVersion = 6;

  users.users.${username} = {
    name = username;
    home = "/Users/${username}";
  };

  environment.pathsToLink = [ "/share/zsh" ];
  environment.shells = [ pkgs.zsh ];
  # System zsh integration left off so nix-darwin does not manage /etc/zshrc;
  # Home Manager owns the user-level zsh config (~/.zshrc, prezto, starship).
  programs.zsh.enable = false;

  fonts.packages = sauceCodeProNerdFont;
}
