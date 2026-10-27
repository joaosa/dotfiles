{
  context7-mcp,
  fetchFromGitHub,
  fetchPnpmDeps,
  lib,
  nodejs,
  pnpm_10,
}:

(context7-mcp.override { inherit nodejs; }).overrideAttrs (
  finalAttrs: previousAttrs: {
    version = "4.0.2";
    src = fetchFromGitHub {
      owner = "upstash";
      repo = "context7";
      tag = "@upstash/context7-mcp@${finalAttrs.version}";
      hash = "sha256-mRjDG+hGG7gU+05CMAtBy7oVFRNSQgQMWgMEnfmmlSM=";
    };
    pnpmDeps = fetchPnpmDeps {
      inherit (finalAttrs) pname version src;
      pnpm = pnpm_10;
      fetcherVersion = 3;
      hash = "sha256-F3c2/y3fgtPiUQOsg3hFdAp9b85AFs2mCTO1Eoa0i5E=";
    };
    # Upstream deploys devDependencies too (vitest -> rollup/fsevents native
    # blobs); ship runtime dependencies only.
    installPhase = lib.replaceStrings [ " deploy " ] [ " --prod deploy " ] previousAttrs.installPhase;
  }
)
