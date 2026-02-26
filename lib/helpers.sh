#!/usr/bin/env bash
# Shared helper functions for bootstrap modules

# ============================================================================
# PLATFORM DETECTION
# ============================================================================

OS="$(uname -s | tr '[:upper:]' '[:lower:]')"

is_macos() { [ "$OS" = "darwin" ]; }
is_linux() { [ "$OS" = "linux" ]; }

sha256sum_portable() {
  if is_macos; then shasum -a 256 "$@"; else sha256sum "$@"; fi
}

sed_inplace() {
  if is_macos; then sed -i '' "$@"; else sed -i "$@"; fi
}

# ============================================================================
# DRY RUN
# ============================================================================

# Check if dry run mode is active. If so, log and return 0 (true).
# Usage: if is_dry_run "install Prezto"; then return; fi
is_dry_run() {
  if [ "$DRY_RUN" = "true" ]; then
    [ $# -gt 0 ] && log_info "[DRY RUN] Would $1"
    return 0
  fi
  return 1
}

# ============================================================================
# CLEANUP TRAP
# ============================================================================

_TEMP_FILES=()

register_temp_file() { _TEMP_FILES+=("$1"); }

_cleanup_temp_files() {
  for f in "${_TEMP_FILES[@]+"${_TEMP_FILES[@]}"}"; do rm -f "$f" 2>/dev/null; done
}

trap _cleanup_temp_files EXIT INT TERM

# ============================================================================
# MODULE INIT
# ============================================================================

# Call from standalone module execution to set up the environment.
# Usage (at top of module): init_standalone
init_standalone() {
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")/.." && pwd)"
  DRY_RUN="${DRY_RUN:-false}"
  source "$SCRIPT_DIR/lib/logging.sh"
  # helpers.sh is already sourced (we're in it)
  source "$SCRIPT_DIR/versions.env"
  START_TIME=$(date +%s)
  ITEMS_INSTALLED=0
  ITEMS_SKIPPED=0
  ITEMS_WARNED=0
  ITEMS_FAILED=0
}

# ============================================================================
# VERSION MANAGEMENT
# ============================================================================

get_tool_version() {
  local tool="$1"
  local tool_versions_file="$SCRIPT_DIR/.tool-versions"
  if [ -f "$tool_versions_file" ]; then
    grep "^${tool} " "$tool_versions_file" | awk '{print $2}'
  else
    echo ""
  fi
}

# ============================================================================
# ASDF MANAGEMENT
# ============================================================================

install_asdf_language() {
  local language="$1"
  local repo="$2"
  local version="${3:-$(get_tool_version "$language")}"
  local skipped=false

  if [ -z "$version" ]; then
    log_error "No version found for $language"
    return 1
  fi

  if ! asdf plugin list 2>/dev/null | grep -qxF "$language"; then
    if is_dry_run "add asdf plugin: $language"; then return 0; fi
    log_info "Adding asdf plugin: $language"
    if ! asdf plugin add "$language" "$repo"; then
      log_error "Failed to add asdf plugin: $language"
      return 1
    fi
    log_success "Added asdf plugin: $language"
  else
    skipped=true
  fi

  if ! asdf list "$language" 2>/dev/null | grep -qF " $version"; then
    if is_dry_run "install $language $version"; then return 0; fi
    log_info "Installing $language $version..."
    if ! asdf install "$language" "$version"; then
      log_error "Failed to install $language $version"
      return 1
    fi
    log_success "Installed $language $version"
  else
    if [ "$skipped" = true ]; then
      log_skip "$language $version (plugin and version already installed)"
    else
      log_skip "$language $version already installed"
    fi
  fi

  is_dry_run || asdf reshim "$language"
}

install_asdf_packages() {
  local language="$1"
  shift
  local packages=("$@")
  local -a already_installed=()
  local installed_count=0

  for package in "${packages[@]}"; do
    local binary_name="" package_name="" package_version="" display_name=""
    local is_installed=false

    case "$language" in
      "golang")
        # github.com/user/repo/cmd/tool@v1.0 -> tool
        binary_name="${package##*/}"
        binary_name="${binary_name%%@*}"
        display_name="$binary_name"
        command -v "$binary_name" >/dev/null 2>&1 && is_installed=true
        ;;
      "nodejs")
        # Handle scoped packages: @scope/name@version vs name@version
        if [[ "$package" == @*/*@* ]]; then
          package_name="${package%@*}"
          package_version="${package##*@}"
        else
          package_name="${package%%@*}"
          package_version="${package#*@}"
        fi
        display_name="$package_name@$package_version"
        npm list -g "$package_name@$package_version" --depth=0 >/dev/null 2>&1 && is_installed=true
        ;;
      *)
        log_error "Unsupported language: $language"
        return 1
        ;;
    esac

    if [ "$is_installed" = true ]; then
      already_installed+=("$display_name")
    elif is_dry_run "install $language package: $display_name"; then
      continue
    else
      log_info "Installing $language package: $package"
      case "$language" in
        "golang")
          if ! go install "$package"; then
            log_error "Failed to install Go package: $display_name"
            continue
          fi
          ;;
        "nodejs")
          if ! npm install -g "$package"; then
            log_error "Failed to install npm package: $display_name"
            continue
          fi
          ;;
      esac
      log_success "Installed $language package: $display_name"
      ((installed_count++)) || true
    fi
  done

  log_skip_grouped "$language packages already installed" "${already_installed[@]+"${already_installed[@]}"}"

  if ! is_dry_run && [ "$installed_count" -gt 0 ]; then
    asdf reshim "$language"
  fi
}

# ============================================================================
# CARGO
# ============================================================================

# Map cargo crate names to their binary names (where they differ)
cargo_bin_name() {
  local pkg="$1"
  case "$pkg" in
    openpgp-card-tools) echo "oct" ;;
    openpgp-card-tool-git) echo "oct-git" ;;
    *) echo "${pkg##*/}" ;;
  esac
}

install_cargo_packages() {
  local packages=("$@")
  local -a already_installed=()

  for pkg in "${packages[@]}"; do
    local bin_name
    bin_name=$(cargo_bin_name "$pkg")

    if command -v "$bin_name" >/dev/null 2>&1; then
      already_installed+=("$pkg")
      continue
    fi

    if is_dry_run "install cargo package: $pkg"; then continue; fi

    local cargo_exit=0
    # openpgp-card-tool-git requires explicit framework linking on macOS
    if is_macos && [ "$pkg" = "openpgp-card-tool-git" ]; then
      RUSTFLAGS="-C link-arg=-framework -C link-arg=AppKit -C link-arg=-framework -C link-arg=CoreServices" \
        cargo install "$pkg" || cargo_exit=$?
    else
      cargo install "$pkg" || cargo_exit=$?
    fi

    if [ "$cargo_exit" -eq 0 ]; then
      log_success "Installed $pkg"
    else
      log_error "Failed to install $pkg (exit code: $cargo_exit)"
    fi
  done

  log_skip_grouped "Cargo packages already installed" "${already_installed[@]+"${already_installed[@]}"}"
}

# ============================================================================
# HOMEBREW
# ============================================================================

pin_brew_packages() {
  local pinned_packages
  pinned_packages=$(brew list --pinned)
  local -a already_pinned=()

  for package in $(brew list --formula); do
    if ! echo "$pinned_packages" | grep -qxF "$package"; then
      if ! brew pin "$package" 2>/dev/null; then
        log_error "Failed to pin: $package"
      else
        log_success "Pinned: $package"
      fi
    else
      already_pinned+=("$package")
    fi
  done

  log_skip_grouped "Already pinned" "${already_pinned[@]+"${already_pinned[@]}"}"
}

# ============================================================================
# DOWNLOADS
# ============================================================================

download_if_missing() {
  local file_path="$1"
  local url="$2"
  local expected_sha256="$3"
  local filename
  filename=$(basename "$file_path")

  if [ -f "$file_path" ]; then
    if [ -n "$expected_sha256" ]; then
      local actual_sha256
      actual_sha256=$(sha256sum_portable "$file_path" | awk '{print $1}')
      if [ "$actual_sha256" = "$expected_sha256" ]; then
        log_skip "$filename (checksum verified)"
        return 0
      else
        if is_dry_run "re-download $filename (checksum mismatch)"; then return 0; fi
        log_warn "Existing file has incorrect checksum, re-downloading..."
        rm -f "$file_path"
      fi
    else
      log_skip "$filename (already exists)"
      return 0
    fi
  fi

  if is_dry_run "download $filename"; then return 0; fi

  log_info "Downloading: $filename"
  mkdir -p "$(dirname "$file_path")"
  local temp_file="${file_path}.tmp"
  register_temp_file "$temp_file"

  if ! curl -fsSL -m 120 -o "$temp_file" "$url"; then
    rm -f "$temp_file"
    log_error "Failed to download $filename"
    return 1
  fi

  if [ -n "$expected_sha256" ]; then
    local actual_sha256
    actual_sha256=$(sha256sum_portable "$temp_file" | awk '{print $1}')
    if [ "$actual_sha256" != "$expected_sha256" ]; then
      rm -f "$temp_file"
      log_error "Checksum verification failed for $filename"
      log_detail "Expected: $expected_sha256"
      log_detail "Got:      $actual_sha256"
      return 1
    fi
  fi

  mv "$temp_file" "$file_path"
  log_success "Downloaded: $filename"
}

# ============================================================================
# SUMMARY
# ============================================================================

print_summary() {
  local end_time
  end_time=$(date +%s)
  local elapsed=$((end_time - START_TIME))
  local minutes=$((elapsed / 60))
  local seconds=$((elapsed % 60))

  local header
  if [ "$ITEMS_FAILED" -gt 0 ]; then
    header="${RED}Setup finished with errors${RESET}"
  else
    header="${GREEN}Setup complete${RESET}"
  fi

  echo ""
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "$header"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo ""
  echo -e "${GREEN}✓${RESET} Installed: $ITEMS_INSTALLED"
  echo -e "${YELLOW}⊘${RESET} Skipped:   $ITEMS_SKIPPED"
  [ "$ITEMS_WARNED" -gt 0 ] && echo -e "${YELLOW}!${RESET} Warnings:  $ITEMS_WARNED"
  [ "$ITEMS_FAILED" -gt 0 ] && echo -e "${RED}✗${RESET} Failed:    $ITEMS_FAILED"
  echo ""
  echo -e "   Total time: ${minutes}m ${seconds}s"
  echo ""
}
