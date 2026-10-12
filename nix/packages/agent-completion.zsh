#compdef agent
# agent.nix substitutes the Claude profile names and the orgs root.

_agent_orgs() {
  local -a orgs
  orgs=(~/@ORGS_SUBDIR@/*(N/:t))
  _describe -t orgs org orgs
}

_agent() {
  local -a subcommands profiles
  profiles=(@PROFILES@)
  subcommands=(
    'fleet:shared container for a trusted org'
    'audit:isolated container for an untrusted repo'
    'trust:accept reviewed .git changes in an org'
    'ls:list agent containers'
    'stop:stop an org'"'"'s containers'
    'doctor:check the VM, host and signing setup'
  )
  if ((CURRENT == 2)); then
    _describe -t commands command subcommands
    return
  fi

  local subcommand="$words[2]"
  shift words
  ((CURRENT--))
  case "$subcommand" in
    fleet)
      _arguments \
        '--rebuild[rebuild the container first]' \
        '(-p --profile)--alt[use the alt Claude profile]' \
        '(--alt -p --profile)'{-p,--profile}"[Claude profile]:profile:($profiles)" \
        '1:org:_agent_orgs' \
        '*::command:_normal'
      ;;
    trust) _arguments '1:org:_agent_orgs' ;;
    stop) _arguments '(1)--all[stop every agent container]' '1:org:_agent_orgs' ;;
    audit) _arguments '1:repository:_files -/' '*::command:_normal' ;;
  esac
}

_agent "$@"
