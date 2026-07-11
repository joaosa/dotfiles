{
  lib,
  stdenvNoCC,
  python3,
}:

# Repo-owned Claude Code + Codex devcontainer templates, adapted from Trail of
# Bits' claude-code-devcontainer. Upstream's self-installing `devc` CLI is not
# shipped: its subcommands read a repo's own .devcontainer and escape the pin,
# and the agent-fleet/agent-audit wrappers use the templates directly. This
# derivation only stages the audited templates and helpers into the store and
# installs a guard as `devc`, making `make switch` the only install/update path.
stdenvNoCC.mkDerivation {
  pname = "agent-devcontainer";
  version = "0-unstable-2026-07-10";

  dontUnpack = true;

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

    # Deliberately do NOT ship upstream's install.sh as `devc`. Its up/./template
    # subcommands read a repository's own .devcontainer (executing its
    # initializeCommand on the host and honoring attacker-supplied mounts), and
    # its self-install/update paths escape this pin. The agent-fleet/agent-audit
    # wrappers never use it; they stage the audited templates and call the
    # devcontainer CLI directly. This guard replaces it so a stray `devc ...`
    # fails loudly instead of taking an unsafe path.
    install -Dm0755 ${./devc-guard.sh} "$out/bin/devc"

    runHook postInstall
  '';

  meta = {
    description = "Hardened devcontainers for Claude Code and Codex";
    homepage = "https://github.com/trailofbits/claude-code-devcontainer";
    license = lib.licenses.asl20;
    mainProgram = "devc";
  };
}
