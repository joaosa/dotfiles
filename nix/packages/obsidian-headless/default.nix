{
  buildNpmPackage,
  cctools,
  fetchzip,
  lib,
  nodejs,
  python3,
  stdenv,
}:

buildNpmPackage (finalAttrs: {
  pname = "obsidian-headless";
  version = "0.0.14";

  # The GitHub repo is docs only; the client ships as a prebundled npm tarball.
  src = fetchzip {
    url = "https://registry.npmjs.org/obsidian-headless/-/obsidian-headless-${finalAttrs.version}.tgz";
    hash = "sha256-+J6C5+FFW323lYroElqE+l+kalc7oMcNDRAaYEw6QiM=";
  };

  # The pinned binary Node lacks the `python` attr buildNpmPackage reads.
  nodejs = nodejs // {
    python = python3;
  };

  # Upstream publishes no lockfile; regenerate with
  # `npm install --package-lock-only --ignore-scripts` on a version bump.
  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';
  npmDepsHash = "sha256-amzHHE9hgxsZ2tTX5Bq80ijwq60A5/lH2WaSEX302Vo=";

  dontNpmBuild = true;

  # better-sqlite3 compiles from source in the sandbox.
  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isDarwin [ cctools ];

  # Keep only the compiled addon; the gyp build tree drags Python and the
  # Node sources into the runtime closure.
  postInstall = ''
    sqlite=$out/lib/node_modules/obsidian-headless/node_modules/better-sqlite3
    mv $sqlite/build/Release/better_sqlite3.node $TMPDIR/
    rm -r $sqlite/build $sqlite/deps $sqlite/src
    install -Dm755 $TMPDIR/better_sqlite3.node -t $sqlite/build/Release
  '';

  # A build alone never starts the CLI or loads the trimmed addon.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    $out/bin/ob --help > /dev/null
    (cd $out/lib/node_modules/obsidian-headless && ${nodejs}/bin/node -e \
      'new (require("better-sqlite3"))(":memory:").prepare("select 1").get()')
    runHook postInstallCheck
  '';

  meta = {
    description = "Headless client for Obsidian Sync";
    homepage = "https://obsidian.md/help/headless";
    license = lib.licenses.unfree;
    mainProgram = "ob";
  };
})
