{
  lib,
  pkgs,
  ...
}:

let
  stateDir = "/var/lib/tailscale";
  # launchd has no equivalent of systemd's StateDirectory=, and it does not
  # pre-create the daemon's state dir. Without it tailscaled spawns, fails to
  # write /var/lib/tailscale/tailscaled.state, and exits (launchd then loops on
  # "spawn scheduled, active count = 0"). Wrap the binary so the dir always
  # exists before exec, and pass --state/--socket explicitly so the paths match
  # what the tailscale CLI looks for by default.
  tailscaled = pkgs.writeShellScript "tailscaled-wrapper" ''
    /bin/mkdir -p ${stateDir}
    exec ${lib.getExe' pkgs.tailscale "tailscaled"} \
      --state=${stateDir}/tailscaled.state \
      --socket=/var/run/tailscaled.socket \
      --hardware-attestation=false
  '';
in
{
  environment.systemPackages = [ pkgs.tailscale ];

  launchd.daemons.tailscaled = {
    serviceConfig = {
      Label = "com.tailscale.tailscaled";
      ProgramArguments = [ "${tailscaled}" ];
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "/var/log/tailscaled.log";
      StandardErrorPath = "/var/log/tailscaled.log";
    };
  };
}
