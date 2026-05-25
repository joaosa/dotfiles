{
  inputs,
  lib,
  pkgs,
  username,
  system,
  ...
}:

let
  sauceCodeProNerdFont =
    if
      builtins.hasAttr "nerd-fonts" pkgs
      && builtins.hasAttr "sauce-code-pro" pkgs.nerd-fonts
    then
      [ pkgs.nerd-fonts.sauce-code-pro ]
    else
      [ ];
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

  environment.systemPackages = with pkgs; [
    git
    zsh
  ];
  environment.pathsToLink = [ "/share/zsh" ];
  environment.shells = [ pkgs.zsh ];
  programs.zsh.enable = true;

  fonts.packages = sauceCodeProNerdFont;
}
