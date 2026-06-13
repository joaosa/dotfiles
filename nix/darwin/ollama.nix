{
  lib,
  pkgs,
  config,
  username,
  ...
}:

{
  environment.systemPackages = [ pkgs.ollama ];

  # User agent rather than a daemon so models and state live in ~/.ollama.
  # Clients (ollmcp, opencode, ...) expect it on localhost:11434.
  launchd.user.agents.ollama = {
    serviceConfig = {
      Label = "com.ollama.serve";
      ProgramArguments = [
        (lib.getExe' pkgs.ollama "ollama")
        "serve"
      ];
      RunAtLoad = true;
      KeepAlive = true;
      EnvironmentVariables = {
        # Unload idle models after 30m. The server is kept alive indefinitely
        # by launchd, so without this a model loaded once (e.g. at boot before
        # the GPU was ready) stays resident for days pinned to CPU; expiring it
        # forces a fresh GPU-aware reload on the next request.
        OLLAMA_KEEP_ALIVE = "30m";
        # Default context is 4096, too small for notes work; 128 GB of unified
        # memory leaves ample room for the larger KV cache.
        OLLAMA_CONTEXT_LENGTH = "16384";
      };
      StandardOutPath = "${config.users.users.${username}.home}/Library/Logs/ollama.log";
      StandardErrorPath = "${config.users.users.${username}.home}/Library/Logs/ollama.log";
    };
  };
}
