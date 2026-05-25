{
  inputs,
  lib,
  phase,
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
  systemPackagesByKey = {
    inherit (pkgs) git zsh;
  };
in
{
  imports = [ ./homebrew.nix ];

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

  system.primaryUser = username;
  system.configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;
  system.stateVersion = 6;

  users.users.${username} = {
    name = username;
    home = "/Users/${username}";
  };

  environment.systemPackages = lib.attrVals phase.systemPackageKeys systemPackagesByKey;
  environment.pathsToLink = lib.mkIf phase.systemShell [ "/share/zsh" ];
  environment.shells = lib.mkIf phase.systemShell [ pkgs.zsh ];
  programs.zsh.enable = phase.systemShell;

  fonts.packages = lib.mkIf phase.fonts sauceCodeProNerdFont;
}
