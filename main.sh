#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# DRY_RUN mode: Set to "true" to preview changes without executing them
DRY_RUN="${DRY_RUN:-false}"

if [ "$DRY_RUN" = "true" ]; then
  echo "=== DRY RUN MODE ==="
  echo "No changes will be made to the system."
  echo "To execute for real, run: DRY_RUN=false $0"
  echo ""
fi

# ============================================================================
# LOGGING & PROGRESS TRACKING
# ============================================================================

# Source common logging functions
# shellcheck source=lib/logging.sh
source "$SCRIPT_DIR/lib/logging.sh"

# Reset tracking for this script
START_TIME=$(date +%s)
ITEMS_INSTALLED=0
ITEMS_SKIPPED=0
ITEMS_FAILED=0

# ============================================================================
# CONFIGURATION
# ============================================================================

GO_PACKAGES=(
  "github.com/x-motemen/gore/cmd/gore@v0.6.1"
  "github.com/cirocosta/asciinema-edit@v0.2.0"
)

NPM_PACKAGES=(
  "@anthropic-ai/claude-code@2.0.8"
)

# File downloads with integrity verification
# To regenerate checksums: curl -fsSL <URL> | shasum -a 256
KUBECTL_ALIASES_URL="https://raw.githubusercontent.com/ahmetb/kubectl-aliases/7549fa45bbde7499b927c74cae13bfb9169c9497/.kubectl_aliases"
KUBECTL_ALIASES_SHA256="2aa6fa924d84663a17e797e566a8ae3512c94037c2d973203be177b720849ea9"

WHISPER_MODEL_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/80da2d8bfee42b0e836fc3a9890373e5defc00a6/ggml-base.en.bin"
WHISPER_MODEL_SHA256="a03779c86df3323075f5e796cb2ce5029f00ec8869eee3fdfb897afe36c6d002"

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

# Get version from .tool-versions file
# Usage: get_tool_version "nodejs"
get_tool_version() {
  local tool="$1"
  local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local tool_versions_file="$script_dir/.tool-versions"

  if [ -f "$tool_versions_file" ]; then
    grep "^${tool} " "$tool_versions_file" | awk '{print $2}'
  else
    echo ""
  fi
}

# Install asdf language with version
# Usage: install_asdf_language "nodejs" "https://github.com/asdf-vm/asdf-nodejs.git"
install_asdf_language() {
  local language="$1"
  local repo="$2"
  local version="${3:-$(get_tool_version "$language")}"
  local skipped=false

  if [ -z "$version" ]; then
    log_error "No version found for $language"
    return 1
  fi

  # Add plugin if not present
  if ! asdf plugin list | grep -q "^${language}$"; then
    log_info "Adding asdf plugin: $language"
    asdf plugin add "$language" "$repo"
    log_success "Added asdf plugin: $language"
  else
    skipped=true
  fi

  # Install version if not present
  if ! asdf list "$language" 2>/dev/null | grep -q "$version"; then
    log_info "Installing $language $version..."
    asdf install "$language" "$version"
    log_success "Installed $language $version"
  else
    if [ "$skipped" = true ]; then
      # Both plugin and version already exist
      log_skip "$language $version (plugin and version already installed)"
    else
      # Only version already exists (we just added the plugin)
      log_skip "$language $version already installed"
    fi
  fi

  # Regenerate shims to handle asdf reinstall scenarios
  asdf reshim "$language"
}

# Install packages for asdf-managed languages
# Usage: install_asdf_packages "golang" "${GO_PACKAGES[@]}"
#        install_asdf_packages "nodejs" "${NPM_PACKAGES[@]}"
install_asdf_packages() {
  local language="$1"
  shift
  local packages=("$@")

  local -a already_installed=()
  local installed_count=0

  for package in "${packages[@]}"; do
    local binary_name=""
    local package_name=""
    local package_version=""
    local display_name=""
    local is_installed=false

    # Parse package info and check if installed (language-specific)
    case "$language" in
      "golang")
        binary_name=$(echo "$package" | awk -F'/' '{print $NF}' | awk -F'@' '{print $1}')
        display_name="$binary_name"

        if command -v "$binary_name" >/dev/null 2>&1; then
          is_installed=true
        fi
        ;;
      "nodejs")
        package_name=$(echo "$package" | awk -F'@' '{print $1}')
        package_version=$(echo "$package" | awk -F'@' '{print $2}')
        display_name="$package_name@$package_version"

        if npm list -g "$package_name@$package_version" --depth=0 >/dev/null 2>&1; then
          is_installed=true
        fi
        ;;
      *)
        log_error "Unsupported language: $language"
        return 1
        ;;
    esac

    # Install or skip
    if [ "$is_installed" = true ]; then
      already_installed+=("$display_name")
    else
      log_info "Installing $language package: $package"

      # Install package (language-specific)
      case "$language" in
        "golang")
          go install "$package"
          ;;
        "nodejs")
          npm install -g "$package"
          ;;
      esac

      log_success "Installed $language package: $display_name"
      ((installed_count++))
    fi
  done

  # Show grouped skip message
  log_skip_grouped "$language packages already installed" "${already_installed[@]}"

  # Regenerate shims if any packages were installed
  if [ "$installed_count" -gt 0 ]; then
    asdf reshim "$language"
  fi
}

# Pin all homebrew packages to prevent auto-updates
# Usage: pin_brew_packages
pin_brew_packages() {
  # Get list of already pinned packages once (not in loop for performance)
  local pinned_packages=$(brew list --pinned)
  local -a already_pinned=()

  # Pin all installed formulae
  for package in $(brew list --formula); do
    if ! echo "$pinned_packages" | grep -q "^${package}$"; then
      brew pin "$package" >/dev/null 2>&1
      log_success "Pinned: $package"
    else
      already_pinned+=("$package")
    fi
  done

  # Show grouped skip message
  log_skip_grouped "Already pinned" "${already_pinned[@]}"
}

# Download file if not exists with SHA256 checksum verification
# Usage: download_if_missing "path/to/file" "url" "expected_sha256"
download_if_missing() {
  local file_path="$1"
  local url="$2"
  local expected_sha256="$3"
  local filename=$(basename "$file_path")

  # If file exists and checksum matches, skip download
  if [ -f "$file_path" ]; then
    if [ -n "$expected_sha256" ]; then
      local actual_sha256=$(shasum -a 256 "$file_path" | awk '{print $1}')
      if [ "$actual_sha256" = "$expected_sha256" ]; then
        log_skip "$filename (checksum verified)"
        return 0
      else
        log_warn "Existing file has incorrect checksum, re-downloading..."
        [ "$DRY_RUN" = "false" ] && rm -f "$file_path"
      fi
    else
      log_skip "$filename (already exists)"
      return 0
    fi
  fi

  if [ "$DRY_RUN" = "true" ]; then
    log_info "[DRY RUN] Would download: $filename"
    return 0
  fi

  # Download file
  log_info "Downloading: $filename"
  mkdir -p "$(dirname "$file_path")"
  local temp_file="${file_path}.tmp"

  if ! curl -fsSL -o "$temp_file" "$url"; then
    rm -f "$temp_file"
    log_error "Failed to download $filename"
    return 1
  fi

  # Verify checksum if provided
  if [ -n "$expected_sha256" ]; then
    local actual_sha256=$(shasum -a 256 "$temp_file" | awk '{print $1}')
    if [ "$actual_sha256" != "$expected_sha256" ]; then
      rm -f "$temp_file"
      log_error "Checksum verification failed for $filename"
      log_error "Expected: $expected_sha256"
      log_error "Got:      $actual_sha256"
      return 1
    fi
  fi

  mv "$temp_file" "$file_path"
  log_success "Downloaded: $filename"
}

# ============================================================================
# INITIALIZATION
# ============================================================================

log_section "1" "5" "INITIALIZATION"

# homebrew
# Note: Homebrew's official installer uses curl | bash pattern. While not ideal from a
# security perspective, this is the official installation method. For enhanced security,
# you can download the script first, review it, then execute manually.
# See: https://github.com/Homebrew/install
if ! command -v brew >/dev/null 2>&1; then
  log_info "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Add to PATH (Apple Silicon uses /opt/homebrew, Intel uses /usr/local)
  export PATH="${PATH:+$PATH:}/opt/homebrew/bin:/usr/local/bin"
  log_success "Installed Homebrew"
else
  log_skip "Homebrew already installed"
fi

# ============================================================================
# HOMEBREW PACKAGES & CASKS
# ============================================================================

log_section "2" "5" "HOMEBREW PACKAGES & CASKS"

# Install from Brewfile
if brew bundle check --file=Brewfile >/dev/null 2>&1; then
  log_skip "All Brewfile packages already installed"
else
  log_info "Installing packages from Brewfile..."
  if ! bundle_output=$(brew bundle --file=Brewfile 2>&1); then
    echo "$bundle_output"
    # Check for pin errors and provide helpful unpin commands
    if echo "$bundle_output" | grep -q "must.*brew unpin"; then
      echo ""
      log_warn "Installation blocked by pinned dependencies."
      echo "$bundle_output" | grep "must.*brew unpin" | sed -E 's/.*`(brew unpin [^`]+)`.*/  \1/' | sort -u
      exit 1
    fi
    log_error "Brewfile installation failed"
    exit 1
  fi
  log_success "Brewfile packages installed"
fi

# Pin packages to prevent auto-updates
log_info "Pinning Homebrew packages..."
pin_brew_packages

# Clean up packages not in Brewfile
log_info "Checking for packages to clean up..."
cleanup_output=$(brew bundle cleanup --force --file=Brewfile 2>&1)
if echo "$cleanup_output" | grep -qE "(Uninstall|Untap)"; then
  echo "$cleanup_output"
  log_success "Cleanup complete"
else
  log_skip "No packages to clean up"
fi

# ============================================================================
# SHELL & DOTFILES
# ============================================================================

log_section "3" "5" "SHELL & DOTFILES"

# prezto - pinned to specific commit for security
PREZTO_COMMIT="56669270988c5e32422643ec9e0562d1f3c6a0b8"
if [ ! -d "${ZDOTDIR:-$HOME}/.zprezto" ]; then
  log_info "Installing Prezto (commit: ${PREZTO_COMMIT:0:8})..."
  zsh << EOF
git clone --recursive https://github.com/sorin-ionescu/prezto.git "\${ZDOTDIR:-\$HOME}/.zprezto"
cd "\${ZDOTDIR:-\$HOME}/.zprezto"
git checkout "$PREZTO_COMMIT"
git submodule update --init --recursive
setopt EXTENDED_GLOB
for rcfile in "\${ZDOTDIR:-\$HOME}"/.zprezto/runcoms/^README.md(.N); do
  ln -sf "\$rcfile" "\${ZDOTDIR:-\$HOME}/.\${rcfile:t}"
done
EOF
  log_success "Installed Prezto"
else
  log_skip "Prezto already installed"
fi

# dotfiles - use master branch as stable
DOTFILES_DIR=~/ghq/github.com/joaosa/dotfiles
DOTFILES_BRANCH="master"
DOTFILES_CHANGED=false

if [ ! -d "$DOTFILES_DIR" ]; then
  log_info "Cloning dotfiles repository (branch: $DOTFILES_BRANCH)..."
  git clone --branch "$DOTFILES_BRANCH" https://github.com/joaosa/dotfiles "$DOTFILES_DIR"
  log_success "Cloned dotfiles"
  DOTFILES_CHANGED=true
else
  # Track current commit before update
  old_commit=$(git -C "$DOTFILES_DIR" rev-parse HEAD 2>/dev/null)

  log_info "Updating dotfiles from $DOTFILES_BRANCH branch..."
  git -C "$DOTFILES_DIR" fetch origin
  git -C "$DOTFILES_DIR" checkout "$DOTFILES_BRANCH"
  git -C "$DOTFILES_DIR" pull origin "$DOTFILES_BRANCH" --quiet || true

  new_commit=$(git -C "$DOTFILES_DIR" rev-parse HEAD 2>/dev/null)

  if [ "$old_commit" != "$new_commit" ]; then
    log_success "Updated dotfiles"
    DOTFILES_CHANGED=true
  else
    log_skip "Dotfiles already up to date"
  fi
fi

# Stow dotfiles only if changed
if [ "$DOTFILES_CHANGED" = true ]; then
  log_info "Installing dotfiles with stow..."
  mapfile -t stow_dirs < <(find "$DOTFILES_DIR" -maxdepth 1 -type d -not -path '*/.*' -exec basename {} \; | grep -v dotfiles)
  stow -d "$DOTFILES_DIR" -t "$HOME" --restow "${stow_dirs[@]}"
  log_success "Installed dotfiles"
else
  log_skip "Dotfiles unchanged, skipping stow"
fi

# fzf
if [ ! -f ~/.fzf.bash ] && [ ! -f ~/.fzf.zsh ]; then
  log_info "Installing fzf..."
  $(brew --prefix)/opt/fzf/install --all
  log_success "Installed fzf"
else
  log_skip "fzf already installed"
fi

# git
if [ -f ~/.gitignore_global ] && [ "$(git config --global --get core.excludesfile)" != "$HOME/.gitignore_global" ]; then
  git config --global core.excludesfile ~/.gitignore_global
  log_success "Configured global git excludes"
else
  log_skip "Global git excludes already configured"
fi

# parallel
if [ ! -f ~/.parallel/will-cite ]; then
  log_info "Configuring GNU parallel..."
  yes 'will cite' | parallel --citation
  log_success "Configured GNU parallel"
else
  log_skip "GNU parallel already configured"
fi

# ============================================================================
# LANGUAGE RUNTIMES
# ============================================================================

log_section "4" "5" "LANGUAGE RUNTIMES"

# rust
if ! command -v rustc >/dev/null 2>&1; then
  log_info "Installing Rust..."
  echo 1 | rustup-init -y --default-toolchain stable
  log_success "Installed Rust"
else
  rustup toolchain list | grep -q stable || rustup install stable
  rustup default stable >/dev/null 2>&1 || true
  log_skip "Rust already installed"
fi

# node
install_asdf_language "nodejs" "https://github.com/asdf-vm/asdf-nodejs.git"

# npm packages
log_info "Installing npm packages..."
install_asdf_packages "nodejs" "${NPM_PACKAGES[@]}"

# golang
install_asdf_language "golang" "https://github.com/asdf-community/asdf-golang.git"

# go packages
log_info "Installing Go packages..."
install_asdf_packages "golang" "${GO_PACKAGES[@]}"

# cargo packages (OpenPGP card tools)
CARGO_PACKAGES=(
  "openpgp-card-tools"      # oct - YubiKey/OpenPGP card management
  "openpgp-card-tool-git"   # oct-git - Git signing without gpg-agent
)

log_info "Installing Cargo packages..."
for pkg in "${CARGO_PACKAGES[@]}"; do
  # oct binaries: openpgp-card-tools -> oct, openpgp-card-tool-git -> oct-git
  case "$pkg" in
    openpgp-card-tools) bin_name="oct" ;;
    openpgp-card-tool-git) bin_name="oct-git" ;;
    *) bin_name="${pkg##*/}" ;;
  esac

  if command -v "$bin_name" >/dev/null 2>&1; then
    log_skip "$pkg ($bin_name) already installed"
  else
    log_info "Installing $pkg..."
    if [ "$DRY_RUN" = "false" ]; then
      # openpgp-card-tool-git requires explicit framework linking on macOS
      # due to mac-notification-sys not linking AppKit/CoreServices properly
      if [ "$pkg" = "openpgp-card-tool-git" ]; then
        RUSTFLAGS="-C link-arg=-framework -C link-arg=AppKit -C link-arg=-framework -C link-arg=CoreServices" cargo install "$pkg"
      else
        cargo install "$pkg"
      fi
      log_success "Installed $pkg"
    else
      log_info "[DRY RUN] Would install $pkg"
    fi
  fi
done

# ============================================================================
# SERVICES
# ============================================================================

log_section "5" "6" "SERVICES"

# syncthing - enable built-in HTTPS
SYNCTHING_CONFIG="$HOME/Library/Application Support/Syncthing/config.xml"
if [ -f "$SYNCTHING_CONFIG" ]; then
  if grep -q '<gui enabled="true" tls="false"' "$SYNCTHING_CONFIG"; then
    log_info "Enabling Syncthing HTTPS..."
    sed -i '' 's/<gui enabled="true" tls="false"/<gui enabled="true" tls="true"/' "$SYNCTHING_CONFIG"
    log_success "Enabled Syncthing HTTPS"
  else
    log_skip "Syncthing HTTPS already enabled"
  fi
fi

# syncthing - start as background service
if ! brew services list | grep -q "syncthing.*started"; then
  log_info "Starting syncthing service..."
  brew services start syncthing
  log_success "Started syncthing service"
else
  log_skip "syncthing service already running"
fi

# ============================================================================
# CONFIGURATION FILES
# ============================================================================

log_section "6" "6" "CONFIGURATION FILES"

# kubectl aliases
download_if_missing "$HOME/.kubectl_aliases" "$KUBECTL_ALIASES_URL" "$KUBECTL_ALIASES_SHA256"

# whisper model
download_if_missing "$HOME/.local/share/whisper/ggml-base.en.bin" "$WHISPER_MODEL_URL" "$WHISPER_MODEL_SHA256"

# ============================================================================
# SUMMARY
# ============================================================================

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
MINUTES=$((ELAPSED / 60))
SECONDS=$((ELAPSED % 60))

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GREEN}✓ Setup Complete!${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
echo -e "${GREEN}✓${RESET} Installed: $ITEMS_INSTALLED"
echo -e "${YELLOW}⊘${RESET} Skipped:   $ITEMS_SKIPPED"
if [ "$ITEMS_FAILED" -gt 0 ]; then
  echo -e "${RED}✗${RESET} Failed:    $ITEMS_FAILED"
fi
echo ""
echo -e "⏱  Total time: ${MINUTES}m ${SECONDS}s"
echo ""

if false; then
 # latex and writing tools
 brew install adr-tools
 brew install --cask basictex
zsh << EOF
 if ! ls /Users/$USER/Library/texmf/tlpkg/texlive.tlpdb > /dev/null; then tlmgr init-usertree; fi
 sudo tlmgr update --self
 sudo tlmgr install latexmk
 sudo tlmgr install moderncv
 sudo tlmgt collection-latexextra
EOF
fi
