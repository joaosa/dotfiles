{
  lib,
  pkgs,
  ...
}:

{
  environment.systemPackages = [ pkgs.tailscale ];

  launchd.daemons.tailscaled = {
    serviceConfig = {
      Label = "com.tailscale.tailscaled";
      ProgramArguments = [
        (lib.getExe' pkgs.tailscale "tailscaled")
        "--hardware-attestation=false"
      ];
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "/var/log/tailscaled.log";
      StandardErrorPath = "/var/log/tailscaled.log";
    };
  };
}
