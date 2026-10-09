#!/usr/bin/env bash
# Uninstall. Sourced by install.sh when it runs with --uninstall.
# Needs lib.sh, configs.sh and services.sh to be loaded first.
#
# Every step asks first. Nothing is deleted from the home folder: the files go
# to ~/.config-removed-YYYYMMDD-HHMMSS. Packages are never removed, because many
# of them (pipewire, networkmanager, polkit, ...) may be used by other things.
# Wallpapers and the Noctalia settings saved by its GUI
# (~/.local/state/noctalia) are left alone.

# Variables set here are read by this module only.
# shellcheck disable=SC2034

REMOVED_DIR=""

# Config folders of the repo, copied to $CONFIG_HOME/<name> by the installer.
UNINSTALL_TREES=(hypr noctalia kitty uwsm gtk-3.0 gtk-4.0 qt6ct btop)
# Files the installer generates, relative to $CONFIG_HOME.
UNINSTALL_GENERATED=(noctalia/templates.toml noctalia/greeter-sync.toml)
UNINSTALL_CURSORS=(Bibata-Modern-Ice Bibata-Modern-Classic)
# Folders that may hold the cursors. CHN_CURSOR_DIRS overrides it (used by tests).
UNINSTALL_CURSOR_DIRS="${CHN_CURSOR_DIRS:-/usr/share/icons /usr/local/share/icons}"

# Move a file or folder out of the way, keeping its path under $REMOVED_DIR.
# Returns 1 when there is nothing to move.
move_to_removed() {
  local path="$1" rel
  [[ -e "$path" || -L "$path" ]] || return 1

  if [[ -z "$REMOVED_DIR" ]]; then
    REMOVED_DIR="$HOME/.config-removed-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$REMOVED_DIR"
  fi

  rel="${path#"$HOME"/}"
  rel="${rel#/}"
  mkdir -p "$REMOVED_DIR/$(dirname "$rel")"
  mv "$path" "$REMOVED_DIR/$rel"
}

# Print (NUL separated) every user file the installer can write.
installer_files() {
  local tree src_dir file

  for tree in "${UNINSTALL_TREES[@]}"; do
    src_dir="$CONFIGS_DIR/$tree"
    [[ -d "$src_dir" ]] || continue
    while IFS= read -r -d '' file; do
      printf '%s\0' "$CONFIG_HOME/$tree/${file#"$src_dir"/}"
    done < <(find "$src_dir" -type f -print0 | sort -z)
  done

  src_dir="$CONFIGS_DIR/icons/default"
  if [[ -d "$src_dir" ]]; then
    while IFS= read -r -d '' file; do
      printf '%s\0' "$HOME/.icons/default/${file#"$src_dir"/}"
    done < <(find "$src_dir" -type f -print0 | sort -z)
  fi

  if [[ -f "$CONFIGS_DIR/mimeapps.list" ]]; then
    printf '%s\0' "$CONFIG_HOME/mimeapps.list"
  fi

  for file in "${UNINSTALL_GENERATED[@]}"; do
    printf '%s\0' "$CONFIG_HOME/$file"
  done
}

# Remove folders left empty after the move. Never touches $CONFIG_HOME itself.
prune_empty_dirs() {
  local tree
  for tree in "${UNINSTALL_TREES[@]}"; do
    [[ -d "$CONFIG_HOME/$tree" ]] && find "$CONFIG_HOME/$tree" -depth -type d -empty -delete
  done
  if [[ -d "$HOME/.icons/default" ]]; then
    find "$HOME/.icons/default" -depth -type d -empty -delete
  fi
  return 0
}

gsettings_reset() {
  command -v gsettings >/dev/null 2>&1 || return 1
  if [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
    gsettings reset "$@"
  elif command -v dbus-run-session >/dev/null 2>&1; then
    dbus-run-session -- gsettings reset "$@"
  else
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Steps
# ---------------------------------------------------------------------------

uninstall_greeter() {
  local unit dms=()

  step "Login screen"
  if ! ask_yes_no "Disable the Noctalia Greeter (greetd) and the passwordless login screen sync?" y; then
    info "Skipped."
    return 0
  fi

  if command -v noctalia-greeter >/dev/null 2>&1; then
    sudo noctalia-greeter passwordless-sync disable "$(id -un)" \
      || warn "Could not disable the passwordless sync (it may not have been enabled)."
  fi

  if unit_exists greetd.service; then
    sudo systemctl disable greetd.service || warn "Could not disable greetd."
  fi

  if [[ -f "$GREETER_STATE_DIR/greeter.toml" ]]; then
    sudo rm -f "$GREETER_STATE_DIR/greeter.toml"
    info "Removed $GREETER_STATE_DIR/greeter.toml"
  fi

  for unit in "${OTHER_DISPLAY_MANAGERS[@]}"; do
    if unit_exists "${unit}.service"; then
      dms+=("$unit")
    fi
  done

  if (( ${#dms[@]} )); then
    info "Other display managers installed: ${dms[*]}"
    info "The installer may have disabled one of them. To use it again: sudo systemctl enable NAME.service"
  else
    warn "No other display manager is installed. The system will boot to a text login."
  fi
  ok "greetd disabled. It stops being used on the next boot."
}

uninstall_configs() {
  local path moved=0 key

  step "Configuration"
  if ! ask_yes_no "Move the config files written by the installer out of ~/.config?" y; then
    info "Skipped."
    return 0
  fi

  while IFS= read -r -d '' path; do
    if move_to_removed "$path"; then
      moved=$((moved + 1))
    fi
  done < <(installer_files)
  prune_empty_dirs

  for key in color-scheme gtk-theme icon-theme cursor-theme cursor-size; do
    gsettings_reset org.gnome.desktop.interface "$key" 2>/dev/null || true
  done

  if (( moved )); then
    ok "Moved $moved files to $REMOVED_DIR"
  else
    info "No installer files found."
  fi
}

# Copy one backed-up file that lives outside the home folder (/etc, /var).
restore_system_file() {
  local file="$1" rel="$2" dest parent owner="root" group="root"

  dest="/$rel"
  parent="$(dirname "$dest")"
  if [[ "$rel" == var/* && -d "$parent" ]]; then
    owner="$(stat -c %U "$parent")"
    group="$(stat -c %G "$parent")"
  fi
  sudo install -D -o "$owner" -g "$group" -m 0644 "$file" "$dest"
  info "Restored $dest"
}

restore_backup() {
  local backups=() oldest file rel count=0

  step "Backups"
  mapfile -t backups < <(find "$HOME" -maxdepth 1 -type d -name '.config-backup-*' | sort)
  if (( ${#backups[@]} == 0 )); then
    info "No backup folder found in $HOME."
    return 0
  fi

  # The oldest backup holds the files from before the first install.
  oldest="${backups[0]}"
  info "Found ${#backups[@]} backup folder(s). The oldest has your files from before the first install."
  if ! ask_yes_no "Restore your files from $oldest?" y; then
    info "Skipped."
    return 0
  fi

  while IFS= read -r -d '' file; do
    rel="${file#"$oldest"/}"
    case "$rel" in
      etc/* | var/*)
        restore_system_file "$file" "$rel"
        ;;
      *)
        # A file in the way (the move step was skipped) is kept, not overwritten.
        move_to_removed "$HOME/$rel" || true
        mkdir -p "$(dirname "$HOME/$rel")"
        cp -a "$file" "$HOME/$rel"
        info "Restored ~/$rel"
        ;;
    esac
    count=$((count + 1))
  done < <(find "$oldest" \( -type f -o -type l \) -print0 | sort -z)

  ok "Restored $count files."
}

uninstall_cursors() {
  local dir name path dirs=()

  step "Cursor themes"
  if ! ask_yes_no "Remove the Bibata cursor themes the installer downloaded?" y; then
    info "Skipped."
    return 0
  fi

  read -r -a dirs <<<"$UNINSTALL_CURSOR_DIRS"
  for dir in "${dirs[@]}"; do
    for name in "${UNINSTALL_CURSORS[@]}"; do
      path="$dir/$name"
      [[ -d "$path" ]] || continue
      if pacman -Qo "$path" >/dev/null 2>&1; then
        warn "$path belongs to a package, skipped."
        continue
      fi
      sudo rm -rf "${dir:?}/$name"
      info "Removed $path"
    done
  done
}

run_uninstall() {
  step "Uninstall"
  info "This will, step by step and with a question before each one:"
  info "  1. disable the Noctalia Greeter and the passwordless sync"
  info "  2. move the config files written by the installer to a removal folder"
  info "  3. restore your old files from the oldest ~/.config-backup-* folder"
  info "  4. remove the Bibata cursor themes"
  info "Packages, wallpapers and ~/.local/state/noctalia are not touched."
  info "The file list comes from the version being run. Use the same CHN_REF you installed with."

  if [[ "${CHN_DEFAULTS:-0}" != "1" ]]; then
    if ! ask_yes_no "Continue?" n; then
      info "Nothing was changed."
      return 0
    fi
  fi

  uninstall_greeter
  uninstall_configs
  restore_backup
  uninstall_cursors

  step "Done"
  ok "Uninstall finished."
  if [[ -n "$REMOVED_DIR" ]]; then
    info "Files that were removed or replaced are in: $REMOVED_DIR"
  fi
  info "Installed packages were kept. To remove one: sudo pacman -Rns <package>"
  info "Reboot to finish."
}
