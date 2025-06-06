#!/bin/bash

# ========================================
# install_color_aliases.sh
# Fixed Color Module & Aliases Installer
# Rules: No white/black. Blue is allowed.
# ========================================

set -euo pipefail

# ---------- COLORS (Built-in, no external dependency) ----------
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly PURPLE='\033[0;35m'
readonly NC='\033[0m'

# ---------- PATHS ----------
BASE_DIR="$HOME/ctl_environment"
DOCS_DIR="$BASE_DIR/docs"
LAWS_DIR="$BASE_DIR/laws/color"
LOG_DIR="$HOME/.logs/ctl_environment"
LOG_FILE="$LOG_DIR/install_$(date +%Y%m%d_%H%M%S).log"

COLOR_ROLES="$BASE_DIR/color_roles.json"
COLOR_LAWS="$LAWS_DIR/color-laws.json"
COLORS_SOURCE="$BASE_DIR/colors.source.sh"
INSTALL_HOOK="$BASE_DIR/install_hook.sh"
DOC_FILE="$DOCS_DIR/color-enforcement.md"
SYMLINK="$HOME/.color_roles.json"
BASH_ALIASES="$HOME/.bash_aliases"
BASHRC="$HOME/.bashrc"

# ---------- LOGGING ----------
setup_logging() {
    mkdir -p "$LOG_DIR"
    echo "Install started at $(date)" > "$LOG_FILE"
}

info() { echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"; }

# ---------- CORE FUNCTIONS ----------

check_dependencies() {
    info "Checking dependencies..."
    if ! command -v jq &> /dev/null; then
        error "jq is required but not installed. Install with: sudo apt-get install jq"
        exit 1
    fi
    success "Dependencies verified."
}

create_directories() {
    info "Creating directory structure..."
    mkdir -p "$DOCS_DIR" "$LAWS_DIR"
    success "Directories created."
}

generate_color_roles() {
    info "Generating color_roles.json (blue allowed, only white/black banned)..."
    cat > "$COLOR_ROLES" <<'EOF'
[
    {
        "role": "directory",
        "category": "infrastructure",
        "color_code": "COLOR_PURPLE",
        "hex_value": "#A020F0",
        "hierarchy": "parent",
        "source_type": "static",
        "app_linked": "filesystem",
        "install_hook": "hook_directory_installed"
    },
    {
        "role": "prompt",
        "category": "interface",
        "color_code": "COLOR_PURPLE",
        "hex_value": "#A020F0",
        "hierarchy": "parent",
        "source_type": "static",
        "app_linked": "bash",
        "install_hook": "hook_prompt_installed"
    },
    {
        "role": "files",
        "category": "storage",
        "color_code": "COLOR_VIBRANT_BLUE",
        "hex_value": "#1E90FF",
        "hierarchy": "child",
        "source_type": "static",
        "app_linked": "filesystem",
        "install_hook": "hook_files_installed"
    },
    {
        "role": "links",
        "category": "storage",
        "color_code": "COLOR_CYAN",
        "hex_value": "#00CED1",
        "hierarchy": "child",
        "source_type": "static",
        "app_linked": "filesystem",
        "install_hook": "hook_links_installed"
    },
    {
        "role": "scripts",
        "category": "automation",
        "color_code": "COLOR_SCRIPT_BLUE",
        "hex_value": "#4169E1",
        "hierarchy": "cousin",
        "source_type": "static",
        "app_linked": "bash",
        "install_hook": "hook_scripts_installed"
    },
    {
        "role": "errors",
        "category": "alert",
        "color_code": "COLOR_RED",
        "hex_value": "#FF0000",
        "hierarchy": "alert",
        "source_type": "static",
        "app_linked": "system",
        "install_hook": "hook_errors_installed"
    },
    {
        "role": "warnings",
        "category": "alert",
        "color_code": "COLOR_YELLOW",
        "hex_value": "#FFFF00",
        "hierarchy": "alert",
        "source_type": "static",
        "app_linked": "system",
        "install_hook": "hook_warnings_installed"
    },
    {
        "role": "success",
        "category": "feedback",
        "color_code": "COLOR_GREEN",
        "hex_value": "#00FF00",
        "hierarchy": "feedback",
        "source_type": "static",
        "app_linked": "system",
        "install_hook": "hook_success_installed"
    }
]
EOF
    if ! jq empty "$COLOR_ROLES" 2>/dev/null; then
        error "Failed to generate valid color_roles.json"
        exit 1
    fi
    success "color_roles.json created (blue colors allowed, only white/black banned)."
}

generate_color_laws() {
    info "Generating color-laws.json..."
    cat > "$COLOR_LAWS" <<'EOF'
{
  "RULE-COLOR-SYSTEM-01": {
    "description": "Enforce color validity for system roles - only white and black are banned.",
    "version": "1.0.0",
    "enforced": true,
    "constraints": {
      "banned_colors": [
        "#FFFFFF",
        "#000000"
      ],
      "allowed_colors": {
        "blue_colors_allowed": true,
        "note": "Blue colors like #1E90FF, #4169E1 are perfectly fine"
      },
      "hierarchy_protection": {
        "parent_cannot_be_overwritten_by_child": true,
        "alert_colors_reserved": ["#FF0000", "#FFFF00"],
        "feedback_colors_reserved": ["#00FF00"]
      }
    },
    "role_colors": {
      "directory": "#A020F0",
      "prompt": "#A020F0", 
      "files": "#1E90FF",
      "scripts": "#4169E1",
      "links": "#00CED1",
      "errors": "#FF0000",
      "warnings": "#FFFF00",
      "success": "#00FF00"
    }
  }
}
EOF
    if ! jq empty "$COLOR_LAWS" 2>/dev/null; then
        error "Failed to generate valid color-laws.json"
        exit 1
    fi
    success "color-laws.json created."
}

generate_colors_source() {
    info "Generating colors.source.sh..."
    cat > "$COLORS_SOURCE" <<'EOF'
#!/bin/bash
# colors.source.sh - Runtime loader for color role schema

COLOR_ROLE_SCHEMA_PATH="${COLOR_ROLE_SCHEMA_PATH:-$HOME/.color_roles.json}"

if [ ! -f "$COLOR_ROLE_SCHEMA_PATH" ]; then
    echo "[ERROR] color_roles.json not found at $COLOR_ROLE_SCHEMA_PATH" >&2
    return 1
fi

if ! command -v jq &> /dev/null; then
    echo "[ERROR] jq is required but not installed" >&2
    return 1
fi

# Load roles into environment
export COLOR_ROLE_MAP=$(cat "$COLOR_ROLE_SCHEMA_PATH" | jq -c '.')

# Function to get color hex by role
get_color_by_role() {
    local role="$1"
    echo "$COLOR_ROLE_MAP" | jq -r ".[] | select(.role==\"$role\") | .hex_value"
}

# Function to apply color to text
color_apply() {
    local role="$1"
    shift
    local text="$*"
    local color_hex=$(get_color_by_role "$role")
    
    # Only enforce no white, no black - blue is allowed
    case "$color_hex" in
        "#FFFFFF"|"#000000")
            color_hex="#A020F0"  # Force purple only for forbidden white/black
            ;;
    esac
    
    # Apply ANSI colors
    case "$color_hex" in
        "#A020F0") echo -e "\033[35m$text\033[0m" ;;     # Purple
        "#1E90FF") echo -e "\033[94m$text\033[0m" ;;     # Blue
        "#4169E1") echo -e "\033[34m$text\033[0m" ;;     # Royal Blue
        "#00CED1") echo -e "\033[96m$text\033[0m" ;;     # Cyan
        "#FF0000") echo -e "\033[91m$text\033[0m" ;;     # Red
        "#FFFF00") echo -e "\033[93m$text\033[0m" ;;     # Yellow
        "#00FF00") echo -e "\033[92m$text\033[0m" ;;     # Green
        *) echo -e "\033[37m$text\033[0m" ;;             # Default white
    esac
}

# Export functions
export -f get_color_by_role
export -f color_apply

# Set colored prompt (purple)
export PS1="\[\033[35m\]\u@\h:\w\$ \[\033[0m\]"
EOF
    chmod +x "$COLORS_SOURCE"
    success "colors.source.sh created."
}

generate_install_hook() {
    info "Generating install_hook.sh..."
    cat > "$INSTALL_HOOK" <<'EOF'
#!/bin/bash
# install_hook.sh - Auto-register a new app into color_roles.json

ROLE_NAME="$1"
CATEGORY="$2"
HIERARCHY="$3"

if [[ -z "$ROLE_NAME" || -z "$CATEGORY" || -z "$HIERARCHY" ]]; then
    echo "Usage: $0 <role_name> <category> <hierarchy>"
    echo "Example: $0 nginx infrastructure parent"
    exit 1
fi

SCHEMA_PATH="${COLOR_ROLE_SCHEMA_PATH:-$HOME/.color_roles.json}"

if [ ! -f "$SCHEMA_PATH" ]; then
    echo "ERROR: color_roles.json not found at $SCHEMA_PATH"
    exit 1
fi

# Check if role already exists
if jq -e ".[] | select(.role==\"$ROLE_NAME\")" "$SCHEMA_PATH" > /dev/null 2>&1; then
    echo "Role '$ROLE_NAME' already exists. Skipping."
    exit 0
fi

# Generate color - only ban white and black, blue is allowed
RAW_COLOR=$(printf "#%06x" $((RANDOM*RANDOM % 0xFEFEFE + 0x010101)))

# Only force purple for forbidden white/black
case "$RAW_COLOR" in
    "#FFFFFF"|"#000000")
        HEX_COLOR="#A020F0"
        ;;
    *)
        HEX_COLOR="$RAW_COLOR"  # Keep original color, blue is fine
        ;;
esac

COLOR_CODE="COLOR_$(echo "$ROLE_NAME" | tr '[:lower:]' '[:upper:]' | tr -d ' -')_$RANDOM"

# Add new role
jq ". + [{\"role\": \"$ROLE_NAME\", \"category\": \"$CATEGORY\", \"color_code\": \"$COLOR_CODE\", \"hex_value\": \"$HEX_COLOR\", \"hierarchy\": \"$HIERARCHY\", \"source_type\": \"dynamic\", \"app_linked\": \"$ROLE_NAME\", \"install_hook\": \"hook_${ROLE_NAME}_installed\"}]" "$SCHEMA_PATH" > "${SCHEMA_PATH}.tmp" && mv "${SCHEMA_PATH}.tmp" "$SCHEMA_PATH"

echo "✅ Role '$ROLE_NAME' registered with color $HEX_COLOR"
EOF
    chmod +x "$INSTALL_HOOK"
    success "install_hook.sh created."
}

generate_bash_aliases() {
    info "Generating .bash_aliases..."
    cat > "$BASH_ALIASES" <<'EOF'
# ~/.bash_aliases - Complete alias system

# -----------------------
# Core System Aliases
# -----------------------
alias please='sudo'
alias ll='ls -alF --color=auto'
alias la='ls -A --color=auto'
alias l='ls -CF --color=auto'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias cls='clear'
alias reload='source ~/.bashrc'

# -----------------------
# Git Shortcuts
# -----------------------
alias gs='git status'
alias ga='git add .'
alias gc='git commit -m'
alias gp='git push'
alias gpl='git pull'
alias gco='git checkout'
alias gbr='git branch'
alias glog='git log --oneline --graph --decorate'

# -----------------------
# Terraform Shortcuts
# -----------------------
alias tf='terraform'
alias tfi='terraform init'
alias tfp='terraform plan'
alias tfa='terraform apply'
alias tfaa='terraform apply -auto-approve'
alias tfd='terraform destroy'
alias tfda='terraform destroy -auto-approve'
alias tfo='terraform output'
alias tfv='terraform validate'
alias tfs='terraform show'

# -----------------------
# Python Development
# -----------------------
alias python='python3'
alias pip='pip3'
alias pipup='pip install --upgrade pip setuptools wheel'

# -----------------------
# System Monitoring
# -----------------------
alias ports='sudo netstat -tuln'
alias myip='curl -s ifconfig.me'
alias diskspace='df -h'
alias meminfo='free -h'

# -----------------------
# Color System Aliases
# -----------------------
alias colorreload='source $HOME/ctl_environment/colors.source.sh'
alias colortest='color_apply warnings "Warning test" && color_apply success "Success test" && color_apply errors "Error test" && color_apply files "Blue file test"'
alias colorroles='cat $HOME/.color_roles.json | jq ".[].role"'

# -----------------------
# Utility Functions
# -----------------------

# Make directory and cd into it
mkcd() {
    mkdir -p "$1" && cd "$1"
}

# Extract various archive formats
extract() {
    if [ -f "$1" ]; then
        case "$1" in
            *.tar.bz2)   tar xjf "$1" ;;
            *.tar.gz)    tar xzf "$1" ;;
            *.bz2)       bunzip2 "$1" ;;
            *.rar)       unrar x "$1" ;;
            *.gz)        gunzip "$1" ;;
            *.tar)       tar xf "$1" ;;
            *.tbz2)      tar xjf "$1" ;;
            *.tgz)       tar xzf "$1" ;;
            *.zip)       unzip "$1" ;;
            *.Z)         uncompress "$1" ;;
            *.7z)        7z x "$1" ;;
            *)           echo "'$1' cannot be extracted" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

# Python virtual environment
venv() {
    python3 -m venv venv && source venv/bin/activate
}
EOF
    success ".bash_aliases created."
}

generate_documentation() {
    info "Generating color-enforcement.md..."
    cat > "$DOC_FILE" <<'EOF'
# Color Enforcement Documentation

## Purpose
Enforces consistent color usage across the ctl_environment system with strict rules:
- No pure white (#FFFFFF) 
- No pure black (#000000)
- Blue colors are allowed and preserved

## Color Mappings
- **Directory/Prompt**: Purple (#A020F0)
- **Files**: Blue (#1E90FF)
- **Scripts**: Royal Blue (#4169E1)
- **Links**: Cyan (#00CED1) 
- **Errors**: Red (#FF0000)
- **Warnings**: Yellow (#FFFF00)
- **Success**: Green (#00FF00)

## Usage
```bash
# Apply colors to text
color_apply errors "Error message"
color_apply warnings "Warning message" 
color_apply success "Success message"

# Register new application
~/ctl_environment/install_hook.sh nginx infrastructure parent
```

## Files
- `color_roles.json` - Active color schema
- `color-laws.json` - Enforcement rules (only white/black banned)
- `colors.source.sh` - Runtime color functions
- `install_hook.sh` - App registration tool
EOF
    success "color-enforcement.md created."
}

create_symlink() {
    info "Creating symlink ~/.color_roles.json..."
    ln -sf "$COLOR_ROLES" "$SYMLINK"
    success "Symlink created."
}

update_bashrc() {
    info "Updating .bashrc..."
    
    # Add color system loader
    if ! grep -q "ctl_environment/colors.source.sh" "$BASHRC"; then
        {
            echo ""
            echo "# Color Role System"
            echo "source \$HOME/ctl_environment/colors.source.sh"
        } >> "$BASHRC"
        success "Color system loader added to .bashrc"
    else
        info "Color system loader already in .bashrc"
    fi
    
    # Add aliases loader
    if ! grep -q "bash_aliases" "$BASHRC"; then
        {
            echo ""
            echo "# Load custom aliases"
            echo "if [ -f ~/.bash_aliases ]; then"
            echo "    . ~/.bash_aliases"
            echo "fi"
        } >> "$BASHRC"
        success "Aliases loader added to .bashrc"
    else
        info "Aliases loader already in .bashrc"
    fi
}

verify_installation() {
    info "Verifying installation..."
    local errors=0
    
    # Check files exist
    for file in "$COLOR_ROLES" "$COLOR_LAWS" "$COLORS_SOURCE" "$INSTALL_HOOK" "$DOC_FILE" "$BASH_ALIASES"; do
        if [ ! -f "$file" ]; then
            error "Missing: $file"
            ((errors++))
        fi
    done
    
    # Check symlink
    if [ ! -L "$SYMLINK" ]; then
        error "Missing symlink: $SYMLINK"
        ((errors++))
    fi
    
    # Validate JSON
    if ! jq empty "$COLOR_ROLES" 2>/dev/null; then
        error "Invalid JSON: color_roles.json"
        ((errors++))
    fi
    
    if ! jq empty "$COLOR_LAWS" 2>/dev/null; then
        error "Invalid JSON: color-laws.json"
        ((errors++))
    fi
    
    # Check for forbidden colors (only white and black)
    if jq -e '.[] | select(.hex_value=="#FFFFFF" or .hex_value=="#000000")' "$COLOR_ROLES" >/dev/null 2>&1; then
        error "Found forbidden white or black colors"
        ((errors++))
    fi
    
    # Verify color correctness
    local warning_color=$(jq -r '.[] | select(.role=="warnings") | .hex_value' "$COLOR_ROLES")
    local error_color=$(jq -r '.[] | select(.role=="errors") | .hex_value' "$COLOR_ROLES")
    
    if [ "$warning_color" != "#FFFF00" ]; then
        error "Warnings should be yellow, found: $warning_color"
        ((errors++))
    fi
    
    if [ "$error_color" != "#FF0000" ]; then
        error "Errors should be red, found: $error_color"
        ((errors++))
    fi
    
    if [ $errors -eq 0 ]; then
        success "Installation verified successfully!"
        success "✓ No forbidden colors found (only white/black banned)"
        success "✓ Blue colors are allowed and preserved"
        success "✓ Warnings are yellow, errors are red"
        return 0
    else
        error "Verification failed with $errors errors"
        return 1
    fi
}

show_completion() {
    echo ""
    echo "=========================================="
    success "Installation Complete!"
    echo "=========================================="
    echo ""
    info "Color Rules Enforced:"
    echo "  ✓ No white (#FFFFFF) or black (#000000)"
    echo "  ✓ Blue colors are allowed and preserved"
    echo "  ✓ Warnings are yellow (#FFFF00)"
    echo "  ✓ Errors are red (#FF0000)"
    echo ""
    info "Next Steps:"
    echo "  1. Reload shell: source ~/.bashrc"
    echo "  2. Test colors: colortest"
    echo "  3. View roles: colorroles"
    echo "  4. Add app: ~/ctl_environment/install_hook.sh <name> <category> <hierarchy>"
    echo ""
    info "Log file: $LOG_FILE"
    echo ""
}

# ---------- MAIN EXECUTION ----------

main() {
    echo "=========================================="
    info "Color Module & Aliases Installer"
    echo "=========================================="
    
    setup_logging
    check_dependencies
    create_directories
    generate_color_roles
    generate_color_laws
    generate_colors_source
    generate_install_hook
    generate_bash_aliases
    create_symlink
    update_bashrc
    
    if verify_installation; then
        show_completion
    else
        error "Installation failed verification"
        exit 1
    fi
}

main "$@"
