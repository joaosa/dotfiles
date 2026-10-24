{
  lib,
  stdenv,
  callPackage,
  fetchurl,
  nodejs_22,
  nodejs-slim_22,
  c-ares,
  sqlite,
  openssl,
}:

# Temporary bridge until nixpkgs patches c-ares and sqlite for the October 21
# Node security release (it already patches brotli). Keep them local to Node
# to avoid rebuilding unrelated packages.
assert lib.assertMsg (nodejs-slim_22.version == "22.23.4")
  "Reassess nodejs-security.nix: nixpkgs Node changed; remove this override once its shared dependencies are patched.";
assert lib.assertMsg (lib.versionAtLeast openssl.version "3.5.9")
  "The Node security override requires OpenSSL 3.5.9 or newer.";

let
  patchedCares =
    if lib.versionAtLeast c-ares.version "1.34.9" then
      c-ares
    else
      c-ares.overrideAttrs {
        version = "1.34.9";
        src = fetchurl {
          url = "https://github.com/c-ares/c-ares/releases/download/v1.34.9/c-ares-1.34.9.tar.gz";
          hash = "sha256-k2S3ChLrWaBoMPtIjZNX+QEA3/DZiyPqNZOhg9Q+by8=";
        };
      };

  patchedSqlite =
    if lib.versionAtLeast sqlite.version "3.53.4" then
      sqlite
    else
      sqlite.overrideAttrs {
        version = "3.53.4";
        src = fetchurl {
          url = "https://sqlite.org/2026/sqlite-src-3530400.zip";
          hash = "sha256-0Y+hWux02MF+FGP4YQla3AG1rRkCVqy0+R0i8DaNIys=";
        };
        docsrc = fetchurl {
          url = "https://sqlite.org/2026/sqlite-doc-3530400.zip";
          hash = "sha256-odD13ldIXQYnlu1+Z9r/B1i1DQAAGg8jOiwVqvQLvcg=";
        };
      };

  patchedNode =
    (nodejs-slim_22.override {
      # Inject the patched libraries into nodejs.nix's arguments.
      callPackage =
        file: args:
        callPackage file (
          args
          // {
            c-ares = patchedCares;
            sqlite = patchedSqlite;
          }
        );
    }).overrideAttrs
      (
        old:
        lib.optionalAttrs stdenv.hostPlatform.isDarwin {
          # Both Node 22.23.3 and the official 22.23.4 binary fail
          # these host-network tests here: inspector resets, IPv6 UDP times out.
          checkFlags = map (
            flag:
            if lib.hasPrefix "CI_SKIP_TESTS=" flag then
              flag + ",test-inspector-ip-detection,test-dgram-udp6-link-local-address"
            else
              flag
          ) old.checkFlags;
        }
      );
in
nodejs_22.override { nodejs-slim = patchedNode; }
