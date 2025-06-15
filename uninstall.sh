#!/bin/bash
# ========================================
# uninstall.sh
# Uninstalls the Complete Color Module and Common Bash Aliases
# ========================================

set -euo pipefail

# ---------- COLORS ----------
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ---------- PATHS ----------
BASE_DIR="$HOME/ctl_environment"
DOCS_DIR="$BASE_DIR/docs"
LAWS_DIR="$BASE_DIR/laws/color"
COLOR_ROLES="$BASE_DIR/color_roles.json"
COLOR_LAWS="$LAWS_DIR/color-laws.json"
COLORS_SOURCE="$BASE_DIR/colors.source.sh"
INSTALL_HOOK="$BASE_DIR/install_hook.sh"
DOC_FILE="$BASE_DIR/docs/color-enforcement.md" # Path to where it's installed
VERSION_FILE="$BASE_DIR/.version"          # Color module version
ALIASES_VERSION_FILE="$BASE_DIR/.aliases_version" # Aliases version
SYMLINK="$HOME/.color_roles.json"
BASH_ALIASES="$HOME/.bash_aliases"
BASHRC="$HOME/.bashrc"

# ---------- FUNCTIONS ----------

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

confirm_action() {
    read -r -p "Are you sure you want to uninstall the Color Module & Aliases? This will remove files and modify your .bashrc. (y/N) " response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            true
            ;;
        *)
            false
            ;;
    esac
}

# Main uninstall function
uninstall_color_system() {
    info "Starting uninstallation of Color Module & Aliases..."

    # Remove generated files and symlink
    info "Removing generated files and symlink..."
    rm -fv "$COLOR_ROLES" "$COLOR_LAWS" "$COLORS_SOURCE" "$INSTALL_HOOK" "$DOC_FILE" "$VERSION_FILE" "$ALIASES_VERSION_FILE" "$SYMLINK" 2>/dev/null || true
    success "Generated files and symlink removed."

    # Remove directories if they are empty
    info "Removing empty directories..."
    rmdir "$LAWS_DIR" 2>/dev/null || true
    rmdir "$DOCS_DIR" 2>/dev/null || true
    rmdir "$BASE_DIR" 2>/dev/null || true
    success "Directories removed if empty."

    # Remove lines from .bashrc related to color system and aliases
    info "Removing entries from $BASHRC..."
    # Using sed to delete lines related to color system loader
    if grep -q "source.*ctl_environment/colors.source.sh" "$BASHRC"; then
        sed -i '/# Color Role System/,+1d' "$BASHRC" # Remove comment and source line
        sed -i '/source.*ctl_environment\/colors.source.sh/d' "$BASHRC" # Ensure source line is gone
        success "Color system loader removed from $BASHRC."
    else
        info "Color system loader not found in $BASHRC."
    fi

    # Using sed to delete lines related to aliases loader
    if grep -q "source.*bash_aliases" "$BASHRC"; then
        sed -i '/# Load custom aliases/,+3d' "$BASHRC" # Remove comment and if block
        sed -i '/if \[ -f ~\/.bash_aliases \]; then/,+3d' "$BASHRC" # Ensure block is gone
        success "Aliases loader removed from $BASHRC."
    else
        info "Aliases loader not found in $BASHRC."
    fi
    
    # Warn about ~/.bash_aliases: we don't automatically delete user's ~/.bash_aliases
    warn "Note: Your personal ~/.bash_aliases file was NOT removed. You may want to manually clean up aliases related to this system if you generated it."
    warn "Also, any dynamically added roles in color_roles.json via install_hook.sh will only be removed if you deleted that file."

    success "Uninstallation complete! Please open a new terminal session or run 'source ~/.bashrc' to fully apply changes."
}

# ---------- MAIN EXECUTION ----------
main() {
    if confirm_action; then
        uninstall_color_system
    else
        info "Uninstallation cancelled."
        exit 0
    fi
}

main "$@"
