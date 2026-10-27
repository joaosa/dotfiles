{
  lib,
  stdenvNoCC,
  fetchurl,
  nodejs_24,
}:

# Official Node 24.22.1 (October 20 security release); nixpkgs still ships
# 24.21.0 with unpatched c-ares/sqlite. Drop this file for pkgs.nodejs once it catches up.
assert lib.assertMsg (lib.versionOlder nodejs_24.version "24.22.1")
  "nixpkgs now has Node ${nodejs_24.version}: use pkgs.nodejs and delete nodejs-bin.nix.";

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "nodejs";
  version = "24.22.1";

  src = fetchurl {
    url = "https://nodejs.org/dist/v${finalAttrs.version}/node-v${finalAttrs.version}-darwin-arm64.tar.xz";
    sha256 = "654ba79de6155647e22321932b45f2a1ccb705976cc337c9b8e278beb085a628";
  };

  installPhase = ''
    mkdir -p $out
    cp -R bin include lib share $out/
  '';

  # Stripping or patching would break the release's code signature.
  dontFixup = true;

  meta = {
    description = "Official Node.js release binary";
    homepage = "https://nodejs.org";
    license = lib.licenses.mit;
    platforms = [ "aarch64-darwin" ];
    mainProgram = "node";
  };
})
