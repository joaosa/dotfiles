{ lib, phase, ... }:

{
  launchd.daemons.tailscaled = lib.mkIf (builtins.elem "tailscale" phase.homebrewBrews) {
    serviceConfig = {
      Label = "com.tailscale.tailscaled";
      ProgramArguments = [
        "/opt/homebrew/opt/tailscale/bin/tailscaled"
        "--hardware-attestation=false"
      ];
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "/opt/homebrew/var/log/tailscaled.log";
      StandardErrorPath = "/opt/homebrew/var/log/tailscaled.log";
    };
  };
}
