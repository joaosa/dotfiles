{
  lib,
  rustPlatform,
  fetchCrate,
  stdenv,
  sqlite,
  libiconv,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "openpgp-card-tool-git";
  version = "0.1.6";

  src = fetchCrate {
    inherit (finalAttrs) pname version;
    hash = "sha256-n35MJIxL1H1+HYLcv6WzRnzif32GOv4Y/lFrhEn4p48=";
  };

  cargoHash = "sha256-j1Osj2rjLxrSKh82ym6PiIHVO1wLE7Ax2/5+pdRcv+E=";

  buildInputs = [ sqlite ] ++ lib.optionals stdenv.hostPlatform.isDarwin [ libiconv ];

  RUSTFLAGS = lib.optionalString stdenv.hostPlatform.isDarwin (
    lib.concatStringsSep " " [
      "-C link-arg=-framework"
      "-C link-arg=AppKit"
      "-C link-arg=-framework"
      "-C link-arg=CoreServices"
    ]
  );

  doCheck = false;

  meta = {
    description = "Git signing and verification tool focused on OpenPGP cards";
    homepage = "https://codeberg.org/openpgp-card/oct-git";
    license = with lib.licenses; [
      mit
      asl20
    ];
    mainProgram = "oct-git";
  };
})
