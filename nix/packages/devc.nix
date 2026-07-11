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
  python3,
}:

# Trail of Bits' `devc` CLI, paired with repo-owned Claude Code + Codex
# templates. Upstream ships a self-installing checkout; this derivation pins the
# CLI, installs the audited templates into the store, and makes `make switch`
# the only install/update path.
stdenvNoCC.mkDerivation {
  pname = "agent-devcontainer";
  version = "0-unstable-2026-07-10";

  src = fetchFromGitHub {
    owner = "trailofbits";
    repo = "claude-code-devcontainer";
    rev = "6750a78849dcb6f1477c5162a6d2185afcdbefd7";
    hash = "sha256-rGNvisG4YnyWY6X+hjEEVJ+cazzJ2PZWxpeNFjX6EvM=";
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    templates="$out/share/agent-devcontainer"
    install -Dm0644 ${../../config/agent-devcontainer/Dockerfile} "$templates/Dockerfile"
    install -Dm0644 ${../../config/agent-devcontainer/.zshrc} "$templates/.zshrc"
    install -Dm0644 ${../../config/agent-devcontainer/post_install.py} "$templates/post_install.py"
    install -Dm0644 ${../../config/agent-devcontainer/init-firewall.sh} "$templates/init-firewall.sh"
    install -Dm0644 ${../../config/agent-devcontainer/apply-firewall.sh} "$templates/apply-firewall.sh"
    install -Dm0644 ${../../config/agent-devcontainer/post-start.sh} "$templates/post-start.sh"
    install -Dm0644 ${../../config/agent-devcontainer/sudoers-agent} "$templates/sudoers-agent"
    install -Dm0644 ${../../config/agent-devcontainer/default.devcontainer.json} "$templates/devcontainer.json"
    install -Dm0644 ${../../config/agent-devcontainer/audit.devcontainer.json} "$templates/audit.devcontainer.json"
    install -Dm0644 ${../../config/agent-devcontainer/fleet.devcontainer.json} "$templates/fleet.devcontainer.json"

    mkdir -p "$out/libexec"
    substitute ${./devc-audit-slug.py} "$out/libexec/devc-audit-slug" \
      --replace-fail '#!/usr/bin/env python3' '#!${python3}/bin/python3'
    chmod 0755 "$out/libexec/devc-audit-slug"

    # Add the two repo-owned runtime helpers to upstream's template copier, then
    # rewrite all template lookups from the script directory to the store.
    substituteInPlace install.sh \
      --replace-fail \
        'cp "$SCRIPT_DIR/.zshrc" "$devcontainer_dir/"' \
        'cp "$SCRIPT_DIR/.zshrc" "$devcontainer_dir/"
    cp "$SCRIPT_DIR/init-firewall.sh" "$devcontainer_dir/"
    cp "$SCRIPT_DIR/post-start.sh" "$devcontainer_dir/"'
    substituteInPlace install.sh \
      --replace-fail 'cp "$SCRIPT_DIR/' "cp \"$templates/"

    install -Dm0755 install.sh "$out/bin/devc"

    # Ensure devc finds all helpers regardless of the caller's PATH. Credentials
    # are deliberately not injected here: only the trusted fleet wrapper reads
    # the Claude token, while audit containers receive no host AI credentials.
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
      }

    runHook postInstall
  '';

  meta = {
    description = "Hardened devcontainers for Claude Code and Codex";
    homepage = "https://github.com/trailofbits/claude-code-devcontainer";
    license = lib.licenses.asl20;
    mainProgram = "devc";
  };
}
