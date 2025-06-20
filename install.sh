#!/bin/bash
# ========================================
# install.sh
# Unified Color Module & Aliases Installer
# ========================================

# Exit immediately if a command exits with a non-zero status.
set -euo pipefail

# ---------- VERSION ----------
CORE_VERSION="2.0.4" # Final bugfixes
ALIASES_VERSION="2.0.4"
CORE_VERSION_FILE="$HOME/ctl_environment/.version"
ALIASES_VERSION_FILE="$HOME/ctl_environment/.aliases_version"

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
BASHRC="$HOME/.bashrc"
BASH_ALIASES_FILE="$HOME/.bash_aliases"
SYMLINK="$HOME/.color_roles.json"

# Source paths for template files in the repository
REPO_ROOT="$(dirname "$(readlink -f "$0")")"
COLOR_ROLES_TEMPLATE="$REPO_ROOT/ctl_environment_template/color_roles.json.template"
COLOR_LAWS_TEMPLATE="$REPO_ROOT/ctl_environment_template/laws/color/color-laws.json.template"
COLORS_SOURCE_TEMPLATE="$REPO_ROOT/ctl_environment_template/colors.source.sh.template"
INSTALL_HOOK_TEMPLATE="$REPO_ROOT/ctl_environment_template/install_hook.sh.template"
BASH_ALIASES_TEMPLATE="$REPO_ROOT/bash_aliases_template.sh"

# ---------- GLOBAL FLAGS ----------
FORCE_OVERWRITE=false
BACKUP_FILES=false
SKIP_ALIASES=false

# ---------- FUNCTIONS ----------

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1" >&2; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

backup_existing_file() {
    local file_to_backup="$1"
    if [ -f "$file_to_backup" ]; then
        local backup_path
        backup_path="${file_to_backup}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$file_to_backup" "$backup_path"
        info "Backed up existing file to: $backup_path"
    fi
}

check_dependencies() {
    info "Checking dependencies..."
    if ! command -v jq &> /dev/null; then
        error "jq is required but not installed. Install with: sudo apt-get install jq"
        exit 1
    fi
    success "Dependencies verified."
}

copy_template_file() {
    local template_path="$1"
    local target_path="$2"
    local filename
    filename=$(basename "$target_path")

    info "Processing $filename..."
    if [ ! -f "$template_path" ]; then
        error "Template file not found: $template_path"
        exit 1
    fi
    if [ -f "$target_path" ]; then
        if $FORCE_OVERWRITE; then
            if $BACKUP_FILES; then backup_existing_file "$target_path"; fi
            warn "Overwriting existing $filename due to --force flag."
            cp "$template_path" "$target_path"
            success "$filename overwritten."
        else
            warn "$filename already exists. Skipping. Use --force to overwrite."
        fi
    else
        cp "$template_path" "$target_path"
        success "$filename created."
    fi
}

install_core_module() {
    info "--- Installing Core Color Module ---"
    
    local installed_version
    if [ -f "$CORE_VERSION_FILE" ]; then
        installed_version=$(cat "$CORE_VERSION_FILE")
        if [ "$installed_version" = "$CORE_VERSION" ] && ! $FORCE_OVERWRITE; then
            info "Core module version $CORE_VERSION already installed. Skipping."
            return
        fi
        info "Updating core module from v$installed_version to v$CORE_VERSION."
    fi

    mkdir -p "$DOCS_DIR" "$LAWS_DIR"
    
    copy_template_file "$COLOR_ROLES_TEMPLATE" "$BASE_DIR/color_roles.json"
    copy_template_file "$COLOR_LAWS_TEMPLATE" "$LAWS_DIR/color-laws.json"
    copy_template_file "$COLORS_SOURCE_TEMPLATE" "$BASE_DIR/colors.source.sh"
    copy_template_file "$INSTALL_HOOK_TEMPLATE" "$BASE_DIR/install_hook.sh"

    chmod +x "$BASE_DIR/colors.source.sh" "$BASE_DIR/install_hook.sh"

    info "Creating symlink ~/.color_roles.json..."
    ln -sf "$BASE_DIR/color_roles.json" "$SYMLINK"
    
    info "Updating .bashrc for color system..."
    touch "$BASHRC" # FIX: Ensure .bashrc exists before grep
    if ! grep -q "source.*ctl_environment/colors.source.sh" "$BASHRC"; then
        echo -e "\n# Color Role System\nsource \$HOME/ctl_environment/colors.source.sh" >> "$BASHRC"
        success "Color system loader added to .bashrc."
    else
        info "Color system loader already in .bashrc."
    fi
    
    echo "$CORE_VERSION" > "$CORE_VERSION_FILE"
    success "Core module installation complete. Version: $CORE_VERSION"
}

install_aliases() {
    if $SKIP_ALIASES; then
        info "--- Skipping Aliases Installation ---"
        return
    fi

    info "--- Installing Bash Aliases ---"

    local installed_version
    if [ -f "$ALIASES_VERSION_FILE" ]; then
        installed_version=$(cat "$ALIASES_VERSION_FILE")
        if [ "$installed_version" = "$ALIASES_VERSION" ] && ! $FORCE_OVERWRITE; then
            info "Aliases version $ALIASES_VERSION already installed. Skipping."
            return
        fi
        info "Updating aliases from v$installed_version to v$ALIASES_VERSION."
    fi

    copy_template_file "$BASH_ALIASES_TEMPLATE" "$BASH_ALIASES_FILE"

    info "Updating .bashrc for aliases..."
    touch "$BASHRC" # FIX: Ensure .bashrc exists before grep
    if ! grep -Fq ". ~/.bash_aliases" "$BASHRC"; then # FIX: Search for the exact string
        echo -e "\n# Load custom aliases\nif [ -f ~/.bash_aliases ]; then\n    . ~/.bash_aliases\nfi" >> "$BASHRC"
        success "Aliases loader added to .bashrc."
    else
        info "Aliases loader already in .bashrc."
    fi

    echo "$ALIASES_VERSION" > "$ALIASES_VERSION_FILE"
    success "Aliases installation complete. Version: $ALIASES_VERSION"
}

verify_installation() {
    info "--- Verifying Installation ---"
    local errors=0

    local core_files=("$BASE_DIR/color_roles.json" "$LAWS_DIR/color-laws.json" "$BASE_DIR/colors.source.sh" "$BASE_DIR/install_hook.sh" "$SYMLINK" "$CORE_VERSION_FILE")
    for file in "${core_files[@]}"; do
        if [ ! -e "$file" ]; then
            error "Missing core file/symlink: $file"
            ((errors++))
        fi
    done

    if ! $SKIP_ALIASES; then
        if [ ! -f "$BASH_ALIASES_FILE" ]; then
            error "Missing alias file: $BASH_ALIASES_FILE"
            ((errors++))
        fi
        # FIX: Check for the correct string to fix the verification bug
        if ! grep -Fq ". ~/.bash_aliases" "$BASHRC"; then
            error "Missing aliases loader in .bashrc"
            ((errors++))
        fi
    fi

    if [ "$errors" -eq 0 ]; then
        success "Installation verification passed!"
    else
        error "Installation verification failed with $errors errors."
        exit 1
    fi
}

show_next_steps() {
    echo ""
    success "=========================================="
    success "  Installation Complete!"
    success "=========================================="
    echo ""
    info "Next steps:"
    echo "  1. Reload your shell: source ~/.bashrc"
    echo "  2. Test colors and aliases: colortest"
    echo "  3. View available color roles: colorroles"
    echo ""
}

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -f, --force         Force overwrite of existing configuration files."
    echo "  -b, --backup        Create backups before overwriting (requires --force)."
    echo "      --skip-aliases  Skip the installation of bash aliases."
    echo "  -h, --help          Show this help message."
    echo "  -v, --version       Show version information."
}

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--force) FORCE_OVERWRITE=true; shift ;;
            -b|--backup) BACKUP_FILES=true; shift ;;
            --skip-aliases) SKIP_ALIASES=true; shift ;;
            -h|--help) usage; exit 0 ;;
            -v|--version) echo "Installer v$CORE_VERSION"; exit 0 ;;
            *) error "Unknown option: $1"; usage; exit 1 ;;
        esac
    done

    if $BACKUP_FILES && ! $FORCE_OVERWRITE; then
        error "--backup requires --force."
        usage
        exit 1
    fi

    echo "=========================================="
    info "  Starting Color Module Installer"
    echo "=========================================="

    check_dependencies
    install_core_module
    install_aliases
    verify_installation
    show_next_steps
}

main "$@"
