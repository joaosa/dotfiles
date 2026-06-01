{
  pkgs,
  username,
  ...
}:

let
  brews = [ ];
  casks = [
    "karabiner-elements"
    "hammerspoon"
    "alacritty"
    "obsidian"
    "slack"
    "orcaslicer"
    "spotify"
    "firefox@developer-edition"
    "google-drive"
  ];
  homebrewEnabled = brews != [ ] || casks != [ ];
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

    inherit brews casks;

    global.autoUpdate = false;
    onActivation = {
      autoUpdate = false;
      upgrade = false;
      cleanup = "none";
    };
  };
}
