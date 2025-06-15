# ~/.bash_aliases
# Complete alias system for development workflow - Managed by install_aliases.sh

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
alias tfaauto='terraform apply -auto-approve'
alias tfd='terraform destroy'
alias tfda='terraform destroy -auto-approve'
alias tfo='terraform output'
alias tfv='terraform validate'
alias tfs='terraform show'
alias tfws='terraform workspace'

# -----------------------
# Python Development
# -----------------------

alias python='python3'
alias pip='pip3'
# The 'venv' alias/function has been removed due to potential shell conflicts.
# Manage your virtual environments directly with 'python3 -m venv <dir>' and 'source <dir>/bin/activate'.
alias pipup='pip install --upgrade pip setuptools wheel'

# -----------------------
# Docker Shortcuts
# -----------------------

alias d='docker'
alias dc='docker compose'
alias dcu='docker compose up -d'
alias dcd='docker compose down'
alias dcr='docker compose restart'
alias dcl='docker compose logs -f'
alias dcb='docker compose build'
alias di='docker images'
alias dps='docker ps'
alias dpsa='docker ps -a'
alias drma='docker rm $(docker ps -aq)' # Remove all stopped containers
alias drima='docker rmi $(docker images -q)' # Remove all images
alias dclean='drma && drima' # Clean up containers and images
alias dexec='docker exec -it' # Execute into a running container
alias dlogs='docker logs -f' # Follow logs of a container
alias dstopa='docker stop $(docker ps -aq)' # Stop all running containers

# -----------------------
# System Monitoring
# -----------------------

alias ports='sudo netstat -tuln'
alias myip='curl -s ifconfig.me'
alias diskspace='df -h'
alias meminfo='free -h'

# -----------------------
# Color System Aliases (Requires ctl_environment/colors.source.sh to be sourced in .bashrc)
# -----------------------

alias colorreload='source $HOME/ctl_environment/colors.source.sh'
alias colortest='color_apply warning "Warning test" && color_apply success "Success test" && color_apply error "Error test" && color_apply typescript "TS Test" && color_apply javascript "JS Test" && color_apply nodejs "Node Test"'
alias colorroles='cat $HOME/.color_roles.json | jq ".[].role"'

# -----------------------
# Directory and Navigation Helpers
# -----------------------

# mkcd function - make directory and cd into it
mkcd() {
    mkdir -p "$1" && cd "$1"
}

# extract function - extract various archive formats
extract() {
    if [ -f "$1" ]; then
        case "$1" in
            *.tar.bz2)   tar xjf "$1"     ;;
            *.tar.gz)    tar xzf "$1"     ;;
            *.bz2)       bunzip2 "$1"     ;;
            *.rar)       unrar x "$1"     ;;
            *.gz)        gunzip "$1"      ;;
            *.tar)       tar xf "$1"      ;;
            *.tbz2)      tar xjf "$1"     ;;
            *.tgz)       tar xzf "$1"     ;;
            *.zip)       unzip "$1"       ;;
            *.Z)         uncompress "$1"  ;;
            *.7z)        7z x "$1"        ;;
            *)           echo "'$1' cannot be extracted via extract()" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

# Find and kill process by name
killp() {
    ps aux | grep "$1" | grep -v grep | awk '{print $2}' | xargs kill -9
}
