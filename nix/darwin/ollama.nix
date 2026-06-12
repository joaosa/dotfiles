{
  lib,
  pkgs,
  username,
  ...
}:

{
  environment.systemPackages = [ pkgs.ollama ];

  # User agent rather than a daemon so models and state live in ~/.ollama.
  # Idle models are unloaded by ollama itself, so keeping the server up is
  # cheap; clients (ollmcp, opencode, ...) expect it on localhost:11434.
  launchd.user.agents.ollama = {
    serviceConfig = {
      Label = "com.ollama.serve";
      ProgramArguments = [
        (lib.getExe' pkgs.ollama "ollama")
        "serve"
      ];
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "/Users/${username}/Library/Logs/ollama.log";
      StandardErrorPath = "/Users/${username}/Library/Logs/ollama.log";
    };
  };
}
