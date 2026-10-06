#!/usr/bin/env bash
#
# CachyOS Hyprland + Noctalia installer
#
# Usage (from a TTY):
#   curl -fsSL https://raw.githubusercontent.com/fabcard/cachyos-hyprland-noctalia/main/install.sh | bash
#
# Built and tested on CachyOS (no desktop). Other Arch-based systems may work.
#
# Environment variables:
#   CHN_REF=<ref>      Branch, tag or commit to download through curl (default: main)
#   CHN_DEFAULTS=1     Never prompt, use the default answer for every question

# Variables set here are read by the modules that install.sh sources.
# shellcheck disable=SC2034
set -euo pipefail

REPO_OWNER="fabcard"
REPO_NAME="cachyos-hyprland-noctalia"
REPO_REF="${CHN_REF:-main}"
TARBALL_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}/archive/${REPO_REF}.tar.gz"

# Answers collected by ask_options, used by the modules.
INSTALL_BLUETOOTH=0
INSTALL_SMB=0
INSTALL_WALLPAPERS=0
INSTALL_GREETER_SYNC=0

SCRIPT_DIR=""

resolve_script_dir() {
  local script_path="${BASH_SOURCE[0]:-}"
  if [[ -n "$script_path" && -f "$script_path" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "$script_path")" && pwd)"
    [[ -f "$SCRIPT_DIR/scripts/lib.sh" ]] || SCRIPT_DIR=""
  fi
}

# When run through "curl | bash", stdin is the script itself. Download the
# whole repository, then run the real installer with stdin attached to the
# terminal so every prompt (including sudo and pacman) works.
bootstrap() {
  local tmp status=0

  command -v curl >/dev/null 2>&1 || { echo "curl is required." >&2; exit 1; }
  command -v tar >/dev/null 2>&1 || { echo "tar is required." >&2; exit 1; }

  tmp="$(mktemp -d)"
  echo "Downloading ${REPO_NAME} (${REPO_REF})..."
  if ! curl -fsSL "$TARBALL_URL" | tar -xz -C "$tmp" --strip-components=1; then
    rm -rf "$tmp"
    echo "Download failed: $TARBALL_URL" >&2
    exit 1
  fi

  if { : </dev/tty; } 2>/dev/null; then
    bash "$tmp/install.sh" "$@" </dev/tty || status=$?
  else
    bash "$tmp/install.sh" "$@" || status=$?
  fi

  rm -rf "$tmp"
  exit "$status"
}

load_module() {
  local file="$SCRIPT_DIR/scripts/$1.sh"
  if [[ ! -f "$file" ]]; then
    echo "Missing module: $file" >&2
    exit 1
  fi
  # shellcheck source=/dev/null
  source "$file"
}

banner() {
  printf '\n%sCachyOS Hyprland + Noctalia installer%s\n' "$C_BOLD" "$C_RESET"
  echo "Installs Hyprland, Noctalia Shell and Noctalia Greeter with a lean default setup."
  echo "Built and tested on CachyOS (no desktop selected in the installer)."
  echo
}

ask_options() {
  step "Options"
  if ask_yes_no "Install Bluetooth packages and enable the service?" n; then
    INSTALL_BLUETOOTH=1
  fi
  if ask_yes_no "Install network share (SMB) support for Nautilus?" n; then
    INSTALL_SMB=1
  fi
  if ask_yes_no "Download the wallpaper pack to ~/Pictures/Wallpapers?" n; then
    INSTALL_WALLPAPERS=1
  fi

  info "Syncing the login screen runs a fixed helper as root. A polkit rule can allow it for your user without a password."
  if ask_yes_no "Sync wallpaper and colors to the login screen without a password prompt?" n; then
    INSTALL_GREETER_SYNC=1
  fi
}

finish() {
  step "Done"
  ok "Installation finished."
  if [[ -n "${BACKUP_DIR:-}" ]]; then
    info "Previous config files were backed up to: $BACKUP_DIR"
  fi
  info "Reboot to start the Noctalia Greeter, then pick the Hyprland (UWSM) session."
  if ask_yes_no "Reboot now?" y; then
    sudo systemctl reboot
  fi
}

main() {
  resolve_script_dir
  if [[ -z "$SCRIPT_DIR" ]]; then
    bootstrap "$@"
    return
  fi

  load_module lib
  trap stop_sudo_keepalive EXIT

  banner
  require_not_root
  check_distro
  check_internet
  check_sudo
  check_existing_desktop
  ask_options

  load_module packages
  load_module services
  load_module configs
  load_module wallpapers

  install_packages
  enable_services
  install_configs
  if [[ "$INSTALL_WALLPAPERS" == "1" ]]; then
    install_wallpapers
  fi

  finish
}

main "$@"
