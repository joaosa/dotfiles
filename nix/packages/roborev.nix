{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
}:

# Upstream dropped its flake and a source build needs Bun for the embedded
# browser app, so this pins the official release binary.
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "roborev-bin";
  version = "0.75.0";

  src = fetchurl {
    url = "https://github.com/kenn-io/roborev/releases/download/v${finalAttrs.version}/roborev_${finalAttrs.version}_darwin_arm64.tar.gz";
    hash = "sha256-aROxlc5S2NjcwrqW93u9MYyryRX7UU0sc6L8QEeWRNc=";
  };

  sourceRoot = ".";

  nativeBuildInputs = [ makeWrapper ];

  # Telemetry is opt-out; the wrapper covers git hooks run outside a login shell.
  installPhase = ''
    runHook preInstall
    install -Dm0755 roborev "$out/libexec/roborev"
    makeWrapper "$out/libexec/roborev" "$out/bin/roborev" \
      --set ROBOREV_TELEMETRY_ENABLED 0
    runHook postInstall
  '';

  # Keep the notarized upstream bytes.
  dontFixup = true;

  meta = {
    description = "Local daemon that reviews each commit with an installed coding agent";
    homepage = "https://www.roborev.io";
    changelog = "https://github.com/kenn-io/roborev/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [ "aarch64-darwin" ];
    mainProgram = "roborev";
  };
})
