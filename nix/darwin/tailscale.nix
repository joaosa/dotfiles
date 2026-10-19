{
  lib,
  pkgs,
  ...
}:

let
  stateDir = "/var/lib/tailscale";
  # Shields up, enforced as device policy; "never" allow incoming = ShieldsUp.
  syspolicy = pkgs.writeText "tailscale-syspolicy.json" (
    builtins.toJSON { AllowIncomingConnections = "never"; }
  );
in
{
  environment.systemPackages = [ pkgs.tailscale ];

  # launchd has no equivalent of systemd's StateDirectory=, and it does not
  # pre-create the daemon's state dir. Without it tailscaled spawns, fails to
  # write /var/lib/tailscale/tailscaled.state, and exits (launchd then loops on
  # "spawn scheduled, active count = 0"). `script` (rather than raw
  # ProgramArguments) keeps Apple's signed /bin/sh as the launched program —
  # launchd can reject a Nix-generated script used directly as the program with
  # EX_CONFIG before it gets a chance to write its log — and adds nix-darwin's
  # `/bin/wait4path /nix/store` guard so early boot doesn't flap before the
  # store volume is mounted. Pass --state/--socket explicitly so the paths
  # match what the tailscale CLI looks for by default.
  launchd.daemons.tailscaled = {
    script = ''
      /bin/mkdir -p ${stateDir}
      exec ${lib.getExe' pkgs.tailscale "tailscaled"} \
        --state=${stateDir}/tailscaled.state \
        --socket=/var/run/tailscaled.socket \
        --syspolicy-file=${syspolicy} \
        --hardware-attestation=false
    '';
    serviceConfig = {
      Label = "com.tailscale.tailscaled";
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "/var/log/tailscaled.log";
      StandardErrorPath = "/var/log/tailscaled.log";
    };
  };
}
