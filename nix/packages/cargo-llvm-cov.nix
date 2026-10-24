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
  # Nix's Rust 1.99 uses LLVM 21 with LLVM 23 profiling-runtime sources,
  # crashing instrumented programs at exit. Use its pinned official toolchain
  # and matching coverage tools for this package's build and tests.
  # Remove when nixpkgs aligns Rust's LLVM, profiling runtime and coverage tools.
  assert lib.assertMsg (
    rust.packages.stable.rustc.version == "1.99.0" && rust.packages.prebuilt.rustc.version == "1.99.0"
  ) "Reassess cargo-llvm-cov.nix: the Rust toolchain changed.";
  cargo-llvm-cov.override {
    rustPlatform = makeRustPlatform rust.packages.prebuilt;
    llvmPackages_22 = llvmPackages_23;
  }
