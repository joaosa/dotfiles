{
  fetchFromGitHub,
  lua54Packages,
  stdenvNoCC,
}:

# System-wide vim mode for Hammerspoon. Only the runtime files are installed;
# the vendored prebuilt binaries are dropped in favour of auditable sources:
#  - vendor/luautf8/*.so is replaced by the nixpkgs source build of lua-utf8
#    (the spoon's wrapper prefers a loadable `lua-utf8` over its blobs), and
#  - vendor/hs is a fallback for Hammerspoon < 0.9.79, never loaded today.
stdenvNoCC.mkDerivation {
  pname = "vimmode-spoon";
  version = "0-unstable-2026-02-15";

  src = fetchFromGitHub {
    owner = "dbalatero";
    repo = "VimMode.spoon";
    rev = "a428e1ae9cc5d937fa6d148da6e2a779c7594abd";
    hash = "sha256-C4WDpMVDF0zuDV4rZYx05gwn8YZf3tOGegBj8dma8vY=";
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    mkdir -p "$out/vendor"
    cp -R init.lua lib docs.json "$out/"
    cp vendor/luautf8.lua "$out/vendor/"
    cp ${lua54Packages.luautf8}/lib/lua/5.4/lua-utf8.so "$out/vendor/lua-utf8.so"
  '';
}
