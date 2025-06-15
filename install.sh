#!/bin/bash
# ========================================
# install.sh
# Complete Color Module Installer
# ========================================

# Exit immediately if a command exits with a non-zero status.
# Treat unset variables as an error when substituting.
# The return value of a pipeline is the status of the last command.
set -euo pipefail

# ---------- VERSION ----------
VERSION="1.1.2" # Incremented version due to template refactoring
VERSION_FILE="$HOME/ctl_environment/.version"

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

# Target paths for the installed files
COLOR_ROLES_TARGET="$BASE_DIR/color_roles.json"
COLOR_LAWS_TARGET="$LAWS_DIR/color-laws.json"
COLORS_SOURCE_TARGET="$BASE_DIR/colors.source.sh"
INSTALL_HOOK_TARGET="$BASE_DIR/install_hook.sh"
DOC_FILE_TARGET="$DOCS_DIR/color-enforcement.md"
SYMLINK="$HOME/.color_roles.json"
BASHRC="$HOME/.bashrc"

# Source paths for the template files in the repository
REPO_ROOT="$(dirname "$(readlink -f "$0")")" # Get the directory of the script itself
COLOR_ROLES_TEMPLATE="$REPO_ROOT/ctl_environment_template/color_roles.json.template"
COLOR_LAWS_TEMPLATE="$REPO_ROOT/ctl_environment_template/laws/color/color-laws.json.template"
COLORS_SOURCE_TEMPLATE="$REPO_ROOT/ctl_environment_template/colors.source.sh.template"
INSTALL_HOOK_TEMPLATE="$REPO_ROOT/ctl_environment_template/install_hook.sh.template"
DOC_FILE_TEMPLATE="$REPO_ROOT/docs/color-enforcement.md" # This template is directly in docs/

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
    local file_to_backup="$1" # Use 'local' for function-scoped variables
    if [ -f "$file_to_backup" ]; then
        local backup_path="${file_to_backup}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$file_to_backup" "$backup_path"
        info "Backed up existing file to: $backup_path"
    fi
}

# Cleanup on error (retained as a function for trap)
cleanup_on_error() {
    error "Installation failed. Attempting to clean up partial installation..."
    # Attempt to remove created files, ignoring errors if they don't exist
    rm -f "$COLOR_ROLES_TARGET" "$COLOR_LAWS_TARGET" "$COLORS_SOURCE_TARGET" "$INSTALL_HOOK_TARGET" "$DOC_FILE_TARGET" "$VERSION_FILE" "$SYMLINK" 2>/dev/null || true
    
    # Remove directories only if they are empty
    rmdir "$LAWS_DIR" 2>/dev/null || true
    rmdir "$DOCS_DIR" 2>/dev/null || true
    rmdir "$BASE_DIR" 2>/dev/null || true
    warn "Partial cleanup attempted. Manual inspection may be required if directories were modified."
}
trap cleanup_on_error ERR # Set a trap to call cleanup_on_error on any command failure

# Check for necessary dependencies
check_dependencies() {
    info "Checking dependencies..."
    if ! command -v jq &> /dev/null; then
        error "jq is required but not installed. Install with: sudo apt-get install jq"
        exit 1
    fi
    success "Dependencies verified."
}

# Create necessary directory structure
create_directories() {
    info "Creating directory structure: $BASE_DIR, $DOCS_DIR, $LAWS_DIR..."
    mkdir -p "$DOCS_DIR"
    mkdir -p "$LAWS_DIR"
    success "Directories created."
}

# Function to copy a template file to a target location
# Handles overwrite logic based on FORCE_OVERWRITE and BACKUP_FILES
copy_template_file() {
    local template_path="$1"
    local target_path="$2"
    local filename=$(basename "$target_path")

    info "Copying $filename..."
    if [ -f "$target_path" ]; then
        if "$FORCE_OVERWRITE"; then
            if "$BACKUP_FILES"; then backup_existing_file "$target_path"; fi
            warn "Overwriting existing $filename due to --force flag."
            cp "$template_path" "$target_path"
            success "$filename overwritten."
            return 0
        else
            warn "$filename already exists. Skipping copy to prevent overwrite. Use --force to overwrite."
            return 1 # Indicate that the file was skipped
        fi
    else
        cp "$template_path" "$target_path"
        success "$filename created."
        return 0
    fi
}

# Generate core config/source files by copying from templates
generate_core_files() {
    copy_template_file "$COLOR_ROLES_TEMPLATE" "$COLOR_ROLES_TARGET" || true # || true to prevent set -e from exiting
    copy_template_file "$COLOR_LAWS_TEMPLATE" "$COLOR_LAWS_TARGET" || true
    copy_template_file "$COLORS_SOURCE_TEMPLATE" "$COLORS_SOURCE_TARGET" || true
    copy_template_file "$INSTALL_HOOK_TEMPLATE" "$INSTALL_HOOK_TARGET" || true
    copy_template_file "$DOC_FILE_TEMPLATE" "$DOC_FILE_TARGET" || true

    # Ensure executable permissions for generated scripts
    chmod +x "$COLORS_SOURCE_TARGET"
    chmod +x "$INSTALL_HOOK_TARGET"
    success "Generated scripts made executable."
}

# Create symlink
create_symlink() {
    info "Creating symlink ~/.color_roles.json..."
    # Always recreate symlink to ensure it points to the correct location in ctl_environment
    ln -sf "$COLOR_ROLES_TARGET" "$SYMLINK"
    success "Symlink created."
}

# Update .bashrc to source necessary files
update_bashrc() {
    info "Updating .bashrc..."
    
    # Add color system loader
    if ! grep -q "source.*ctl_environment/colors.source.sh" "$BASHRC"; then
        echo "" >> "$BASHRC"
        echo "# Color Role System" >> "$BASHRC"
        echo "source \$HOME/ctl_environment/colors.source.sh" >> "$BASHRC"
        success "Color system loader added to .bashrc"
    else
        info "Color system loader already present in .bashrc"
    fi
    
    # The aliases loader logic for ~/.bash_aliases is now handled by install_aliases.sh
    # This script (install.sh) only manages the core color system.
}

# Check current version against installed version
check_version() {
    local installed_version
    if [ -f "$VERSION_FILE" ]; then
        installed_version=$(cat "$VERSION_FILE")
        if [ "$installed_version" = "$VERSION" ]; then
            info "Version $VERSION already installed."
            return 0
        else
            info "Installed version ($installed_version) differs from script version ($VERSION). An update will be performed."
            return 1 # Indicate an update is needed
        fi
    fi
    info "No version file found. Performing fresh installation."
    return 1 # Indicate installation is needed
}

# Save current version
save_version() {
    echo "$VERSION" > "$VERSION_FILE"
    success "Version $VERSION saved to $VERSION_FILE."
}

# Verify installation integrity
verify_installation() {
    info "Verifying installation..."
    
    local errors=0
    local files_to_check=(
        "$COLOR_ROLES_TARGET"
        "$COLOR_LAWS_TARGET"
        "$COLORS_SOURCE_TARGET"
        "$INSTALL_HOOK_TARGET"
        "$DOC_FILE_TARGET"
        "$SYMLINK"
        "$VERSION_FILE"
    )

    # Check core files presence
    for file_to_check_item in "${files_to_check[@]}"; do
        if [ ! -e "$file_to_check_item" ]; then # -e checks if a file or symlink exists
            error "Missing essential file/symlink: $file_to_check_item"
            errors=$((errors + 1))
        fi
    done
    
    # Validate JSON files (only if they exist)
    if [ -f "$COLOR_ROLES_TARGET" ]; then
        if ! jq empty "$COLOR_ROLES_TARGET" 2>/dev/null; then
            error "Invalid JSON in color_roles.json"
            errors=$((errors + 1))
        fi
    fi
    
    if [ -f "$COLOR_LAWS_TARGET" ]; then
        if ! jq empty "$COLOR_LAWS_TARGET" 2>/dev/null; then
            error "Invalid JSON in color-laws.json"
            errors=$((errors + 1))
        fi
    fi
    
    if [ "$errors" -eq 0 ]; then
        success "Installation verification passed!"
        return 0
    else
        error "Installation verification failed with $errors errors."
        return 1
    fi
}

# Show next steps after successful installation
show_next_steps() {
    echo ""
    echo "=========================================="
    success "Color Module Installation Complete!"
    echo "=========================================="
    echo ""
    info "Next steps:"
    echo "  1. Reload your shell: source ~/.bashrc"
    echo "  2. Test colors: colortest"
    echo "  3. View roles: colorroles"
    echo "  4. Add new app: ~/ctl_environment/install_hook.sh <name> <category> <hierarchy>"
    echo "  5. To install common aliases, run: ./install_aliases.sh"
    echo ""
    info "Available commands (from colors.source.sh):"
    echo "  • Color functions: color_apply <role> <text>"
    echo ""
    info "Documentation: ~/ctl_environment/docs/color-enforcement.md"
    echo ""
}

# Display usage information
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -f, --force     Force overwrite existing configuration files."
    echo "  -b, --backup    Create backups of existing files before overwriting (requires -f)."
    "  -h, --help      Show this help message."
    "  -v, --version   Show version information."
    echo ""
    echo "This script installs or updates the core color-coded environment system."
    echo "It does NOT manage shell aliases; use install_aliases.sh for that."
    echo "By default, it will not overwrite existing config/source files if they are detected."
    "To regenerate them, use the --force flag. To back them up, use --backup with --force."
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
                echo "Color Module Installer v$VERSION"
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
    info "Color Module Installer Starting (v$VERSION)"
    echo "=========================================="
    
    # Check version and decide to proceed or update
    if ! check_version && ! "$FORCE_OVERWRITE"; then
        info "Skipping re-installation as same version is installed and --force is not used."
        exit 0
    fi

    check_dependencies
    create_directories
    
    info "Generating and updating core files by copying from templates..."
    generate_core_files # This function now handles copying from templates
    
    create_symlink
    update_bashrc
    
    if verify_installation; then
        save_version # Only save version if installation is successful
        show_next_steps
    else
        error "Installation failed verification. Please check errors above."
        exit 1
    fi
}

# Run main function
main "$@"
