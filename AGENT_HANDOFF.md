# Agent experience handoff

Updated: 2026-11-18. Read the current AGENTS.md and inspect the working tree
before continuing; this note records task state, not additional authorization.

## User intent and current state

The user asked to improve their agent experience across all three areas:
less friction and reliable completion, faster startup and easier sessions,
and better shared instructions and skills. The first pass is implemented and
locally verified. They then asked whether anything else could help and requested
this handoff. On resuming with "Read AGENT_HANDOFF.md and continue", the agent
proceeded with local command-specific help and dependency diagnostics as the
stated default follow-up. That follow-up is also implemented and locally verified.

The user then explicitly requested all five proposed follow-ups: startup profiling,
failure handling, versioned guidance, skill cleanup, and full verification. They
also requested roborev awareness. Those local changes are implemented and verified;
see the continuation details below. No additional feature is selected.

The user requested commits. Created four signed local commits:

- `c470592` — launcher/startup/session diagnostics (484 changed lines).
- `9fd6090` — versioned shared guidance and skill policy (264 changed lines).
- `38dd558` — workflow documentation, web permissions and repository notes.
- `215710c` — remove direnv and its Zsh integration (6 deleted lines).

All passed gitleaks, nixfmt, statix and deadnix commit hooks. Temporary per-command
hook wrappers preserved validation and omitted only the outbound roborev post-commit
hook; no review was queued. The repository's normal hook configuration is unchanged.
No pushes, PRs, system-wide activation, or real container launches were made.
Shared guidance was edited live in the earlier session; its new repository-managed
link still awaits authorized activation. The later skill exclusions below were
explicitly requested and applied directly to the host Codex config.

## Latest continuation: direnv and skill exclusions

- Direnv removal is committed in `215710c`, but has not been activated. The live
  Zsh configuration still has its direnv hook. The user's `TYPESAFE_API_KEY` is
  stored in `~/.envrc`; its value was not printed or copied into the repository.
  After removal is activated, `source ~/.envrc` loads it manually. No replacement
  automatic secret loader was requested or added.
- Audited explicit skill invocations and tool-call path references across 2,545
  local Claude/Codex log files. Missing records are only a shortlist signal, not
  proof of no use. Aggregate report: `/private/tmp/dotfiles-skill-usage-20261118.json`.
- The user explicitly selected `docx`, `morning`, `setup-writing-style`, `pptx`,
  `xlsx`, `pdf`, and all Work Pets, Pages and Sites skills for disabling. Pages
  includes `manage-schedules`. Applied 15 new exclusions to `~/.codex/config.toml`;
  all 29 installed policy matches, including the 14 previous exclusions, were
  verified disabled. Existing entries, unrelated settings and file permissions
  were preserved; a second merge made no changes.
- Restart Codex to load the exclusions; restart was not performed. This change
  affects host Codex only. Claude discovery and container settings were not
  changed, plugins were not uninstalled, and synced skill files remain intact.
- Updated `config/agents/codex-skill-exclusions.json` from a flat path list to
  `shared` and `plugins` pattern lists. The merge helper discovers matching sync
  bundles and cached plugin versions when run, preserving per-path re-enables.
  New versions installed later require another merge or authorized activation.
- A later Claude session, asked to match Codex, added `skillOverrides` to
  `claudeSharedSettings` in `nix/home/common.nix`, turning off the six user-selected
  synced skills (`docx`, `morning`, `pdf`, `pptx`, `setup-writing-style`, `xlsx`)
  by their `anthropic-skills:` names. It takes effect on activation only; live
  profile settings were not edited. Nix formatting, statix and deadnix passed;
  full `make check` was not rerun and the override is unconfirmed in a live session
  (check `/skills` after activation). `skill-creator` stays enabled in Claude.
- The user then requested a commit: the five implementation files and this note
  were committed together, with the outbound roborev post-commit hook omitted.
- Live config recovery copy: `config.toml.before` in the temporary directory
  `codex-skill-exclusions-gkkg_nsy` under macOS `$TMPDIR`; temporary files may expire.

Verification for this continuation passed full offline `make check` (system
build, flake checks and formatting), focused merge tests, live config preservation
and idempotence checks, and `git diff --check`. Tests cover overlapping patterns,
unrelated plugins, new plugin versions and invalid paths. An initial test mismatch
between macOS `/var` and `/private/var` was fixed by resolving the fixture root.
The full check command was:

```sh
make check NIX='/nix/var/nix/profiles/default/bin/nix --extra-experimental-features "nix-command flakes" --offline --option builders "" --option post-build-hook ""'
```

The requested changes are implemented and verified. No further feature is selected.
Do not commit, activate the system, or start a fresh roborev review merely because
this handoff is resumed; those actions still need their applicable authorization.

## Completed changes

- `nix/packages/agent.sh`: fleet commands and shells now retain the caller's
  repository/subdirectory within the selected organization, mapped to
  `/workspace/...`. Launches from outside that org still start at its root.
  Arguments are passed separately through a small `sh -c` wrapper, preserving
  spaces, shell metacharacters, empty arguments, and command exit status.
- Added `agent --help`, `agent -h`, and `agent help`, with examples including
  Claude and Codex session resumption. Help runs without VM/keychain access.
  Command-specific help is available as `agent help <command>`,
  `agent <command> --help`, or `agent <command> -h` (the flag must stand alone).
  Added the `help` subcommand and its command topics to Zsh completion.
- Launch preflight now checks for devcontainer, colima and docker, plus ssh-add
  for fleet, before starting the VM or loading signing keys. Missing commands
  get an explicit PATH/install error. `ls` and `stop` also check for docker;
  `doctor` reports the additional host tools. Help needs none of these tools.
- `config/agent-devcontainer/post-start.sh`: failed/interrupted agent updates
  have a 15-minute retry cooldown using `$HOME/.agent-update-attempt`.
  Successful updates retain the existing daily interval; audit stays pinned.
  Stamps remain container-local. The first update attempt can still block.
- `nix/packages/agent-test.sh`: added argument-boundary, directory selection,
  wrapper execution/exit-status, side-effect-free help, and update-cooldown
  tests. Follow-up tests cover every command's help, missing dependencies with
  a restricted PATH, and forwarding agent help flags after `--`. Updater commands
  are stubbed; tests do not log in or contact registries.
- `flake.nix`: the agent check now also lints/tests post-start.sh and supplies
  jq to the test environment. Test script now takes the launcher and post-start
  script as its two arguments.
- `README.md`: documented retained directory context, help, resuming sessions,
  separate host/container histories, update retry cooldown, command-specific
  help and early dependency errors.
- `~/.claude-shared/CLAUDE.md`: appended task-execution and skills/continuity
  guidance covering routine decisions, fewer redundant reads/checks, completion,
  focused skill selection, and session handoffs. Original outbound-data and PR
  rules remain intact. Both `~/.codex/AGENTS.md` and `~/.claude/CLAUDE.md` were
  verified to resolve to the updated content. Individual skills and Codex
  settings were not changed.

## Completed continuation

- `agent.sh`: Docker listing/stop failures now return errors instead of looking
  like empty results. Launches verify Docker connectivity before credentials.
  Doctor continues after failed mount queries and never treats SSH transport
  failure as proof that the host SSH directory is hidden.
- Startup uses `colima list --json`, selecting the default VM explicitly. The
  old doctor logic incorrectly combined the statuses of multiple Colima profiles.
  Five interleaved local samples measured median `status` at 730.5 ms and
  `list --json` at 275.7 ms; these are probe times, not complete launch times.
- Added `agent fleet --no-update` for one launch, preserving authentication and
  cooldown stamps. `AGENT_TIMING=1` prints fixed-label phase timings on the host
  and in the fleet startup hook. No command arguments or credentials are logged.
- `config/agents/CLAUDE.md` starts with the live shared guidance verbatim, then
  adds roborev instructions: inspect relevant existing local jobs, match revisions,
  validate findings, avoid recursive reviews, and respect outbound approval for
  fresh reviews and automatic commit hooks. Checked examples against installed
  roborev help. Existing local job 76 concerns Go-tool pinning, outside this task;
  it remains open. No review was enqueued and no job record was changed.
- Home Manager now manages `~/.claude-shared/CLAUDE.md` as a link to the repository
  source; its normal `.hm-backup` migration preserves the old real file. Both
  container profiles bind the repository file directly because the old shared-file
  path was outside the VM's mounts. Existing client links and skills remain.
- Audited synced skill duplicates: existing host Codex exclusions already retain
  one copy of each duplicated skill and prefer the built-in skill creator. Saved
  those 14 existing choices as relative paths in `codex-skill-exclusions.json`.
  `merge-codex-skills.py` applies missing installed-path exclusions at activation,
  preserving comments, unrelated settings, explicit re-enables and file mode.
  It uses host Python + tomlkit; it adds no Python dependency to the container.
- Added the `agent-settings` flake check and regression coverage for locale-safe
  timing, multiple VMs, failed Docker/SSH operations, skipped updates retaining
  authentication, config preservation, idempotence and invalid TOML.
- README and completion document the new behavior. No synced skill was removed.

## Preserve pre-existing work

At task start, these changes already existed:

- `nix/home/common.nix`: removed blanket Claude WebFetch/WebSearch prompts while
  retaining the shared outbound-data approval rule.
- `nix/home/darwin.nix`: originally had an added media-ps5 launch agent. The user
  subsequently explicitly requested its removal: reverted that uncommitted block,
  unloaded the running `org.nix-community.home.media-ps5` LaunchAgent, and moved
  its plist out of `~/Library/LaunchAgents`. That source file now matches HEAD.
  Recovery copy: `/private/tmp/agent-commit-jcoc5dnw/media-ps5.removed.plist`.
- `README.md`: paragraphs about shared coding skills and public-web permissions
  immediately after the shared Claude/Codex configuration description.
- Originally untracked `AGENTS.md`: repository-specific instructions, included
  in the requested follow-up commit.

Do not revert or attribute the original changes to this task. The user's later
commit request includes the remaining settings and repository notes. This handoff
records the work and verification history; it does not grant new authorization.

## Verification completed

- `nix build --offline --no-link .#checks.aarch64-darwin.agent .#checks.aarch64-darwin.statix .#checks.aarch64-darwin.deadnix`
- `nix fmt --offline -- --fail-on-change`
- Bash syntax checks and ShellCheck for agent.sh, agent-test.sh, post-start.sh.
- Zsh syntax check for agent-completion.zsh; `git diff --check`.
- CLI resume examples checked against installed `codex resume --help` and
  `claude --help`; directory handling checked against installed devcontainer
  CLI help and repository mount configuration.

All final checks passed. An initial startup-test failure was caused by missing
jq in the Nix test environment; adding it fixed the failure. Initial sandboxed
Nix invocation could not access its cache database; offline checks succeeded
with approved access to the local cache/store.

For the help/dependency follow-up, reran the offline agent flake check with
`--option builders '' --option post-build-hook ''`, plus Bash/Zsh syntax,
ShellCheck, and `git diff --check`. The Nix cache again required filesystem
approval. No Nix source changed in this follow-up; previous formatting, statix
and deadnix results still apply.

The continuation passed full `make check`, including the macOS system build,
agent/agent-settings checks, statix, deadnix and Nix formatting. It ran from a
temporary snapshot containing the working tree and new files, without modifying
the real Git index. The snapshot is `/private/tmp/agent-experience-check-a3l5yxqb`.
Nix was invoked with `--offline --option builders '' --option post-build-hook ''`.
Bash/Zsh syntax, ShellCheck, JSON inspection and `git diff --check` also passed.
After committing and removing media-ps5, full offline `make check` passed again
directly in the real repository. Both commit signatures verified successfully.
Confirmed launchd no longer has the PS5 service and its login plist is absent.

The first new timer check caught a decimal-comma locale issue; stripping all
non-digits fixed it. An initial snapshot without a Git root made nixfmt-tree scan
the Nix store; it was stopped after reporting zero changed files. Initializing
Git only inside the snapshot fixed formatter discovery, and the full check passed.

Profiling read only local VM/Docker status. There were no existing agent containers.
Temporary reports are `/private/tmp/agent-startup-profile.json` and
`/private/tmp/agent-vm-probe-profile.json`. A separate controlled comparison used
one-second updater stubs: roughly 1325 ms cold, 13 ms cached, 66 ms skipped under
the concurrent build load. These are synthetic updater results, not service or
download benchmarks. No real agent or registry was invoked by that comparison.

Not run: complete live container startup/authentication, a new roborev review,
or `make switch`. Do not activate merely to verify these changes.

## Possible next improvements

All selected local work is complete. A real fleet launch would provide end-to-end
timings and integration evidence, but may build images, forward credentials and
authenticate with external services. Obtain the required per-action outbound
approval before doing that. System-wide activation remains a separate action.

If opening PRs later, split launcher changes from shared guidance/skill policy,
and keep pre-existing unrelated work separate; check each against its actual base.

## Boundaries and recovery

Outbound requests containing private content or identifying data require chat
approval for each action, including credentials, repository content, handles,
and home paths. No uploads were needed for this work. Keep PRs below 700 changed
lines and check against the actual base before opening one. Existing approvals
do not authorize new outbound actions.

The original shared guidance snapshot is at
`/private/tmp/agent-guidance.before.md`; the applied draft is at
`/private/tmp/agent-guidance.proposed.md`. These are temporary recovery aids and
may disappear. Read the live shared file before any further edit and preserve
later changes. Editing it requires filesystem access outside this repository.
The new canonical source is `config/agents/CLAUDE.md`; after activation, edit that
source rather than creating a separate live copy.
