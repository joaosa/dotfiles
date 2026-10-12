{
  lib,
  writeShellApplication,
  coreutils,
  devc,
  dotfilesPath,
  # Claude profile name -> keychain service holding its OAuth token.
  profiles,
  defaultProfile,
}:

# `agent`: single entry point for the Claude Code + Codex devcontainers.
# Only pure helpers go in runtimeInputs; host tools come from the caller's PATH.
writeShellApplication {
  name = "agent";
  runtimeInputs = [ coreutils ];
  text = ''
    AGENT_DEVC=${devc}
    AGENT_DOTFILES=${lib.escapeShellArg dotfilesPath}
    AGENT_DEFAULT_PROFILE=${lib.escapeShellArg defaultProfile}
    AGENT_TEMPLATE_FILES=(${lib.escapeShellArgs devc.templateFiles})
    declare -A AGENT_PROFILES=(${
      lib.concatStringsSep " " (
        lib.mapAttrsToList (name: service: "[${name}]=${lib.escapeShellArg service}") profiles
      )
    })
  ''
  + builtins.readFile ./agent.sh;
}
