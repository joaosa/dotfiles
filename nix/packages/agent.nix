{
  lib,
  writeShellApplication,
  writeTextDir,
  symlinkJoin,
  coreutils,
  gawk,
  gnugrep,
  gnused,
  jq,
  devc,
  dotfilesPath,
  # Claude profile name -> keychain service holding its OAuth token.
  profiles,
  defaultProfile,
}:

# `agent`: single entry point for the Claude Code + Codex devcontainers.
# Only pure helpers go in runtimeInputs; host tools come from the caller's PATH.
let
  script = writeShellApplication {
    name = "agent";
    runtimeInputs = [
      coreutils
      gawk
      gnugrep
      gnused
      jq
    ];
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
  };
  completion = writeTextDir "share/zsh/site-functions/_agent" (
    lib.replaceStrings [ "@PROFILES@" ] [ (lib.concatStringsSep " " (lib.attrNames profiles)) ] (
      builtins.readFile ./agent-completion.zsh
    )
  );
in
symlinkJoin {
  name = "agent";
  paths = [
    script
    completion
  ];
  meta.mainProgram = "agent";
}
