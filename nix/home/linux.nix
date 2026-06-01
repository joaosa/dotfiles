{ lib, pkgs, ... }:

# Linux-only home configuration. Empty today; this is where a future Linux host
# adds things like fontconfig, GTK/cursor themes, or systemd user services.
lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
}
