# Repository Guidelines

## Project Structure & Module Organization
- Root contains Bash scripts: `post-install.sh` (main setup), `clean-snaps.sh` (Snap cleanup) and examples like `exemplo.sh`.
- Docs live in `README.md` and `CLAUDE.md`; auxiliary config in `.claude/`.
- No build system or test harness; scripts run directly on Ubuntu.

## Build, Test, and Development Commands
- Run locally: `./post-install.sh` (see options with `./post-install.sh --help`).
- Snap cleanup: `./clean-snaps.sh`.
- Syntax check: `bash -n post-install.sh clean-snaps.sh`.
- Lint: `shellcheck post-install.sh clean-snaps.sh`.
- Format: `shfmt -w -i 2 -bn -ci .`.

## Coding Style & Naming Conventions
- Shebang `#!/usr/bin/env bash`; require Bash 5+; start with `set -euo pipefail`.
- Indentation 2 spaces; max line length 100; prefer double quotes.
- Naming: `snake_case` for vars/functions; installers as `install_<name>()`.
- Logging: use `print_info`, `print_warn`, `print_error`, `print_step`.
- Structure: helpers above `main`; entrypoint is `main` and called at file end.

## Testing Guidelines
- Target Ubuntu 25 (plucky) + GNOME; ensure idempotency (run twice without errors).
- Prefer non-destructive changes; call `create_backup <path> [suffix]` before edits.
- Quick checks: `bash -n`, `shellcheck`, `./post-install.sh --help`.
- Verify settings via `gsettings` or CLI checks when adding installers/config.
- APT sources: prefer modern `ubuntu.sources`; avoid duplicating entries in `/etc/apt/sources.list`.

## Commit & Pull Request Guidelines
- Commits: imperative, present tense, ≤72 chars (e.g., `Add Discord install with Flatpak fallback`).
- Keep diffs focused; avoid unrelated formatting churn.
- PRs include purpose, summary, test notes (commands + outputs), and screenshots/logs for UI changes.
- Link issues and note impacts (deps, reboots, security considerations).

## Security & Configuration Tips
- Do not run as root; use `sudo` within commands.
- Prefer official repositories; use `signed-by` and keyrings for APT.
- Backups of APT files go to `/var/backups/ubuntu-setup/` (keep `/etc/apt` clean).
- Prompt before destructive actions; offer `--no-*` flags and safe defaults.
