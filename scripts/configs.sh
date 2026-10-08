#!/usr/bin/env bash
# Config installation. Sourced by install.sh.
#
# Files under configs/ are copied to ~/.config with a few placeholders filled
# in. Existing files are backed up first. Files that did not change are left
# alone, so running the installer twice is safe.
#
# Placeholders: @KB_LAYOUT@ @KB_VARIANT@ @BROWSER_DESKTOP@ @HOME@ @CURSOR_THEME@
# @CURSOR_PATH@ @MONITOR1@ @MONITOR2@ @MONITOR3@

CONFIGS_DIR="${CONFIGS_DIR:-${SCRIPT_DIR:-.}/configs}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
GREETER_STATE_DIR="/var/lib/noctalia-greeter"
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"

DESKTOP_DIRS=(
  /usr/share/applications
  /usr/local/share/applications
  "$HOME/.local/share/applications"
  /var/lib/flatpak/exports/share/applications
)

DRM_DIR="${DRM_DIR:-/sys/class/drm}"

KB_LAYOUT="us"
KB_VARIANT=""
BROWSER_DESKTOP="brave-origin.desktop"
MONITOR1=""
MONITOR2=""
MONITOR3=""
CURSOR_THEME="${CURSOR_THEME:-Adwaita}"
CURSOR_PATH="${CURSOR_PATH:-/usr/share/icons}"
GREETER_SYNC_OK=0
BTOP_TEMPLATE=0

# ---------------------------------------------------------------------------
# Detection
# ---------------------------------------------------------------------------

# Read the X11 keyboard layout from the system. Falls back to "us".
detect_keyboard() {
  local layout="" variant=""

  if command -v localectl >/dev/null 2>&1; then
    layout="$(localectl status 2>/dev/null | awk -F': *' '/X11 Layout/ {print $2; exit}')"
    variant="$(localectl status 2>/dev/null | awk -F': *' '/X11 Variant/ {print $2; exit}')"
  fi

  [[ "$layout" == "n/a" ]] && layout=""
  [[ "$variant" == "n/a" ]] && variant=""

  if [[ "$layout" =~ ^[A-Za-z0-9_,-]+$ ]]; then
    KB_LAYOUT="$layout"
    if [[ "$variant" =~ ^[A-Za-z0-9_,-]*$ ]]; then
      KB_VARIANT="$variant"
    fi
  fi

  info "Keyboard layout: $KB_LAYOUT${KB_VARIANT:+ ($KB_VARIANT)}"
}

desktop_exists() {
  local id="$1" dir
  for dir in "${DESKTOP_DIRS[@]}"; do
    [[ -f "$dir/$id" ]] && return 0
  done
  return 1
}

# Find the desktop file of the Brave browser.
detect_browser() {
  local dir file
  if desktop_exists "brave-origin.desktop"; then
    BROWSER_DESKTOP="brave-origin.desktop"
    return 0
  fi

  for dir in "${DESKTOP_DIRS[@]}"; do
    [[ -d "$dir" ]] || continue
    for file in "$dir"/brave*.desktop; do
      [[ -f "$file" ]] || continue
      BROWSER_DESKTOP="$(basename "$file")"
      info "Browser desktop file: $BROWSER_DESKTOP"
      return 0
    done
  done

  warn "No Brave desktop file found. Browser entries will be skipped in mimeapps.list."
}

# Read the connected monitors (for example DP-1 or HDMI-A-1) from the kernel.
# Up to three. When nothing is found the names stay empty, which means "any monitor".
detect_monitors() {
  local status_file name count=0

  for status_file in "$DRM_DIR"/card*-*/status; do
    [[ -r "$status_file" ]] || continue
    [[ "$(<"$status_file")" == "connected" ]] || continue

    name="${status_file%/status}"
    name="${name##*/}"
    name="${name#card*-}"
    count=$(( count + 1 ))

    case "$count" in
      1) MONITOR1="$name" ;;
      2) MONITOR2="$name" ;;
      3) MONITOR3="$name" ;;
    esac
  done

  if (( count == 0 )); then
    warn "No connected monitor found. Edit ~/.config/hypr/conf/variables.lua later if you need to."
  else
    info "Monitors: ${MONITOR1:-none}${MONITOR2:+, $MONITOR2}${MONITOR3:+, $MONITOR3}"
  fi
}

# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------

sed_escape() { printf '%s' "$1" | sed -e 's/[\/&|]/\\&/g'; }

# Print a config file with placeholders filled in.
render_stdout() {
  local src="$1"
  sed \
    -e "s|@KB_LAYOUT@|$(sed_escape "$KB_LAYOUT")|g" \
    -e "s|@KB_VARIANT@|$(sed_escape "$KB_VARIANT")|g" \
    -e "s|@BROWSER_DESKTOP@|$(sed_escape "$BROWSER_DESKTOP")|g" \
    -e "s|@HOME@|$(sed_escape "$HOME")|g" \
    -e "s|@CURSOR_THEME@|$(sed_escape "$CURSOR_THEME")|g" \
    -e "s|@CURSOR_PATH@|$(sed_escape "$CURSOR_PATH")|g" \
    -e "s|@MONITOR1@|$(sed_escape "$MONITOR1")|g" \
    -e "s|@MONITOR2@|$(sed_escape "$MONITOR2")|g" \
    -e "s|@MONITOR3@|$(sed_escape "$MONITOR3")|g" \
    "$src" | sed -E '/^variant = ""$/d'
}

# Copy a temporary file to its destination, with backup, only when it differs.
place_file() {
  local tmp="$1" dest="$2"

  if [[ -f "$dest" ]] && cmp -s "$tmp" "$dest"; then
    return 0
  fi

  backup_path "$dest"
  mkdir -p "$(dirname "$dest")"
  install -m 0644 "$tmp" "$dest"
  info "Installed $dest"
}

render_file() {
  local src="$1" dest="$2" tmp
  tmp="$(mktemp)"
  render_stdout "$src" >"$tmp"
  place_file "$tmp" "$dest"
  rm -f "$tmp"
}

# Render every file of a source folder into a destination folder.
install_dir() {
  local src_dir="$1" dest_dir="$2" file

  [[ -d "$src_dir" ]] || die "Missing config folder: $src_dir"

  while IFS= read -r -d '' file; do
    render_file "$file" "$dest_dir/${file#"$src_dir"/}"
  done < <(find "$src_dir" -type f -print0 | sort -z)
}

# Render every file of configs/<name> into $CONFIG_HOME/<name>.
install_tree() {
  install_dir "$CONFIGS_DIR/$1" "$CONFIG_HOME/$1"
}

# ---------------------------------------------------------------------------
# Special cases
# ---------------------------------------------------------------------------

# mimeapps.list: use the real Brave desktop file and drop entries whose app is
# not installed, so no file type points to a missing application.
install_mimeapps() {
  local src="$CONFIGS_DIR/mimeapps.list" tmp line id missing=()

  [[ -f "$src" ]] || die "Missing file: $src"
  tmp="$(mktemp)"

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line//brave-origin.desktop/$BROWSER_DESKTOP}"
    if [[ "$line" != \#* && "$line" == *=*.desktop\; ]]; then
      id="${line#*=}"
      id="${id%;}"
      if ! desktop_exists "$id"; then
        missing+=("$id")
        continue
      fi
    fi
    printf '%s\n' "$line"
  done <"$src" >"$tmp"

  if (( ${#missing[@]} )); then
    warn "Not installed, removed from mimeapps.list: $(printf '%s\n' "${missing[@]}" | sort -u | tr '\n' ' ')"
  fi

  place_file "$tmp" "$CONFIG_HOME/mimeapps.list"
  rm -f "$tmp"
}

# Turn on the Noctalia theme templates for GTK, Qt (qt6ct and KColorScheme), kitty,
# and btop, plus the community templates for Brave Origin and fastfetch.
# The built-in IDs are checked against "noctalia theme --list-templates". When
# that list cannot be read, they are used as they are. Community templates are
# fetched by Noctalia from api.noctalia.dev, so they are not checked here.
TEMPLATE_CANDIDATES=(btop gtk3 gtk4 kcolorscheme kitty qt)
COMMUNITY_TEMPLATES=(brave-origin fastfetch)

write_noctalia_templates() {
  local line tok listed=() ids=() candidate found joined="" community="" tmp id

  if ! command -v noctalia >/dev/null 2>&1; then
    warn "noctalia not found, skipping theme templates."
    return 0
  fi

  while IFS= read -r line; do
    tok="${line#"${line%%[[:alnum:]]*}"}"
    tok="${tok%%[[:space:]]*}"
    listed+=("${tok,,}")
  done < <(noctalia theme --list-templates 2>/dev/null || true)

  if (( ${#listed[@]} == 0 )); then
    ids=("${TEMPLATE_CANDIDATES[@]}")
  else
    for candidate in "${TEMPLATE_CANDIDATES[@]}"; do
      for found in "${listed[@]}"; do
        if [[ "$found" == "$candidate" ]]; then
          ids+=("$candidate")
          break
        fi
      done
    done
  fi

  if (( ${#ids[@]} == 0 )); then
    warn "None of the expected theme templates were listed by noctalia. In Noctalia open"
    warn "Settings > Templates and turn on GTK 3, GTK 4, Qt, KColorScheme and kitty by hand."
    return 0
  fi

  for id in "${ids[@]}"; do
    joined+="${joined:+, }\"$id\""
    [[ "$id" == "btop" ]] && BTOP_TEMPLATE=1
  done

  for id in "${COMMUNITY_TEMPLATES[@]}"; do
    community+="${community:+, }\"$id\""
  done

  info "Noctalia templates enabled: $joined"
  info "Noctalia community templates enabled: $community"
  tmp="$(mktemp)"
  {
    printf '# Theme templates for GTK, Qt, KDE-framework apps, kitty, btop, Brave Origin and fastfetch\n'
    printf '# (generated by the installer).\n\n'
    printf '[theme.templates]\n'
    printf 'enable_builtin_templates = true\n'
    printf 'builtin_ids = [%s]\n' "$joined"
    printf 'enable_community_templates = true\n'
    printf 'community_ids = [%s]\n' "$community"
  } >"$tmp"
  place_file "$tmp" "$CONFIG_HOME/noctalia/templates.toml"
  rm -f "$tmp"
}

# Copy a file only when it does not exist yet. Noctalia may edit it later, so a
# second run must not put the old content back.
seed_file() {
  local src="$1" dest="$2"
  if [[ -e "$dest" ]]; then
    return 0
  fi
  render_file "$src" "$dest"
}

# btop only needs its config when the Noctalia btop template is on.
install_btop_config() {
  if [[ "$BTOP_TEMPLATE" == "1" ]] && command -v btop >/dev/null 2>&1; then
    install_tree btop
  fi
}

# greeter.toml lives in a folder owned by the greetd user.
install_greeter_config() {
  local src="$CONFIGS_DIR/greeter/greeter.toml" dest="$GREETER_STATE_DIR/greeter.toml"
  local user group tmp

  [[ -f "$src" ]] || die "Missing file: $src"

  user="$(greetd_existing_user "${GREETD_CONFIG:-/etc/greetd/config.toml}")"
  user="${user:-greeter}"
  if ! id "$user" >/dev/null 2>&1; then
    warn "greetd user '$user' not found, skipping greeter.toml."
    return 0
  fi
  group="$(id -gn "$user")"

  tmp="$(mktemp)"
  render_stdout "$src" >"$tmp"
  if [[ "$GREETER_SYNC_OK" == "1" ]]; then
    printf '\n[appearance]\nscheme = "Synced"\n' >>"$tmp"
  fi

  if [[ -f "$dest" ]] && cmp -s "$tmp" "$dest"; then
    ok "greeter.toml already up to date."
  else
    backup_path "$dest"
    sudo install -d -o "$user" -g "$group" -m 0755 "$GREETER_STATE_DIR"
    sudo install -o "$user" -g "$group" -m 0644 "$tmp" "$dest"
    info "Installed $dest"
  fi
  rm -f "$tmp"
}

gsettings_set() {
  command -v gsettings >/dev/null 2>&1 || return 1
  if [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
    gsettings set "$@"
  elif command -v dbus-run-session >/dev/null 2>&1; then
    dbus-run-session -- gsettings set "$@"
  else
    return 1
  fi
}

# Dark mode, theme, icons and cursor for GTK apps.
apply_gsettings() {
  local ok_all=1 pair
  local settings=(
    "color-scheme prefer-dark"
    "gtk-theme adw-gtk3-dark"
    "icon-theme Adwaita"
    "cursor-theme $CURSOR_THEME"
    "cursor-size 24"
  )

  for pair in "${settings[@]}"; do
    # shellcheck disable=SC2086
    gsettings_set org.gnome.desktop.interface $pair 2>/dev/null || ok_all=0
  done

  if (( ok_all )); then
    ok "GTK dark mode and theme applied."
  else
    warn "Could not write GNOME settings. Noctalia applies dark mode on first start anyway."
  fi
}

# Let Noctalia sync the wallpaper and colors to the login screen without a
# password prompt. The rule written by noctalia-greeter only covers its
# constrained appearance sync action, only for this user, and only from an
# active local session.
# Undo with: sudo noctalia-greeter passwordless-sync disable "$USER"
setup_greeter_sync() {
  local user tmp
  user="$(id -un)"

  if ! command -v noctalia-greeter >/dev/null 2>&1; then
    warn "noctalia-greeter not found, skipping greeter sync."
    return 0
  fi

  if ! sudo noctalia-greeter passwordless-sync enable "$user"; then
    warn "Could not enable passwordless greeter sync. The greeter may be older than 1.5.0."
    warn "Auto-sync stays off, because it would ask for a password on every change."
    return 0
  fi

  tmp="$(mktemp)"
  cat >"$tmp" <<'TOML'
# Sync the Noctalia wallpaper and colors to the login screen automatically.
# Needs the passwordless rule created with:
#   sudo noctalia-greeter passwordless-sync enable "$USER"

[shell.greeter_sync]
auto_sync = true
TOML
  place_file "$tmp" "$CONFIG_HOME/noctalia/greeter-sync.toml"
  rm -f "$tmp"
  GREETER_SYNC_OK=1
  ok "Login screen sync enabled."
}

warn_old_hypr_conf() {
  if [[ -f "$CONFIG_HOME/hypr/hyprland.conf" ]]; then
    warn "Found an old $CONFIG_HOME/hypr/hyprland.conf. Hyprland 0.55 uses hyprland.lua; consider removing the .conf."
  fi
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

install_configs() {
  step "Installing configuration"

  detect_keyboard
  detect_browser
  detect_monitors

  mkdir -p "$WALLPAPER_DIR"
  warn_old_hypr_conf

  install_tree hypr
  install_tree noctalia
  install_tree kitty
  install_tree uwsm
  install_tree gtk-3.0
  install_tree gtk-4.0
  install_tree qt6ct
  install_dir "$CONFIGS_DIR/icons/default" "$HOME/.icons/default"
  seed_file "$CONFIGS_DIR/kdeglobals" "$CONFIG_HOME/kdeglobals"
  install_mimeapps
  write_noctalia_templates
  install_btop_config

  # The greeter sync comes first: greeter.toml depends on whether it works.
  if [[ "${INSTALL_GREETER_SYNC:-0}" == "1" ]]; then
    setup_greeter_sync
  fi
  install_greeter_config
  apply_gsettings

  if command -v noctalia >/dev/null 2>&1; then
    if noctalia config validate >/dev/null 2>&1; then
      ok "Noctalia config is valid."
    else
      warn "'noctalia config validate' reported a problem. Run it by hand to see details."
    fi
  fi

  ok "Configuration done."
}
