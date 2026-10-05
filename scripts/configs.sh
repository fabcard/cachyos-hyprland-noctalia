#!/usr/bin/env bash
# Config installation. Sourced by install.sh.
#
# Files under configs/ are copied to ~/.config with a few placeholders filled
# in. Existing files are backed up first. Files that did not change are left
# alone, so running the installer twice is safe.
#
# Placeholders: @KB_LAYOUT@ @KB_VARIANT@ @BROWSER_DESKTOP@ @HOME@

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

KB_LAYOUT="us"
KB_VARIANT=""
BROWSER_DESKTOP="brave-origin.desktop"

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

# Render every file of configs/<name> into $CONFIG_HOME/<name>.
install_tree() {
  local name="$1" src_dir="$CONFIGS_DIR/$1" file

  [[ -d "$src_dir" ]] || die "Missing config folder: $src_dir"

  while IFS= read -r -d '' file; do
    render_file "$file" "$CONFIG_HOME/$name/${file#"$src_dir"/}"
  done < <(find "$src_dir" -type f -print0 | sort -z)
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

# Turn on the GTK and Qt theme templates of Noctalia. The template IDs come
# from "noctalia theme --list-templates", so no ID is guessed.
write_noctalia_templates() {
  local line tok ids=() joined="" tmp id

  if ! command -v noctalia >/dev/null 2>&1; then
    warn "noctalia not found, skipping theme templates."
    return 0
  fi

  while IFS= read -r line; do
    tok="${line#"${line%%[[:alnum:]]*}"}"
    tok="${tok%%[[:space:]]*}"
    tok="${tok,,}"
    case "$tok" in
      gtk*|qt*) ids+=("$tok") ;;
    esac
  done < <(noctalia theme --list-templates 2>/dev/null || true)

  if (( ${#ids[@]} == 0 )); then
    warn "Could not read template IDs from noctalia. In Noctalia open Settings > Templates"
    warn "and turn on GTK 3, GTK 4 and Qt by hand."
    return 0
  fi

  while IFS= read -r id; do
    joined+="${joined:+, }\"$id\""
  done < <(printf '%s\n' "${ids[@]}" | sort -u)

  info "Noctalia templates enabled: $joined"
  tmp="$(mktemp)"
  printf '# Theme templates for GTK and Qt apps (generated by the installer).\n\n[theme.templates]\nenable_builtin_templates = true\nbuiltin_ids = [%s]\n' "$joined" >"$tmp"
  place_file "$tmp" "$CONFIG_HOME/noctalia/templates.toml"
  rm -f "$tmp"
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
    "cursor-theme Adwaita"
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

  mkdir -p "$WALLPAPER_DIR"
  warn_old_hypr_conf

  install_tree hypr
  install_tree noctalia
  install_tree kitty
  install_tree uwsm
  install_tree gtk-3.0
  install_tree gtk-4.0
  install_tree qt6ct
  install_mimeapps
  write_noctalia_templates
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
