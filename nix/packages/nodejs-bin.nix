{
  lib,
  stdenvNoCC,
  fetchurl,
  nodejs_24,
}:

# Official Node 24.22.3 (November 10 security release); nixpkgs still ships
# 24.21.0 with unpatched c-ares/sqlite. Drop this file for pkgs.nodejs once it catches up.
assert lib.assertMsg (lib.versionOlder nodejs_24.version "24.22.3")
  "nixpkgs now has Node ${nodejs_24.version}: use pkgs.nodejs and delete nodejs-bin.nix.";

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "nodejs";
  version = "24.22.3";

  src = fetchurl {
    url = "https://nodejs.org/dist/v${finalAttrs.version}/node-v${finalAttrs.version}-darwin-arm64.tar.xz";
    sha256 = "1d64136c8a43d648d1b3bad10797a4c995b1ca032d2bde8799de43b37f058fe5";
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
