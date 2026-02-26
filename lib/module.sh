#!/usr/bin/env bash
# Module runner framework for bootstrap

# List all available module names (derived from numbered filenames)
list_modules() {
  local modules_dir="$SCRIPT_DIR/modules"
  for f in "$modules_dir"/[0-9][0-9]-*.sh; do
    [ -f "$f" ] || continue
    local name
    name=$(basename "$f")
    name="${name#[0-9][0-9]-}"
    name="${name%.sh}"
    echo "$name"
  done
}

# Resolve a module name to its file path.
# Matches by: exact name, or numeric-prefix (e.g. "homebrew" -> "01-homebrew.sh")
_resolve_module() {
  local name="$1"
  local modules_dir="$SCRIPT_DIR/modules"

  # Try exact match first
  [ -f "$modules_dir/$name.sh" ] && echo "$modules_dir/$name.sh" && return 0

  # Try numbered prefix match (NN-name.sh) via glob
  local match
  for match in "$modules_dir"/[0-9][0-9]-"${name}".sh; do
    [ -f "$match" ] && echo "$match" && return 0
  done

  return 1
}

# Run a single module by name in a subshell (isolates run() definitions)
run_module() {
  local name="$1"
  local current="$2"
  local total="$3"

  local module_file
  if ! module_file=$(_resolve_module "$name"); then
    log_error "Unknown module: $name"
    log_info "Available modules: $(list_modules | tr '\n' ' ')"
    return 1
  fi

  log_section "$current" "$total" "$(echo "$name" | tr '[:lower:]' '[:upper:]')"

  # Run in subshell so each module's run() doesn't clobber the previous.
  # Counters are written via EXIT trap to survive failures mid-module.
  # Subshell resets counters to 0; parent adds the delta.
  local counter_file
  counter_file=$(mktemp)

  # shellcheck disable=SC2030  # Subshell modifications are intentional; counters propagated via temp file
  (
    ITEMS_INSTALLED=0
    ITEMS_SKIPPED=0
    ITEMS_WARNED=0
    ITEMS_FAILED=0
    trap 'echo "$ITEMS_INSTALLED $ITEMS_SKIPPED $ITEMS_WARNED $ITEMS_FAILED" > "'"$counter_file"'"' EXIT
    source "$module_file"
    run
  )
  local exit_code=$?

  # Add subshell's counters to parent's running total
  if [ -s "$counter_file" ]; then
    local di ds dw df
    read -r di ds dw df < "$counter_file"
    (( ITEMS_INSTALLED += di )) || true
    (( ITEMS_SKIPPED += ds )) || true
    (( ITEMS_WARNED += dw )) || true
    (( ITEMS_FAILED += df )) || true
  fi
  rm -f "$counter_file"

  return "$exit_code"
}

# Build MODULE_ORDER from filesystem (must be after list_modules is defined)
MODULE_ORDER=()
while IFS= read -r _mod_name; do
  MODULE_ORDER+=("$_mod_name")
done < <(list_modules)
unset _mod_name
