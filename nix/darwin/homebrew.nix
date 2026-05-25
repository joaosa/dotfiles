{ pkgs, username, ... }:

{
  nix-homebrew = {
    enable = true;
    enableRosetta = pkgs.stdenv.hostPlatform.isAarch64;
    user = username;
    autoMigrate = true;
    mutableTaps = true;
  };

  homebrew = {
    enable = true;
    user = username;
    enableZshIntegration = true;

    taps = [
      "aviator-co/tap"
      "fluxcd/tap"
    ];

    brews = [
      "agg"
      "cargo-geiger"
      "colima"
      "docker"
      "docker-buildx"
      "fortune"
      "fluxcd/tap/flux"
      "gitmux"
      "iftop"
      "jd"
      "ollama"
      "opencode"
      "pinentry-mac"
      "prek"
      "aviator-co/tap/av"
      "sesh"
      "tailscale"
      "tcptraceroute"
      "telnet"
      "terminal-notifier"
      "watch"
      "ykman"
      {
        name = "syncthing";
        restart_service = "changed";
      }
    ];

    casks = [
      "alacritty"
      "blender"
      "discord"
      "firefox@developer-edition"
      "font-sauce-code-pro-nerd-font"
      "gcloud-cli"
      "google-drive"
      "hammerspoon"
      "ipfs-desktop"
      "karabiner-elements"
      "mullvad-vpn"
      "obsidian"
      "orcaslicer"
      "signal"
      "slack"
      "spotify"
    ];

    global.autoUpdate = false;
    onActivation = {
      autoUpdate = false;
      upgrade = false;
      cleanup = "none";
    };
  };
}
