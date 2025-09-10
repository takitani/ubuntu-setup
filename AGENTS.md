# Repository Guidelines

## Project Structure & Module Organization
- Root contains Bash scripts: `post-install.sh` (main), `clean-snaps.sh` (Snap cleanup), and examples like `exemplo.sh`.
- Docs and meta live in `README.md` and `CLAUDE.md`; auxiliary config in `.claude/`.
- No build artifacts or test harness are present; scripts are intended to run directly.

## Build, Test, and Development Commands
- Run locally: `./post-install.sh` or view options with `./post-install.sh --help`.
- Snap cleanup: `./clean-snaps.sh`.
- Syntax check: `bash -n post-install.sh clean-snaps.sh`.
- Lint (recommended): `shellcheck post-install.sh clean-snaps.sh`.
- Format (recommended): `shfmt -w -i 2 -bn -ci .`.

## Coding Style & Naming Conventions
- Shebang: `#!/usr/bin/env bash`; require Bash 5+; start scripts with `set -euo pipefail`.
- Indentation: 2 spaces; max 100 cols; use double quotes by default.
- Naming: `snake_case` for variables and functions. Installers follow `install_<name>()`.
- Logging: prefer existing helpers `print_info`, `print_warn`, `print_error`, `print_step`.
- Structure: place small helper functions above `main`; keep entrypoint as `main` and call it at end.

## Testing Guidelines
- Target Ubuntu 25 + GNOME. Validate idempotency: run scripts twice without errors.
- Prefer non-destructive changes; use `create_backup <path> [suffix]` before modifying files.
- Quick checks: `bash -n`, `shellcheck`, and `./post-install.sh --help`.
- When adding installers or settings, document steps in `README.md` and verify with `gsettings` or CLI checks.

## Commit & Pull Request Guidelines
- Commit style: imperative, present tense, concise summary (≤72 chars).
  - Example: `Add Discord install with Flatpak fallback`
- Include focused diffs; avoid unrelated formatting churn.
- PRs must include: purpose, summary of changes, test notes (commands run, outputs), and any screenshots/log snippets when UI changes apply.
- Link related issues and note impacts (dependencies, reboots required, security considerations).

## Security & Configuration Tips
- Do not run as root; use `sudo` within commands as in current scripts.
- Guard network/download steps with retries and checksums when possible; avoid silent failures.
- Prefer official repositories; use `signed-by` and keyrings for APT sources.
- Clearly prompt before destructive actions; provide `--no-*` flags and safe defaults.

