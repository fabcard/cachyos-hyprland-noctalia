#!/usr/bin/env bash
# Package installation. Sourced by install.sh.
#
# Every package is looked up with "pacman -Si" first. Packages found in the
# repositories are installed with pacman. Packages that are not in any
# repository are only tried from the AUR when an AUR helper (shelly, paru or
# yay) already exists, and only after asking. No helper is ever installed.

# Variables set here are read by the other modules.
# shellcheck disable=SC2034
MIN_HYPRLAND_VERSION="0.55.0"

# A missing package from this list stops the installer.
REQUIRED_PKGS=(
  hyprland
  uwsm
  xdg-desktop-portal-hyprland
  xdg-desktop-portal-gtk
  noctalia
  greetd
  noctalia-greeter
  pipewire
  wireplumber
  pipewire-pulse
  networkmanager
  polkit
  grim
  slurp
  satty
  wl-clipboard
  gnome-keyring
  dconf
  kitty
  xdg-utils
)

# A missing package from this list only prints a warning.
OPTIONAL_PKGS=(
  nwg-look
  adw-gtk-theme
  adwaita-icon-theme
  breeze-icons
  qt6ct
  qt6-wayland
  nautilus
  loupe
  papers
  gnome-text-editor
  gnome-calculator
  decibels
  showtime
  brave-origin-bin
  gvfs
  gvfs-mtp
  udisks2
  exfatprogs
  ntfs-3g
  ttf-jetbrains-mono-nerd
  noto-fonts
  noto-fonts-emoji
  xdg-user-dirs-gtk
  hyprpicker
  btop
)

# Cursor theme: Bibata Modern Ice, from the upstream release (not in the repositories).
# It goes to /usr/share/icons. That folder is searched by every toolkit (Xcursor,
# GTK, Qt, Hyprland) and readable by every user, including the greeter, which
# runs as a different user. /usr/local/share/icons is NOT searched by Xcursor.
# If anything fails, Adwaita is used.
BIBATA_VERSION="v2.0.7"
BIBATA_URL="https://github.com/ful1e5/Bibata_Cursor/releases/download/${BIBATA_VERSION}/Bibata-Modern-Ice.tar.xz"
BIBATA_SHA256="a68cae60c4dc706350e194ebc91c5fe48bc7bc9d59e119555834a2a7ee5078ef" # SHA-256 of the v2.0.7 archive
CURSOR_SYSTEM_DIR="${CURSOR_SYSTEM_DIR:-/usr/share/icons}"
OLD_CURSOR_DIR="${OLD_CURSOR_DIR:-/usr/local/share/icons}" # used by an earlier version of this installer
CURSOR_THEME="Adwaita"
CURSOR_PATH="/usr/share/icons"

BLUETOOTH_PKGS=(bluez bluez-utils)
SMB_PKGS=(gvfs-smb)

REPO_PKGS=()
AUR_CANDIDATES=()
FAILED_REQUIRED=()
FAILED_OPTIONAL=()
AUR_HELPER=""

pkg_installed() { pacman -Q "$1" >/dev/null 2>&1; }
pkg_in_repos()  { pacman -Si "$1" >/dev/null 2>&1; }

# Usage: classify_pkg <package> <required|optional>
classify_pkg() {
  local pkg="$1" kind="$2"

  if pkg_installed "$pkg"; then
    return 0
  elif pkg_in_repos "$pkg"; then
    REPO_PKGS+=("$pkg")
  else
    AUR_CANDIDATES+=("${kind}:${pkg}")
  fi
}

detect_aur_helper() {
  local helper
  for helper in shelly paru yay; do
    if command -v "$helper" >/dev/null 2>&1; then
      AUR_HELPER="$helper"
      return 0
    fi
  done
  return 1
}

aur_install() {
  local pkg="$1"
  case "$AUR_HELPER" in
    shelly) shelly install aur "$pkg" --needed ;;
    paru|yay) "$AUR_HELPER" -S --needed "$pkg" ;;
    *) return 1 ;;
  esac
}

record_failure() {
  local kind="$1" pkg="$2"
  if [[ "$kind" == "required" ]]; then
    FAILED_REQUIRED+=("$pkg")
  else
    FAILED_OPTIONAL+=("$pkg")
  fi
}

install_aur_candidates() {
  local entry kind pkg names=()

  (( ${#AUR_CANDIDATES[@]} )) || return 0

  for entry in "${AUR_CANDIDATES[@]}"; do
    names+=("${entry#*:}")
  done
  warn "Not found in the configured repositories: ${names[*]}"

  if ! detect_aur_helper; then
    warn "No AUR helper found (shelly, paru or yay). These packages were skipped."
    for entry in "${AUR_CANDIDATES[@]}"; do
      record_failure "${entry%%:*}" "${entry#*:}"
    done
    return 0
  fi

  warn "AUR packages are not reviewed by the distribution. $AUR_HELPER will show each PKGBUILD for review."
  if ! ask_yes_no "Try to install them from the AUR with $AUR_HELPER?" n; then
    for entry in "${AUR_CANDIDATES[@]}"; do
      record_failure "${entry%%:*}" "${entry#*:}"
    done
    return 0
  fi

  for entry in "${AUR_CANDIDATES[@]}"; do
    kind="${entry%%:*}"
    pkg="${entry#*:}"
    if ! aur_install "$pkg"; then
      record_failure "$kind" "$pkg"
    fi
  done
}

check_hyprland_version() {
  local ver
  ver="$(pacman -Q hyprland 2>/dev/null | awk '{print $2}')"
  ver="${ver#*:}"
  ver="${ver%%-*}"

  [[ -n "$ver" ]] || die "Hyprland is not installed."

  if [[ "$(printf '%s\n%s\n' "$MIN_HYPRLAND_VERSION" "$ver" | sort -V | head -n1)" != "$MIN_HYPRLAND_VERSION" ]]; then
    die "Hyprland $ver is too old. The Lua configuration needs Hyprland $MIN_HYPRLAND_VERSION or newer."
  fi
  ok "Hyprland $ver supports Lua configuration."
}

use_bibata_cursor() {
  CURSOR_THEME="Bibata-Modern-Ice"
  CURSOR_PATH="$CURSOR_SYSTEM_DIR"
  ok "Cursor theme: $CURSOR_THEME"
}

install_cursor_theme() {
  local tmp archive

  step "Installing the cursor theme"

  # Remove the copy an earlier version of this installer put in /usr/local/share/icons.
  if [[ -d "$OLD_CURSOR_DIR/Bibata-Modern-Ice" && "$OLD_CURSOR_DIR" != "$CURSOR_SYSTEM_DIR" ]]; then
    sudo rm -rf "$OLD_CURSOR_DIR/Bibata-Modern-Ice"
  fi

  if [[ -f "$CURSOR_SYSTEM_DIR/Bibata-Modern-Ice/cursors/left_ptr" ]]; then
    use_bibata_cursor
    return 0
  fi

  tmp="$(mktemp -d)"
  archive="$tmp/Bibata-Modern-Ice.tar.xz"

  if ! curl -fsSL "$BIBATA_URL" -o "$archive"; then
    warn "Could not download Bibata ($BIBATA_URL). Using the Adwaita cursor."
    rm -rf "$tmp"
    return 0
  fi

  if [[ -n "$BIBATA_SHA256" ]]; then
    if ! echo "$BIBATA_SHA256  $archive" | sha256sum -c --status; then
      warn "The Bibata archive does not match the pinned checksum. Using the Adwaita cursor."
      rm -rf "$tmp"
      return 0
    fi
  else
    warn "No checksum is pinned for the Bibata archive, so it is only protected by HTTPS."
  fi

  if ! tar -xf "$archive" -C "$tmp" || [[ ! -f "$tmp/Bibata-Modern-Ice/cursors/left_ptr" ]]; then
    warn "The Bibata archive has an unexpected layout. Using the Adwaita cursor."
    rm -rf "$tmp"
    return 0
  fi

  sudo install -d -m 0755 "$CURSOR_SYSTEM_DIR"
  sudo rm -rf "$CURSOR_SYSTEM_DIR/Bibata-Modern-Ice"
  sudo cp -a --no-preserve=ownership "$tmp/Bibata-Modern-Ice" "$CURSOR_SYSTEM_DIR/"
  sudo chmod -R u=rwX,go=rX "$CURSOR_SYSTEM_DIR/Bibata-Modern-Ice"
  rm -rf "$tmp"

  use_bibata_cursor
}

install_packages() {
  local pkg

  step "Updating the system"
  sudo pacman -Syu

  step "Resolving packages"
  for pkg in "${REQUIRED_PKGS[@]}"; do classify_pkg "$pkg" required; done
  for pkg in "${OPTIONAL_PKGS[@]}"; do classify_pkg "$pkg" optional; done

  if [[ "${INSTALL_BLUETOOTH:-0}" == "1" ]]; then
    for pkg in "${BLUETOOTH_PKGS[@]}"; do classify_pkg "$pkg" optional; done
  fi
  if [[ "${INSTALL_SMB:-0}" == "1" ]]; then
    for pkg in "${SMB_PKGS[@]}"; do classify_pkg "$pkg" optional; done
  fi

  if (( ${#REPO_PKGS[@]} )); then
    step "Installing packages from the repositories"
    sudo pacman -S --needed "${REPO_PKGS[@]}"
  else
    info "All repository packages are already installed."
  fi

  install_aur_candidates

  if (( ${#FAILED_OPTIONAL[@]} )); then
    warn "Optional packages not installed: ${FAILED_OPTIONAL[*]}"
  fi

  if (( ${#FAILED_REQUIRED[@]} )); then
    err "Required packages could not be installed: ${FAILED_REQUIRED[*]}"
    if [[ "$IS_CACHYOS" == "1" ]]; then
      err "On CachyOS, 'noctalia' comes from the cachyos-extra-v3 repository. Check that it is enabled in /etc/pacman.conf."
    fi
    exit 1
  fi

  check_hyprland_version
  install_cursor_theme
  ok "Packages done."
}
