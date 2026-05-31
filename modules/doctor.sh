#!/usr/bin/env bash
# Doctor: Verify setup health by checking expected binaries and model data

# shellcheck disable=SC1091
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && source "${BASH_SOURCE[0]%/*}/../lib/standalone.sh"

run() {
  log_section "1" "3" "CORE TOOLS"
  check_binary brew "Homebrew"
  check_binary git "Git"
  check_binary just "Just"
  check_binary zsh "Zsh"
  check_binary nvim "Neovim"
  check_binary tmux "tmux"

  log_section "2" "3" "LANGUAGE RUNTIMES"
  check_binary rustc "Rust compiler"
  check_binary cargo "Cargo"
  check_binary node "Node.js"
  check_binary go "Go"
  check_binary python3 "Python"
  check_binary pip3 "Python package installer"

  log_section "3" "3" "ASR"
  check_binary qwen-asr "Qwen ASR CLI"
  check_file "$HOME/.local/share/qwen3-asr/Qwen3-ASR-0.6B/config.json" "ASR model (Qwen3-ASR-0.6B)"

  return $(( ITEMS_FAILED > 0 ? 1 : 0 ))
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && { run || true; print_summary --doctor; exit $(( ITEMS_FAILED > 0 ? 1 : 0 )); }
