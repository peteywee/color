#!/bin/bash
# ========================================
# uninstall.sh
# Uninstalls the Color Module and Aliases
# ========================================

set -euo pipefail

# ---------- COLORS ----------
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ---------- PATHS ----------
BASE_DIR="$HOME/ctl_environment"
SYMLINK="$HOME/.color_roles.json"
BASH_ALIASES_FILE="$HOME/.bash_aliases"
BASHRC="$HOME/.bashrc"

# ---------- FUNCTIONS ----------

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
# FIX: Redirect warnings and errors to stderr
warn() { echo -e "${YELLOW}[WARN]${NC} $1" >&2; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

confirm_action() {
    read -r -p "Are you sure you want to uninstall? This removes ~/ctl_environment and modifies ~/.bashrc. (y/N) " response
    case "$response" in
        [yY][eE][sS]|[yY]) true ;;
        *) false ;;
    esac
}

# Main uninstall function
uninstall_system() {
    info "--- Starting Uninstallation ---"

    if [ -d "$BASE_DIR" ]; then
        info "Removing directory: $BASE_DIR"
        rm -rf "$BASE_DIR"
        success "Directory $BASE_DIR removed."
    else
        info "Directory $BASE_DIR not found."
    fi

    if [ -L "$SYMLINK" ]; then
        info "Removing symlink: $SYMLINK"
        rm -f "$SYMLINK"
        success "Symlink removed."
    else
        info "Symlink $SYMLINK not found."
    fi

    if [ -f "$BASH_ALIASES_FILE" ]; then
        warn "Your $BASH_ALIASES_FILE file will be removed as part of the cleanup."
        read -r -p "Do you want to delete $BASH_ALIASES_FILE? (y/N) " response
        if [[ "$response" =~ ^[yY]([eE][sS])?$ ]]; then
            rm -f "$BASH_ALIASES_FILE"
            success "$HOME/.bash_aliases removed."
        else
            info "$HOME/.bash_aliases was not removed."
        fi
    fi

    info "Cleaning up .bashrc..."
    if [ -f "$BASHRC" ]; then
        cp "$BASHRC" "${BASHRC}.backup.$(date +%Y%m%d_%H%M%S)"
        
        sed -i '/# Color Role System/,+1d' "$BASHRC"
        sed -i '/# Load custom aliases/,+3d' "$BASHRC"
        
        success ".bashrc cleaned up. A backup was created."
    fi

    success "--- Uninstallation Complete ---"
    info "Please reload your shell to apply changes: source ~/.bashrc"
}

# ---------- MAIN EXECUTION ----------
main() {
    if confirm_action; then
        uninstall_system
    else
        info "Uninstallation cancelled."
    fi
}

main "$@"
