{
  pkgs,
  username,
  ...
}:

let
  homeDir = if pkgs.stdenv.hostPlatform.isDarwin then "/Users/${username}" else "/home/${username}";
  # Where this repo is checked out. Override per host if cloned elsewhere.
  dotfilesPath = "${homeDir}/ghq/github.com/joaosa/dotfiles";
in
{
  imports = [
    ./common.nix
    ./darwin.nix
    ./linux.nix
  ];

  home.username = username;
  home.homeDirectory = homeDir;
  home.stateVersion = "25.11";

  # Shared facts the split modules read via `config`.
  _module.args = { inherit homeDir dotfilesPath; };
}
