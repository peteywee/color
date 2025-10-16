#!/usr/bin/env bash
set -Eeuo pipefail

# install_aliases.sh
# Idempotently installs/updates a managed aliases block (cache wizard + safe docker cleaners)
# and ensures ~/.bashrc sources ~/.bash_aliases. Safe on Debian/Ubuntu/Crostini.

ALIASES_FILE="${HOME}/.bash_aliases"
BASHRC_FILE="${HOME}/.bashrc"
PROFILE_FILE="${HOME}/.profile"

echo "⏳ Installing managed aliases into ${ALIASES_FILE}"

mkdir -p "$(dirname "${ALIASES_FILE}")"
touch "${ALIASES_FILE}"

# 1) Ensure ~/.bashrc sources ~/.bash_aliases (append once if missing)
if ! grep -qE '^\s*(\.|source)\s+\$HOME/\.bash_aliases\b' "${BASHRC_FILE}" 2>/dev/null; then
  cat <<'RC' >> "${BASHRC_FILE}"

# --- Aliases loader (managed) ---
if [ -f "$HOME/.bash_aliases" ]; then
  . "$HOME/.bash_aliases"
fi
# --- end aliases loader ---
RC
  echo "✅ Added aliases loader to ${BASHRC_FILE}"
else
  echo "✅ ${BASHRC_FILE} already loads ~/.bash_aliases"
fi

# 2) (Optional) Load color helpers if you use them and they exist
if [ -f "$HOME/ctl_environment/colors.source.sh" ] && ! grep -q 'ctl_environment/colors.source.sh' "${BASHRC_FILE}" 2>/dev/null; then
  cat <<'RC' >> "${BASHRC_FILE}"

# --- Color helpers loader (optional, managed) ---
if [ -f "$HOME/ctl_environment/colors.source.sh" ]; then
  . "$HOME/ctl_environment/colors.source.sh"
fi
# --- end color helpers loader ---
RC
  echo "✅ Added color helpers loader to ${BASHRC_FILE}"
fi

# 3) Ensure login shells pull in .bashrc (good hygiene on Debian/Crostini)
if ! grep -q 'source ~/.bashrc' "${PROFILE_FILE}" 2>/dev/null; then
  cat <<'PR' >> "${PROFILE_FILE}"

# Load interactive shell config
if [ -n "$BASH_VERSION" ] && [ -f "$HOME/.bashrc" ]; then
  . "$HOME/.bashrc"
fi
PR
  echo "✅ Ensured ${PROFILE_FILE} sources ${BASHRC_FILE}"
fi

# 4) Remove any previous managed blocks and append the latest one
#    (Covers older docker-clean block name and current cache-clean block name)
sed -i '/^# --- docker-clean aliases (managed) ---$/,/^# --- end docker-clean aliases ---$/d' "${ALIASES_FILE}" || true
sed -i '/^# --- cache-clean (managed) ---$/,/^# --- end cache-clean ---$/d' "${ALIASES_FILE}" || true

cat <<'EOF' >> "${ALIASES_FILE}"
# --- cache-clean (managed) ---
# Safe, preview-first cache cleaning utilities with an interactive wizard.
# Also includes safer Docker clean helpers (drma/drima) and dclean alias.

# Clear old definitions to avoid collisions
unalias cacheclean 2>/dev/null || true
unalias cachepreview 2>/dev/null || true
unalias cclean 2>/dev/null || true
unalias cpreview 2>/dev/null || true
unalias cwizard 2>/dev/null || true
unalias drma 2>/dev/null || true
unalias drima 2>/dev/null || true
unalias dclean 2>/dev/null || true

# Safer Docker "remove all" helpers (only run if there are resources)
drma() { ids=$(docker ps -aq 2>/dev/null || true); [ -n "$ids" ] && docker rm $ids || true; }
drima() { ids=$(docker images -q 2>/dev/null || true); [ -n "$ids" ] && docker rmi $ids || true; }
alias dclean='drma && drima'

_cache_cmd_exists(){ command -v "$1" >/dev/null 2>&1; }

_yesno(){
  # Usage: _yesno "Prompt?" (default=N)
  read -r -p "${1:-Proceed?} [y/N]: " reply
  case "$reply" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

# ---------- Docker ----------
_cache_preview_docker(){
  _cache_cmd_exists docker || { echo "docker not found"; return 0; }
  echo "== Docker disk usage (current) =="; docker system df || true
  echo "-- Exited containers --"; docker ps -a -f status=exited --format '{{.ID}}\t{{.Image}}\t{{.Names}}' || true
  echo "-- Dangling images --"; docker images -f dangling=true --format '{{.ID}}\t{{.Repository}}:{{.Tag}}\t{{.Size}}' || true
  echo "-- Unused networks --"; docker network ls -f "dangling=true" || true
  echo "-- Builders --"; docker builder ls 2>/dev/null || true
}

_cache_clean_docker(){
  # $1: --aggressive|"" ; aggressive prompts for extra steps (all images, builder, volumes)
  _cache_cmd_exists docker || return 0
  echo "Docker: pruning stopped containers, dangling images, unused networks (safe)."
  docker container prune -f || true
  docker image prune -f || true
  docker network prune -f || true
  if [ "${1:-}" = "--aggressive" ]; then
    echo "Docker: AGGRESSIVE - pruning ALL unused images (-a) and builder cache."
    docker image prune -a -f || true
    docker builder prune -a -f 2>/dev/null || docker builder prune -f 2>/dev/null || true
    if _yesno "AGGRESSIVE: also prune UNUSED VOLUMES? (data may be lost)"; then
      docker volume prune -f || true
    fi
  fi
}

# ---------- Node (pnpm/npm) ----------
_cache_preview_node(){
  if _cache_cmd_exists pnpm; then
    store="$(pnpm store path 2>/dev/null || true)"
    [ -n "$store" ] && { echo "pnpm store: $store"; du -sh "$store" 2>/dev/null || true; }
  fi
  if _cache_cmd_exists npm; then
    npmc="$(npm config get cache 2>/dev/null || true)"
    [ -n "$npmc" ] && { echo "npm cache: $npmc"; du -sh "$npmc" 2>/dev/null || true; }
  fi
}

_cache_clean_node(){
  if _cache_cmd_exists pnpm; then
    echo "pnpm: pruning store..."; pnpm store prune || true
  fi
  if _cache_cmd_exists npm; then
    npm cache verify 2>/dev/null || true
    _yesno "Clean npm cache?" && npm cache clean --force || true
  fi
}

# ---------- Python (pip) ----------
_cache_preview_python(){
  if _cache_cmd_exists pip; then
    pdir="$(pip cache dir 2>/dev/null || true)"
    [ -n "$pdir" ] && { echo "pip cache: $pdir"; du -sh "$pdir" 2>/dev/null || true; }
  fi
}

_cache_clean_python(){
  if _cache_cmd_exists pip; then
    _yesno "Purge pip cache?" && pip cache purge || true
  fi
}

# ---------- APT ----------
_cache_preview_apt(){
  if [ -d /var/cache/apt/archives ]; then
    echo "/var/cache/apt/archives size:"
    (sudo du -sh /var/cache/apt/archives 2>/dev/null || du -sh /var/cache/apt/archives 2>/dev/null) || true
  fi
  echo "-- Simulated autoremove (preview) --"
  sudo apt-get -s autoremove 2>/dev/null | sed -n '1,120p' || true
}

_cache_clean_apt(){
  # $1: "autoremove" to also autoremove
  _yesno "Clean APT caches (autoclean + clean)?" || return 1
  sudo apt-get autoclean -y || true
  sudo apt-get clean || true
  if [ "${1:-}" = "autoremove" ]; then
    _yesno "Also autoremove unused packages (purge)?" && sudo apt-get autoremove --purge -y || true
  fi
}

# ---------- Journald ----------
_cache_preview_journal(){
  journalctl --disk-usage 2>/dev/null || true
}

_cache_clean_journal(){
  # $1: retention window (e.g., 7d, 14d)
  local window="${1:-14d}"
  _yesno "Vacuum journal logs to last ${window}?" || return 1
  sudo journalctl --vacuum-time="$window" || true
}

# ---------- Non-interactive entrypoints ----------
cachepreview(){
  case "${1:-all}" in
    docker)  _cache_preview_docker ;;
    node)    _cache_preview_node ;;
    python)  _cache_preview_python ;;
    apt)     _cache_preview_apt ;;
    journal) _cache_preview_journal ;;
    all|*)   _cache_preview_docker; _cache_preview_node; _cache_preview_python; _cache_preview_apt; _cache_preview_journal ;;
  esac
}

cacheclean(){
  mode="${1:-all}"; shift || true
  case "$mode" in
    docker)  _cache_clean_docker "$@" ;;
    node)    _cache_clean_node ;;
    python)  _cache_clean_python ;;
    apt)     _cache_clean_apt "autoremove" ;;
    journal) _cache_clean_journal "7d" ;;
    all|*)   _cache_clean_docker "$@"; _cache_clean_node; _cache_clean_python; _cache_clean_apt "autoremove"; _cache_clean_journal "7d" ;;
  esac
}

# ---------- Interactive wizard ----------
cachewizard(){
  local opts=(docker node python apt journal)
  local map=("docker" "node" "python" "apt" "journal")
  local sel=()

  echo "Select caches to manage:"
  for i in "${!opts[@]}"; do printf "  %d) %s\n" "$((i+1))" "${opts[$i]}"; done
  echo "Type numbers separated by spaces, or 'all'."
  read -r -p "Selection [all]: " choice

  if [ -z "$choice" ] || [ "$choice" = "all" ]; then
    sel=("${opts[@]}")
  else
    for tok in $choice; do
      case "$tok" in
        all|ALL) sel=("${opts[@]}"); break ;;
        ''|*[!0-9]*) echo "Ignoring invalid token: $tok" >&2 ;;
        *) idx=$((tok-1)); [ $idx -ge 0 ] && [ $idx -lt ${#opts[@]} ] && sel+=("${map[$idx]}") || echo "Out of range: $tok" >&2 ;;
      esac
    done
    # de-dup
    if [ "${#sel[@]}" -gt 1 ]; then
      local tmp=() seen=""
      for s in "${sel[@]}"; do
        case " $seen " in *" $s "*) :;; *) tmp+=("$s"); seen="$seen $s";; esac
      done
      sel=("${tmp[@]}")
    fi
  fi

  if [ "${#sel[@]}" -eq 0 ]; then
    echo "No valid selections. Exiting."
    return 1
  fi

  echo
  echo "=== PREVIEW (${sel[*]}) ==="
  for s in "${sel[@]}"; do
    echo "---- $s ----"
    cachepreview "$s"
    echo
  done

  echo "After preview: choose next action."
  echo "  1) Clean now"
  echo "  2) Exit without changes"
  read -r -p "Choice [2]: " next
  [ "${next:-2}" = "1" ] || { echo "Aborted."; return 0; }

  # Pre-clean options
  local docker_mode=""  # "" or --aggressive
  local apt_mode=""     # "" or autoremove
  local journal_window="7d"

  case " ${sel[*]} " in *" docker "*) _yesno "Use AGGRESSIVE Docker cleanup? (all unused images + builder; volumes on extra confirm)" && docker_mode="--aggressive" ;; esac
  case " ${sel[*]} " in *" apt "*) _yesno "Include APT autoremove (purge)?" && apt_mode="autoremove" ;; esac
  case " ${sel[*]} " in *" journal "*) _yesno "Vacuum journald to last ${journal_window}?" || journal_window="" ;; esac

  echo
  echo "=== CLEANING (${sel[*]}) ==="
  for s in "${sel[@]}"; do
    echo "---- $s ----"
    case "$s" in
      docker)  _cache_clean_docker "$docker_mode" ;;
      node)    _cache_clean_node ;;
      python)  _cache_clean_python ;;
      apt)     _cache_clean_apt "$apt_mode" ;;
      journal) [ -n "$journal_window" ] && _cache_clean_journal "$journal_window" || echo "Skipped journald." ;;
    esac
    echo
  done

  echo "Done."
}

# Convenience aliases
alias cpreview='cachepreview'
alias cclean='cacheclean'
alias cwizard='cachewizard'
# --- end cache-clean ---
EOF

echo "✅ Managed alias block installed."

# 5) Reload current shell (best effort)
# shellcheck disable=SC1090
if [ -f "${BASHRC_FILE}" ]; then
  . "${BASHRC_FILE}" || true
fi

# 6) Verification
echo "🔎 Verifying..."
type cachewizard >/dev/null 2>&1 && echo " - cachewizard ✅" || echo " - cachewizard ❌"
type cachepreview >/dev/null 2>&1 && echo " - cachepreview ✅" || echo " - cachepreview ❌"
type cacheclean  >/dev/null 2>&1 && echo " - cacheclean  ✅" || echo " - cacheclean  ❌"
alias dclean >/dev/null 2>&1 && echo " - dclean alias ✅" || echo " - dclean alias ❌"

echo "🎉 Finished."
