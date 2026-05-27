{
  lib,
  phase,
  pkgs,
  username,
  ...
}:

let
  homebrewEnabled = phase.homebrewBrews != [ ] || phase.homebrewCasks != [ ];
in
{
  nix-homebrew = {
    enable = homebrewEnabled;
    enableRosetta = pkgs.stdenv.hostPlatform.isAarch64;
    user = username;
    autoMigrate = true;
    mutableTaps = true;
  };

  homebrew = {
    enable = homebrewEnabled;
    user = username;
    enableZshIntegration = true;

    taps = lib.optional (builtins.elem "fluxcd/tap/flux" phase.homebrewBrews) "fluxcd/tap";

    brews = phase.homebrewBrews;

    casks = phase.homebrewCasks;

    global.autoUpdate = false;
    onActivation = {
      autoUpdate = false;
      upgrade = false;
      cleanup = "none";
    };
  };
}
