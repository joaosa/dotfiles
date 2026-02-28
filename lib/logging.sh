#!/usr/bin/env bash
# Common logging functions for bootstrap scripts

# Colors (disabled per https://no-color.org/ or when not a terminal)
if [ -n "${NO_COLOR+set}" ] || ! [ -t 1 ]; then
  RED='' GREEN='' YELLOW='' BLUE='' CYAN='' RESET=''
else
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  BLUE='\033[0;34m'
  CYAN='\033[0;36m'
  RESET='\033[0m'
fi

# Tracking variables (can be reset by sourcing script)
START_TIME="${START_TIME:-$(date +%s)}"
ITEMS_INSTALLED="${ITEMS_INSTALLED:-0}"
ITEMS_SKIPPED="${ITEMS_SKIPPED:-0}"
ITEMS_WARNED="${ITEMS_WARNED:-0}"
ITEMS_FAILED="${ITEMS_FAILED:-0}"

reset_counters() {
  START_TIME=$(date +%s)
  ITEMS_INSTALLED=0
  ITEMS_SKIPPED=0
  ITEMS_WARNED=0
  ITEMS_FAILED=0
}

log_info() {
  echo -e "${BLUE}i${RESET}  $*"
}

log_success() {
  echo -e "${GREEN}✓${RESET}  $*"
  ((ITEMS_INSTALLED++)) || true
}

log_skip() {
  echo -e "${YELLOW}⊘${RESET}  $*"
  ((ITEMS_SKIPPED++)) || true
}

log_warn() {
  echo -e "${YELLOW}!${RESET}  $*"
  ((ITEMS_WARNED++)) || true
}

log_error() {
  echo -e "${RED}x${RESET}  $*" >&2
  ((ITEMS_FAILED++)) || true
}

# Error/warning detail line (indented, no counter increment)
log_detail() {
  echo -e "   $*" >&2
}

die() {
  log_error "$@"
  exit 1
}

log_section() {
  local current="$1"
  local total="$2"
  local name="$3"
  echo ""
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "${CYAN}[$current/$total] $name${RESET}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

log_skip_grouped() {
  local message="$1"
  shift
  local items=("$@")
  local count="${#items[@]}"

  if [ "$count" -eq 0 ]; then
    return
  fi

  echo -e "${YELLOW}⊘${RESET}  $message: ${items[*]}"
  ((ITEMS_SKIPPED += count)) || true
}

# ============================================================================
# SUMMARY
# ============================================================================

print_summary() {
  local doctor_mode=false
  [ "${1:-}" = "--doctor" ] && doctor_mode=true

  echo ""
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

  if [ "$doctor_mode" = false ]; then
    local header
    if [ "$ITEMS_FAILED" -gt 0 ]; then
      header="${RED}Setup finished with errors${RESET}"
    else
      header="${GREEN}Setup complete${RESET}"
    fi
    echo -e "$header"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    echo -e "${GREEN}✓${RESET} Installed: $ITEMS_INSTALLED"
    echo -e "${YELLOW}⊘${RESET} Skipped:   $ITEMS_SKIPPED"
    [ "$ITEMS_WARNED" -gt 0 ] && echo -e "${YELLOW}!${RESET} Warnings:  $ITEMS_WARNED"
    [ "$ITEMS_FAILED" -gt 0 ] && echo -e "${RED}✗${RESET} Failed:    $ITEMS_FAILED"
    echo ""

    local end_time
    end_time=$(date +%s)
    local elapsed=$((end_time - START_TIME))
    local minutes=$((elapsed / 60))
    local seconds=$((elapsed % 60))
    echo -e "   Total time: ${minutes}m ${seconds}s"
  else
    echo -e "${GREEN}✓${RESET} Passed:   $ITEMS_INSTALLED"
    [ "$ITEMS_WARNED" -gt 0 ] && echo -e "${YELLOW}!${RESET} Warnings: $ITEMS_WARNED"
    [ "$ITEMS_FAILED" -gt 0 ] && echo -e "${RED}✗${RESET} Failed:   $ITEMS_FAILED"
  fi

  echo ""
}
