{
  lib,
  rustPlatform,
  fetchCrate,
  stdenv,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "qwen-asr-cli";
  version = "0.3.0";

  src = fetchCrate {
    inherit (finalAttrs) pname version;
    hash = "sha256-m04I5AEU/gg/pQr9gg9S2DoSc3gT7U4x+t5iEM6dlg4=";
  };

  cargoHash = "sha256-0E2YWY+qbHP3+TJpEngRauq5Z0I2NyKSeuFIvXF/Jp0=";

  # A fixed Apple Silicon baseline rather than target-cpu=native: native
  # resolves to the build host's chip (apple-m3 locally, older on CI runners),
  # which is non-reproducible and breaks ring's build under nix's cc-wrapper on
  # the runner. apple-m1 is <= any arm64 Mac/runner, so the binary builds
  # everywhere and still runs on this machine.
  RUSTFLAGS = lib.optionalString stdenv.hostPlatform.isDarwin "-C target-cpu=apple-m1";

  doCheck = false;

  meta = {
    description = "Qwen3-ASR speech-to-text CLI";
    homepage = "https://github.com/huanglizhuo/QwenASR";
    license = lib.licenses.mit;
    mainProgram = "qwen-asr";
  };
})
