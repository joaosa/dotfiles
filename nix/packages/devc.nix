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
let
  # Egress allowlists, substituted into the staged profile JSONs so the shared
  # base cannot drift between profiles. Once github.com is admitted the
  # firewall cannot stop credentialed exfiltration (an attacker-supplied PAT
  # pushes anywhere), so its guarantee is "no direct-to-attacker traffic";
  # every entry is then a utility-vs-surface call. Fleet carries the agents,
  # GitHub plus its read-only release CDNs, and the ecosystems actually in
  # use. No sentry.io anywhere: Sentry ingestion is attacker-readable storage
  # (any account can receive POSTed events) and the agents' crash telemetry
  # fails silently without it. No ghcr.io: there is no docker daemon inside
  # the container, so OCI pulls are niche — re-add on first real need.
  fleetDomains = [
    "api.openai.com"
    "auth.openai.com"
    "chatgpt.com"
    "api.anthropic.com"
    "claude.ai"
    "downloads.claude.ai"
    "github.com"
    "api.github.com"
    "codeload.github.com"
    "raw.githubusercontent.com"
    "objects.githubusercontent.com"
    "release-assets.githubusercontent.com"
    "registry.npmjs.org"
    "crates.io"
    "index.crates.io"
    "static.crates.io"
    "static.rust-lang.org"
    "proxy.golang.org"
    "sum.golang.org"
    # Serena (MCP) resolves its Python deps through uv at launch.
    "pypi.org"
    "files.pythonhosted.org"
    # Scryfall MTG API; bulk data and card images live on scryfall.io.
    "api.scryfall.com"
    "data.scryfall.io"
    "cards.scryfall.io"
  ];
  # Currently identical to fleet; a distinct name so the profiles can diverge
  # again without touching the substitutions below.
  auditDomains = fleetDomains;

  templateDir = ../../config/agent-devcontainer;
  templateFiles = [
    "Dockerfile"
    ".zshrc"
    "post_install.py"
    "init-firewall.sh"
    "apply-firewall.sh"
    "firewall-lockdown.sh"
    "post-start.sh"
    "entrypoint.sh"
  ];
in
stdenvNoCC.mkDerivation {
  pname = "agent-devcontainer";
  version = "0-unstable-2026-07-10";

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    templates="$out/share/agent-devcontainer"
    ${lib.concatMapStrings (file: ''
      install -Dm0644 ${templateDir + "/${file}"} "$templates/${file}"
    '') templateFiles}
    substitute ${templateDir + "/audit.devcontainer.json"} "$templates/audit.devcontainer.json" \
      --replace-fail '@AGENT_ALLOWED_DOMAINS@' '${lib.concatStringsSep " " auditDomains}'
    substitute ${templateDir + "/fleet.devcontainer.json"} "$templates/fleet.devcontainer.json" \
      --replace-fail '@AGENT_ALLOWED_DOMAINS@' '${lib.concatStringsSep " " fleetDomains}'
    chmod 0644 "$templates/audit.devcontainer.json" "$templates/fleet.devcontainer.json"

    mkdir -p "$out/libexec"
    ${lib.concatMapStrings
      (helper: ''
        substitute ${./. + "/${helper}.py"} "$out/libexec/${helper}" \
          --replace-fail '#!/usr/bin/env python3' '#!${python3}/bin/python3'
        chmod 0755 "$out/libexec/${helper}"
      '')
      [
        "devc-audit-slug"
        "devc-git-guard"
      ]
    }

    # Guard in place of upstream's `devc` (see header), so stray calls fail loudly.
    install -Dm0755 ${./devc-guard.sh} "$out/bin/devc"

    runHook postInstall
  '';

  passthru = { inherit templateFiles; };

  meta = {
    description = "Hardened devcontainers for Claude Code and Codex";
    homepage = "https://github.com/trailofbits/claude-code-devcontainer";
    license = lib.licenses.asl20;
    mainProgram = "devc";
  };
}
