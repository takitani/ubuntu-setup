# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Ubuntu 25 + GNOME post-installation script project, inspired by the Arch Linux + Hyprland exarch-setup. The repository contains a single main shell script that automates system setup and configuration tasks for Ubuntu with GNOME desktop environment.

## Development Principles

### Script Safety and Idempotency
The post-install script MUST follow these critical principles:

1. **Always backup before modifying**: Before modifying any existing configuration file, create a backup with a descriptive suffix using the `create_backup()` function
2. **Idempotent operations**: The script must be safe to run multiple times without causing errors or duplicate configurations
3. **Check before applying**: Always verify if a configuration has already been applied before attempting to apply it
4. **Non-destructive**: Never overwrite user customizations unnecessarily
5. **Graceful failure handling**: Use conditional checks and `|| true` where appropriate to prevent script termination on non-critical failures

### Implementation patterns to follow:
- Use `create_backup()` function for consistent backups
- Use `gsettings get` to check current values before setting new ones
- Use `--needed` flag with package managers to avoid reinstalling
- Check if commands/applications exist before attempting operations
- Wrap potentially failing commands with proper error handling
- Provide clear feedback about what was done vs. what was already configured

## Architecture

The project consists of:
- `post-install.sh`: Main bash script that handles system updates, application installation, locale configuration, and GNOME desktop setup
- `README.md`: Comprehensive documentation for users
- `CLAUDE.md`: This development guidance file

## Key Functions

The post-install script provides these main functions:
- `update_system()`: Updates system packages using apt
- `setup_repositories()`: Configures universe/multiverse repos and Flatpak/Snap
- `install_desktop_apps()`: Installs desktop applications via various methods (apt, flatpak, snap, direct download)
- `set_locale_ptbr()`: Configures Brazilian Portuguese locale with English interface
- `configure_keyboard_layout()`: Sets up US International + BR keyboard layouts with cedilla support
- `configure_gnome_settings()`: Applies GNOME desktop preferences via gsettings
- `configure_gnome_extensions()`: Installs and configures GNOME extensions
- `configure_autostart()`: Sets up application autostart and dock favorites

## Development Commands

Since this is a shell script project, development primarily involves:
- Running the script: `./post-install.sh`
- Testing with options: `./post-install.sh --no-flatpak --no-snap`
- Checking syntax: `bash -n post-install.sh`
- Testing individual functions (source the script and call functions)

## Configuration Details

### Ubuntu/GNOME specific configurations:
- **Package management**: Uses `apt` for system packages, `flatpak` for some apps, `snap` for others
- **Desktop settings**: Uses `gsettings` to configure GNOME preferences
- **Keyboard layouts**: Uses `gsettings` for input sources (replaces Hyprland's kb_* settings)
- **Extensions**: Installs via package manager and enables via `gnome-extensions` command
- **Autostart**: Uses `.desktop` files in `~/.config/autostart/`

### Files modified:
- `/etc/locale.gen` for locale configuration
- `~/.XCompose` and `~/.config/gtk-3.0/Compose` for cedilla support
- `~/.config/autostart/*.desktop` for application autostart
- GNOME settings via gsettings (no direct file modification)

### Key differences from Arch version:
- Package manager: `yay` → `apt` + `flatpak` + `snap`
- Desktop environment: Hyprland → GNOME
- Configuration method: Direct config files → `gsettings` + some config files
- Extensions: Manual config → GNOME Extensions system

## Application Installation Methods

The script uses multiple installation methods:
1. **APT packages**: System tools, official repositories
2. **Official .deb packages**: Chrome, VS Code (with repository setup)
3. **Flatpak**: Discord (cross-platform apps)
4. **Snap**: Slack (when Flatpak not preferred)
5. **Direct download**: JetBrains Toolbox, Cursor IDE

Each method includes existence checks to avoid reinstallation and proper error handling.

## Testing and Validation

When modifying the script:
1. Test on a clean Ubuntu 25 installation
2. Run the script multiple times to verify idempotency
3. Check that all backups are created properly
4. Verify that configurations are applied correctly
5. Test with different option flags
6. Ensure graceful handling of missing dependencies or network issues