{
  lib,
  stdenvNoCC,
  fetchurl,
  nodejs_24,
}:

let
  version = "24.22.3";
in
# Official Node security release ahead of nixpkgs; drop for pkgs.nodejs once it catches up.
assert lib.assertMsg (lib.versionOlder nodejs_24.version version)
  "nixpkgs now has Node ${nodejs_24.version}: use pkgs.nodejs here and in devc.nix, then delete nodejs-bin.nix.";

stdenvNoCC.mkDerivation {
  pname = "nodejs";
  inherit version;

  src = fetchurl {
    url = "https://nodejs.org/dist/v${version}/node-v${version}-darwin-arm64.tar.xz";
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
}
