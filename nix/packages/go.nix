{
  lib,
  go_1_27,
}:

let
  version = "1.27.3";
in
# The one Go pin. The host takes the nixpkgs package; the devcontainer
# downloads the same release, checked against the digests below.
assert lib.assertMsg (
  go_1_27.version == version
) "nixpkgs now has Go ${go_1_27.version}: update version and linuxSha256 in go.nix.";

{
  package = go_1_27;
  inherit version;
  # Official linux archive checksums from go.dev/dl.
  linuxSha256 = {
    amd64 = "65efbc80fdc1fa2cd2631cad5b481777a68e8725f34e89f50fc6ac714e379b40";
    arm64 = "a06e99309dbcbdca1a8ccd2282c3ee146e55930886e26b4f1193269587165f49";
  };
}
