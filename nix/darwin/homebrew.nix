{
  config,
  inputs,
  pkgs,
  username,
  ...
}:

let
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
in
{
  nix-homebrew = {
    enable = true;
    enableRosetta = pkgs.stdenv.hostPlatform.isAarch64;
    user = username;
    autoMigrate = true;
    # Taps are pinned flake inputs and `brew tap` is disabled; nix-homebrew
    # sets HOMEBREW_NO_INSTALL_FROM_API so brew installs from these pinned
    # taps instead of the live API, making casks follow flake.lock.
    mutableTaps = false;
    taps = {
      "homebrew/homebrew-core" = inputs.homebrew-core;
      "homebrew/homebrew-cask" = inputs.homebrew-cask;
    };
  };

  homebrew = {
    enable = true;
    user = username;
    enableZshIntegration = true;

    taps = builtins.attrNames config.nix-homebrew.taps;
    inherit casks;

    global.autoUpdate = false;
    onActivation = {
      autoUpdate = false;
      upgrade = false;
      # Everything brew-installed is declared above, so removing an entry
      # from the list uninstalls it on the next switch.
      cleanup = "uninstall";
    };
  };
}
