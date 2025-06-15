#!/bin/bash
# ========================================
# install_aliases.sh
# Common Bash Aliases Installer
# ========================================

set -euo pipefail

# ---------- VERSION ----------
VERSION="1.0.4" # Incremented version for aliases version file fix
VERSION_FILE="$HOME/ctl_environment/.aliases_version" # Separate version for aliases

# ---------- COLORS ----------
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ---------- PATHS ----------
BASE_DIR="$HOME/ctl_environment" # Used for context, not primary target for aliases
BASH_ALIASES="$HOME/.bash_aliases"
BASHRC="$HOME/.bashrc"

# Source path for the template file in the repository
REPO_ROOT="$(dirname "$(readlink -f "$0")")" # Get the directory of the script itself
BASH_ALIASES_TEMPLATE="$REPO_ROOT/bash_aliases_template.sh"

# ---------- GLOBAL FLAGS ----------
FORCE_OVERWRITE=false
BACKUP_FILES=false

# ---------- FUNCTIONS ----------

# Logging functions
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Function to backup an existing file
backup_existing_file() {
    local file_to_backup="$1"
    if [ -f "$file_to_backup" ]; then
        local backup_path="${file_to_backup}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$file_to_backup" "$backup_path"
        info "Backed up existing file to: $backup_path"
    fi
}

# Generate .bash_aliases by copying from template
generate_bash_aliases() {
    info "Generating .bash_aliases..."
    if [ -f "$BASH_ALIASES" ]; then
        if "$FORCE_OVERWRITE"; then
            if "$BACKUP_FILES"; then backup_existing_file "$BASH_ALIASES"; fi
            warn "Overwriting existing $BASH_ALIASES due to --force flag."
            cp "$BASH_ALIASES_TEMPLATE" "$BASH_ALIASES"
            success ".bash_aliases overwritten."
            return 0
        else
            warn "$BASH_ALIASES already exists. Skipping generation. Use --force to overwrite. Manual merge might be needed for new aliases."
            return 1 # Indicate that the file was skipped
        fi
    else
        cp "$BASH_ALIASES_TEMPLATE" "$BASH_ALIASES"
        success ".bash_aliases created."
        return 0
    fi
}

# Update .bashrc to source .bash_aliases
update_bashrc() {
    info "Updating .bashrc to source ~/.bash_aliases..."
    # Add aliases loader
    if ! grep -q "source.*bash_aliases" "$BASHRC"; then
        echo "" >> "$BASHRC"
        echo "# Load custom aliases" >> "$BASHRC"
        echo "if [ -f ~/.bash_aliases ]; then" >> "$BASHRC"
        echo "    . ~/.bash_aliases" >> "$BASHRC"
        echo "fi" >> "$BASHRC"
        success "Aliases loader added to .bashrc"
    else
        info "Aliases loader already present in .bashrc"
    fi
    return 0
}

# Check current version against installed version
check_version() {
    local installed_version
    if [ -f "$VERSION_FILE" ]; then
        installed_version=$(cat "$VERSION_FILE")
        if [ "$installed_version" = "$VERSION" ]; then
            info "Aliases version $VERSION already installed."
            return 0
        else
            info "Installed aliases version ($installed_version) differs from script version ($VERSION). An update will be performed."
            return 1 # Indicate an update is needed
        fi
    fi
    info "No aliases version file found. Performing fresh installation."
    return 1 # Indicate installation is needed
}

# Save current version
save_version() {
    echo "$VERSION" > "$VERSION_FILE"
    success "Aliases version $VERSION saved to $VERSION_FILE."
    return 0
}

# Verify installation integrity
verify_installation() {
    info "Verifying aliases installation..."
    local errors=0
    
    # Check if .bash_aliases exists
    if [ ! -f "$BASH_ALIASES" ]; then
        error "Missing .bash_aliases file."
        ((errors++))
    fi

    # Check if the .bashrc sourcing line is present
    if ! grep -q "source.*bash_aliases" "$BASHRC"; then
        error "Missing sourcing line for .bash_aliases in $BASHRC."
        ((errors++))
    fi

    # Check version file
    if [ ! -f "$VERSION_FILE" ]; then
        error "Missing aliases version file: $VERSION_FILE"
        ((errors++))
    fi
    
    if [ "$errors" -eq 0 ]; then
        success "Aliases installation verification passed!"
        return 0
    else
        error "Aliases installation verification failed with $errors errors."
        return 1
    fi
}

# Show next steps after successful installation
show_next_steps() {
    echo ""
    echo "=========================================="
    success "Common Bash Aliases Installation Complete!"
    echo "=========================================="
    echo ""
    info "Next steps:"
    echo "  1. Reload your shell: source ~/.bashrc"
    echo "  2. Test aliases: colortest, gs, tfp, ports, dps, dc up"
    echo "  (Note: Python virtual environment activation is now managed manually or via other tools.)"
    echo ""
}

# Display usage information
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -f, --force     Force overwrite existing .bash_aliases file."
    echo "  -b, --backup    Create a backup of existing .bash_aliases before overwriting (requires -f)."
    echo "  -h, --help      Show this help message."
    echo "  -v, --version   Show version information."
    echo ""
    echo "This script installs or updates common Bash aliases."
    echo "By default, it will not overwrite ~/.bash_aliases if it is detected."
    "To regenerate it, use the --force flag. To back it up, use --backup with --force."
}

# ---------- MAIN EXECUTION ----------
main() {
    # Parse command-line options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--force)
                FORCE_OVERWRITE=true
                shift
                ;;
            -b|--backup)
                BACKUP_FILES=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            -v|--version)
                echo "Common Bash Aliases Installer v$VERSION"
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    # Validate backup flag usage
    if "$BACKUP_FILES" && ! "$FORCE_OVERWRITE"; then
        error "--backup flag requires --force flag to be used."
        usage
        exit 1
    fi

    echo "=========================================="
    info "Common Bash Aliases Installer Starting (v$VERSION)"
    echo "=========================================="
    
    local needs_installation_or_update=1 # Track if install/update logic proceeds
    local version_check_result=1 # Assume update needed until proven otherwise
    
    if check_version; then # if check_version returns 0 (true), means already installed and same version
        version_check_result=0
        if ! "$FORCE_OVERWRITE"; then
            info "Skipping re-installation. Run with --force to re-install."
            exit 0 # Exit cleanly if already installed and not forced
        fi
    fi

    # Proceed with installation/update regardless of version_check_result if --force is used
    # or if it's a fresh install (version_check_result is 1)

    generate_bash_aliases || true # Allow script to continue if file skipped
    update_bashrc
    
    if verify_installation; then
        # Only save version if a new install or a forced update occurred
        # i.e., if check_version was 1 (needs update/install) OR if FORCE_OVERWRITE is true
        if [ "$version_check_result" -eq 1 ] || "$FORCE_OVERWRITE"; then
            save_version
        fi
        show_next_steps
    else
        error "Aliases installation failed verification. Please check errors above."
        exit 1
    fi
}

# Run main function
main "$@"
