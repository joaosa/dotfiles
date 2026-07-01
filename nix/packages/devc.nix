{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  makeWrapper,
  bash,
  coreutils,
  devcontainer,
  docker,
  jq,
  git,
}:

# Trail of Bits' `devc` CLI wraps the devcontainer CLI to run Claude Code in a
# sandboxed container. Upstream ships it as a self-installing git checkout
# (`install.sh self-install` symlinks it into ~/.local/bin and reads its four
# template files from the script's own directory). Here we pin it instead: the
# script and its templates are installed into the store, the template lookups
# are rewritten to that path, and `make switch` is the install/update path.
stdenvNoCC.mkDerivation {
  pname = "claude-code-devcontainer";
  version = "0-unstable-2026-06-27";

  src = fetchFromGitHub {
    owner = "trailofbits";
    repo = "claude-code-devcontainer";
    rev = "6750a78849dcb6f1477c5162a6d2185afcdbefd7";
    hash = "sha256-rGNvisG4YnyWY6X+hjEEVJ+cazzJ2PZWxpeNFjX6EvM=";
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    templates="$out/share/claude-devcontainer"
    install -Dm0644 -t "$templates" \
      Dockerfile devcontainer.json post_install.py .zshrc

    # Upstream copies templates via `cp "$SCRIPT_DIR/<file>"` (the script's own
    # dir). Under Nix the script lives in $out/bin, so rewrite that one shared
    # prefix to the installed template dir; no other $SCRIPT_DIR use matches it.
    substituteInPlace install.sh \
      --replace-fail 'cp "$SCRIPT_DIR/' "cp \"$templates/"

    install -Dm0755 install.sh "$out/bin/devc"

    # Ensure devc finds the devcontainer CLI, docker and its other helpers
    # regardless of the caller's PATH; and source the Claude OAuth token from
    # the login keychain so EVERY devc invocation (up/rebuild/shell, not just
    # the claude-fleet wrapper) forwards it into the container via localEnv.
    # Only set it when unset, so an explicit override still wins.
    wrapProgram "$out/bin/devc" \
      --prefix PATH : ${
        lib.makeBinPath [
          bash
          coreutils
          devcontainer
          docker
          jq
          git
        ]
      } \
      --run 'export CLAUDE_CODE_OAUTH_TOKEN="''${CLAUDE_CODE_OAUTH_TOKEN:-$(/usr/bin/security find-generic-password -a "$USER" -s claude-code-oauth -w 2>/dev/null)}"'

    runHook postInstall
  '';

  meta = {
    description = "Sandboxed devcontainer for running Claude Code with bypassed permissions";
    homepage = "https://github.com/trailofbits/claude-code-devcontainer";
    license = lib.licenses.asl20;
    mainProgram = "devc";
  };
}
