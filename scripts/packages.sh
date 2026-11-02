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
  wl-clipboard
  gnome-keyring
  dconf
  kitty
  xdg-terminal-exec
  xdg-utils
)

# A missing package from this list only prints a warning.
OPTIONAL_PKGS=(
  nwg-look
  adw-gtk-theme
  adwaita-icon-theme
  adwaita-icon-theme-legacy
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
  fastfetch
  btop
)

# Cursor themes, from the upstream release (not in the repositories):
#   Bibata Modern Ice     white, used in dark mode (also the login screen)
#   Bibata Modern Classic black, used in light mode
# Both go to /usr/share/icons. That folder is searched by every toolkit (Xcursor,
# GTK, Qt, Hyprland) and readable by every user, including the greeter, which
# runs as a different user. /usr/local/share/icons is NOT searched by Xcursor.
# If the Ice download fails, Adwaita is used. If the Classic download fails,
# only the dark cursor is available and the light mode keeps it.
# Always the latest release, with no checksum: the archive is only protected by HTTPS.
BIBATA_BASE_URL="https://github.com/ful1e5/Bibata_Cursor/releases/latest/download"
BIBATA_ICE="Bibata-Modern-Ice"
BIBATA_CLASSIC="Bibata-Modern-Classic"
CURSOR_SYSTEM_DIR="${CURSOR_SYSTEM_DIR:-/usr/share/icons}"
CURSOR_THEME="Adwaita"
CURSOR_PATH="/usr/share/icons"

# Icon theme for GTK apps, from the upstream release (not in the repositories).
# MoreWaita adds icons for many apps and inherits from Adwaita, so it is only
# installed when Adwaita is present. Qt keeps breeze-dark. It is the latest
# release (the tag comes from the /releases/latest redirect), with no checksum.
# A folder that already exists is kept: remove it to update.
MOREWAITA_LATEST_URL="https://github.com/somepaulo/MoreWaita/releases/latest"
MOREWAITA_ARCHIVE_URL="https://github.com/somepaulo/MoreWaita/archive/refs/tags"
ICON_THEME="Adwaita"

# Chaotic-AUR (third-party repo), from https://github.com/chaotic-aur (docs at aur.chaotic.cx).
CHAOTIC_KEY="3056513887B78AEB"
CHAOTIC_KEYSERVER="keyserver.ubuntu.com"
CHAOTIC_CDN="https://cdn-mirror.chaotic.cx/chaotic-aur"
PACMAN_CONF="${PACMAN_CONF:-/etc/pacman.conf}"

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
  CURSOR_THEME="$BIBATA_ICE"
  CURSOR_PATH="$CURSOR_SYSTEM_DIR"
  ok "Cursor theme: $CURSOR_THEME"
}

# Download one Bibata variant and install it to $CURSOR_SYSTEM_DIR.
# Usage: install_bibata_variant <name>
# Returns 0 when the variant is installed, 1 when it is not (a warning is printed).
install_bibata_variant() {
  local name="$1" tmp archive url

  if [[ -f "$CURSOR_SYSTEM_DIR/$name/cursors/left_ptr" ]]; then
    return 0
  fi

  url="$BIBATA_BASE_URL/$name.tar.xz"
  tmp="$(mktemp -d)"
  archive="$tmp/$name.tar.xz"

  if ! curl -fsSL "$url" -o "$archive"; then
    warn "Could not download $name ($url)."
    rm -rf "$tmp"
    return 1
  fi

  if ! tar -xf "$archive" -C "$tmp" || [[ ! -f "$tmp/$name/cursors/left_ptr" ]]; then
    warn "The $name archive has an unexpected layout."
    rm -rf "$tmp"
    return 1
  fi

  sudo install -d -m 0755 "$CURSOR_SYSTEM_DIR"
  sudo rm -rf "${CURSOR_SYSTEM_DIR:?}/$name"
  sudo cp -a --no-preserve=ownership "$tmp/$name" "$CURSOR_SYSTEM_DIR/"
  sudo chmod -R u=rwX,go=rX "$CURSOR_SYSTEM_DIR/$name"
  rm -rf "$tmp"
  return 0
}

install_cursor_theme() {
  step "Installing the cursor themes"

  if install_bibata_variant "$BIBATA_ICE"; then
    use_bibata_cursor
  else
    warn "Using the Adwaita cursor."
  fi

  # Light mode cursor. Optional: without it the dark cursor stays in light mode.
  if install_bibata_variant "$BIBATA_CLASSIC"; then
    ok "Light mode cursor: $BIBATA_CLASSIC"
  else
    warn "Light mode will keep the dark cursor."
  fi
}

# Print the archive URL of the latest MoreWaita release. Fails when there is none.
morewaita_archive_url() {
  local final
  final="$(curl -fsSL -o /dev/null -w '%{url_effective}' "$MOREWAITA_LATEST_URL")" || return 1
  [[ "$final" == */releases/tag/* ]] || return 1
  printf '%s/%s.tar.gz\n' "$MOREWAITA_ARCHIVE_URL" "${final##*/}"
}

# Download MoreWaita and install it to $CURSOR_SYSTEM_DIR (the same folder as the
# cursors). Without it, or without Adwaita, the Adwaita icons stay.
install_icon_theme() {
  local dest="$CURSOR_SYSTEM_DIR/MoreWaita" tmp cache url

  step "Installing the MoreWaita icon theme"

  if [[ ! -f "$CURSOR_SYSTEM_DIR/Adwaita/index.theme" ]]; then
    warn "The Adwaita icon theme is missing, which MoreWaita needs. Using the Adwaita icons."
    return 0
  fi

  if [[ ! -f "$dest/index.theme" ]]; then
    tmp="$(mktemp -d)"
    mkdir "$tmp/MoreWaita"
    url="$(morewaita_archive_url || true)"

    # Same files as the upstream install.sh copies.
    if [[ -z "$url" ]] \
        || ! curl -fsSL "$url" -o "$tmp/morewaita.tar.gz" \
        || ! tar -xzf "$tmp/morewaita.tar.gz" -C "$tmp/MoreWaita" --strip-components=1 \
          --exclude='*.build' --exclude='*.sh' --exclude='*.py' --exclude='*.md' \
          --exclude='.git*' --exclude='_dev' \
        || [[ ! -f "$tmp/MoreWaita/index.theme" ]]; then
      warn "Could not download MoreWaita (${url:-$MOREWAITA_LATEST_URL}). Using the Adwaita icons."
      rm -rf "$tmp"
      return 0
    fi

    sudo install -d -m 0755 "$CURSOR_SYSTEM_DIR"
    sudo cp -a --no-preserve=ownership "$tmp/MoreWaita" "$CURSOR_SYSTEM_DIR/"
    sudo chmod -R u=rwX,go=rX "$dest"
    rm -rf "$tmp"
  fi

  # The cache is optional: GTK works without it, only slower.
  for cache in gtk4-update-icon-cache gtk-update-icon-cache; do
    if command -v "$cache" >/dev/null 2>&1; then
      sudo "$cache" -f -t "$dest" || warn "Could not update the MoreWaita icon cache."
      break
    fi
  done

  ICON_THEME="MoreWaita"
  ok "Icon theme: $ICON_THEME"
}

# Optional. On failure it warns and the install goes on without the repo.
# The section is only appended (never edited), so no backup is needed. It goes
# last, so the CachyOS and Arch repositories keep priority. The "pacman -Syu"
# that follows downloads the new repository database.
setup_chaotic_aur() {
  step "Adding the Chaotic-AUR repository"

  if ! { pkg_installed chaotic-keyring && pkg_installed chaotic-mirrorlist; }; then
    if ! sudo pacman-key --recv-key "$CHAOTIC_KEY" --keyserver "$CHAOTIC_KEYSERVER" \
      || ! sudo pacman-key --lsign-key "$CHAOTIC_KEY" \
      || ! sudo pacman -U "$CHAOTIC_CDN/chaotic-keyring.pkg.tar.zst" "$CHAOTIC_CDN/chaotic-mirrorlist.pkg.tar.zst"; then
      warn "Could not set up Chaotic-AUR. Continuing without it."
      return 0
    fi
  fi

  if grep -q '^\[chaotic-aur\]' "$PACMAN_CONF"; then
    info "chaotic-aur is already in $PACMAN_CONF."
  else
    printf '\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist\n' | sudo tee -a "$PACMAN_CONF" >/dev/null
  fi
  ok "Chaotic-AUR enabled."
}

install_packages() {
  local pkg

  if [[ "${INSTALL_CHAOTIC:-0}" == "1" ]]; then
    setup_chaotic_aur
  fi

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
  install_icon_theme
  ok "Packages done."
}
