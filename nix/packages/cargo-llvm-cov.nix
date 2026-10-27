{
  cargo-llvm-cov,
  lib,
  stdenv,
  makeRustPlatform,
  rust,
  llvmPackages_23,
}:

if !stdenv.hostPlatform.isDarwin then
  cargo-llvm-cov
else
  # Nix's Rust 1.99 pairs LLVM 21 with an LLVM 23 profiler runtime, crashing
  # instrumented test programs at exit; use the official toolchain instead.
  assert lib.assertMsg (
    rust.packages.stable.rustc.version == "1.99.0" && rust.packages.prebuilt.rustc.version == "1.99.0"
  ) "Reassess cargo-llvm-cov.nix: the Rust toolchain changed.";
  cargo-llvm-cov.override {
    rustPlatform = makeRustPlatform rust.packages.prebuilt;
    llvmPackages_22 = llvmPackages_23;
  }
