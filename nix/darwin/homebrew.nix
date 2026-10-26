{ username, ... }:

let
  casks = [
    "karabiner-elements"
    "hammerspoon"
    "alacritty"
    "obsidian"
    "slack"
    "spotify"
    "firefox@developer-edition"
    "google-drive"
  ];
in
{
  nix-homebrew = {
    enable = true;
    user = username;
    autoMigrate = true;
  };

  homebrew = {
    enable = true;
    user = username;
    enableZshIntegration = true;

    inherit casks;

    global.autoUpdate = false;
    onActivation = {
      # Refresh the API index on switch so new casks resolve; apps self-update.
      autoUpdate = true;
      upgrade = false;
      # Everything brew-installed is declared above, so removing an entry
      # from the list uninstalls it on the next switch.
      cleanup = "uninstall";
    };
  };
}
