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
  reset_counters
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
# STOW PACKAGE DISCOVERY
# ============================================================================

# Print one stow package name per line, skipping hidden directories.
discover_stow_packages() {
  local stow_dir="$SCRIPT_DIR/stow"
  local name
  for d in "$stow_dir"/*/; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    [[ "$name" == .* ]] && continue
    echo "$name"
  done
}

# ============================================================================
# PACKAGE NAME PARSING
# ============================================================================

# Extract binary name from a Go install path: github.com/user/repo/cmd/tool@v1.0 -> tool
go_binary_name() {
  local pkg="$1"
  local name="${pkg##*/}"
  echo "${name%%@*}"
}

# Extract package name from an npm specifier: @scope/name@version -> @scope/name, name@version -> name
npm_package_name() {
  local pkg="$1"
  if [[ "$pkg" == @*/*@* ]]; then
    echo "${pkg%@*}"
  else
    echo "${pkg%%@*}"
  fi
}

# Extract version from an npm specifier: @scope/name@version -> version, name@version -> version
npm_package_version() {
  local pkg="$1"
  echo "${pkg##*@}"
}

# Check if an npm package specifier (name or name@version) is globally installed.
is_npm_pkg_installed() {
  npm list -g "$1" --depth=0 >/dev/null 2>&1
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
        binary_name=$(go_binary_name "$package")
        display_name="$binary_name"
        command -v "$binary_name" >/dev/null 2>&1 && is_installed=true
        ;;
      "nodejs")
        package_name=$(npm_package_name "$package")
        package_version=$(npm_package_version "$package")
        display_name="$package_name@$package_version"
        is_npm_pkg_installed "$package_name@$package_version" && is_installed=true
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

# Extract binary name from a cargo package spec (crate:binary or just crate)
cargo_bin_name() {
  local pkg="$1"
  if [[ "$pkg" == *:* ]]; then
    echo "${pkg#*:}"
  else
    echo "${pkg##*/}"
  fi
}

# Extract crate name from a cargo package spec (crate:binary or just crate)
cargo_crate_name() {
  local pkg="$1"
  echo "${pkg%%:*}"
}

install_cargo_packages() {
  local packages=("$@")
  local -a already_installed=()

  for pkg in "${packages[@]}"; do
    local bin_name crate_name
    bin_name=$(cargo_bin_name "$pkg")
    crate_name=$(cargo_crate_name "$pkg")

    if command -v "$bin_name" >/dev/null 2>&1; then
      already_installed+=("$crate_name")
      continue
    fi

    if is_dry_run "install cargo package: $crate_name"; then continue; fi

    local cargo_exit=0
    # openpgp-card-tool-git requires explicit framework linking on macOS
    if is_macos && [ "$crate_name" = "openpgp-card-tool-git" ]; then
      RUSTFLAGS="-C link-arg=-framework -C link-arg=AppKit -C link-arg=-framework -C link-arg=CoreServices" \
        cargo install "$crate_name" || cargo_exit=$?
    else
      cargo install "$crate_name" || cargo_exit=$?
    fi

    if [ "$cargo_exit" -eq 0 ]; then
      log_success "Installed $crate_name"
    else
      log_error "Failed to install $crate_name (exit code: $cargo_exit)"
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
