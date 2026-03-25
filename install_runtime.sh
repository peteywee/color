#!/bin/bash
# Modern runtime installer/migrator for the color system.
# Keeps source repo location separate from deployed runtime state.

set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1" >&2; }
error()   { echo -e "${RED}[ERROR]${NC} $1" >&2; }

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
LEGACY_DIR="$HOME/ctl_environment"
DEFAULT_RUNTIME_DIR="$HOME/.local/share/tss/color"
RUNTIME_DIR="${COLOR_RUNTIME_HOME:-$DEFAULT_RUNTIME_DIR}"
BASHRC="$HOME/.bashrc"
FORCE=false
BACKUP=false
INSTALL_ARGS=()

usage() {
  cat <<USAGE
Usage: $0 [OPTIONS] [-- <install.sh options>]
Options:
  --runtime-dir <path>   Deploy runtime assets to a custom path.
  --force                Allow replacement of an existing runtime directory.
  --backup               Create a timestamped backup before replacing runtime data.
  -h, --help             Show this help message.

All remaining options are forwarded to ./install.sh.
Examples:
  $0
  $0 --runtime-dir "$HOME/configs-runtime/color" -- --skip-nano
USAGE
}

backup_dir() {
  local source_dir="$1"
  local backup_path="${source_dir}.backup.$(date +%Y%m%d_%H%M%S)"
  cp -a "$source_dir" "$backup_path"
  info "Backed up runtime directory to: $backup_path"
}

ensure_runtime_loader_note() {
  touch "$BASHRC"
  if ! grep -Fq 'COLOR_RUNTIME_HOME=' "$BASHRC"; then
    {
      echo ''
      echo '# Color runtime location'
      echo "export COLOR_RUNTIME_HOME=\"$RUNTIME_DIR\""
    } >> "$BASHRC"
    success "Added COLOR_RUNTIME_HOME to .bashrc"
  else
    info "COLOR_RUNTIME_HOME already present in .bashrc"
  fi
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --runtime-dir)
        [[ $# -lt 2 ]] && { error "--runtime-dir requires a path"; exit 1; }
        RUNTIME_DIR="$2"
        shift 2
        ;;
      --force)
        FORCE=true
        shift
        ;;
      --backup)
        BACKUP=true
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      --)
        shift
        INSTALL_ARGS+=("$@")
        break
        ;;
      *)
        INSTALL_ARGS+=("$1")
        shift
        ;;
    esac
  done

  mkdir -p "$(dirname "$RUNTIME_DIR")"

  info "Running unified installer first..."
  "$SCRIPT_DIR/install.sh" "${INSTALL_ARGS[@]}"

  if [ "$LEGACY_DIR" = "$RUNTIME_DIR" ]; then
    ensure_runtime_loader_note
    success "Runtime already installed at legacy/default path: $LEGACY_DIR"
    exit 0
  fi

  if [ -e "$RUNTIME_DIR" ] && [ ! -L "$RUNTIME_DIR" ]; then
    if ! $FORCE; then
      error "Runtime target already exists: $RUNTIME_DIR"
      error "Re-run with --force to replace it, or choose --runtime-dir <path>."
      exit 1
    fi
    $BACKUP && backup_dir "$RUNTIME_DIR"
    rm -rf "$RUNTIME_DIR"
    warn "Removed existing runtime target due to --force."
  fi

  if [ -L "$LEGACY_DIR" ]; then
    rm -f "$LEGACY_DIR"
  fi

  if [ -d "$LEGACY_DIR" ]; then
    mv "$LEGACY_DIR" "$RUNTIME_DIR"
    success "Moved runtime from $LEGACY_DIR to $RUNTIME_DIR"
  elif [ ! -d "$RUNTIME_DIR" ]; then
    error "Expected runtime directory missing after install: $LEGACY_DIR"
    exit 1
  fi

  ln -sfn "$RUNTIME_DIR" "$LEGACY_DIR"
  success "Created compatibility symlink: $LEGACY_DIR -> $RUNTIME_DIR"

  ensure_runtime_loader_note

  echo
  success "Modern runtime migration complete."
  info "Source repo remains separate from runtime state."
  info "Runtime directory: $RUNTIME_DIR"
  info "Compatibility link: $LEGACY_DIR"
  info "Reload shell: source ~/.bashrc"
}

main "$@"
