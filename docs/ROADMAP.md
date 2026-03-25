# Color System Modernization Roadmap

## Goal
Evolve the repository from a single-user shell installer into a modular configuration runtime package with clear source/runtime separation, stronger validation, and reproducible machine bootstrap behavior.

## Workstreams

### 1. Installer surface
- Keep `install.sh` as the unified installer.
- Preserve backward compatibility with wrapper entrypoints.
- Add task-specific wrappers for core, aliases, prompt, nano, and runtime migration.
- Keep all wrappers idempotent and safe to re-run.

### 2. Runtime separation
- Keep the source repository wherever the user clones it.
- Move deployed runtime assets into `~/.local/share/tss/color` by default.
- Preserve `~/ctl_environment` as a compatibility symlink.
- Export `COLOR_RUNTIME_HOME` for downstream tooling.

### 3. Governance and validation
- Add validation tooling for:
  - duplicate roles
  - duplicate hex values
  - invalid hex strings
  - forbidden pure white/pure black assignments
  - missing required roles
- Fail closed for invalid schema.

### 4. Modular shell features
- Treat aliases, prompt, nano syntax, and core runtime as separate install concerns.
- Keep wrappers simple so machine bootstrap scripts can compose them.

### 5. Bootstrap orchestration
- Add a high-level bootstrap script that installs the modern runtime layout.
- Support forwarding installer flags to the unified installer.
- Keep user-facing output explicit and operational.

## Immediate Deliverables Added in This Phase
- `install_runtime.sh`
- `install_aliases.sh` compatibility wrapper
- `install_core.sh`
- `install_prompt.sh`
- `install_nano.sh`
- `bootstrap_color_env.sh`
- `validate_color_roles.sh`
- `docs/ROADMAP.md`

## Next Refactor Targets
- Fold runtime-dir support directly into `install.sh`
- Move prompt handling behind an explicit prompt module flag
- Update `README.md` to match the actual installer surface
- Teach `uninstall.sh` about the modern runtime location
