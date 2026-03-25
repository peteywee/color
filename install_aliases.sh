#!/bin/bash
# Backward-compatibility wrapper for legacy alias installs.
# The installer surface was unified into install.sh.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"

cat <<'MSG'
[INFO] install_aliases.sh is deprecated.
[INFO] Alias installation is now handled by install.sh.
[INFO] Running the unified installer with nano syntax disabled.
MSG

exec "$SCRIPT_DIR/install.sh" --skip-nano "$@"
