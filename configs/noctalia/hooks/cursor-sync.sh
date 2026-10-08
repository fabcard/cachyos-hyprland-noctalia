#!/usr/bin/env bash
# Switch the cursor theme to match the Noctalia theme mode.
#
# Called by the Noctalia hooks "started" and "theme_mode_changed"
# (see ~/.config/noctalia/hooks.toml). Hooks do not pass arguments, so the mode
# comes from $NOCTALIA_THEME_MODE. When that is not set (the "started" hook),
# the script asks Noctalia, then GNOME settings, and falls back to dark.
#
#   dark  -> Bibata-Modern-Ice
#   light -> Bibata-Modern-Classic
#
# Run by hand to test: NOCTALIA_THEME_MODE=light bash cursor-sync.sh

set -u

DARK_CURSOR="Bibata-Modern-Ice"
LIGHT_CURSOR="Bibata-Modern-Classic"
CURSOR_SIZE=24
ICON_DIRS=(/usr/share/icons /usr/local/share/icons "$HOME/.icons" "$HOME/.local/share/icons")

normalize_mode() {
  local value="${1,,}"
  value="${value//[[:space:]\'\"]/}"
  case "$value" in
    dark | light) printf '%s' "$value" ;;
  esac
}

theme_installed() {
  local dir
  for dir in "${ICON_DIRS[@]}"; do
    [[ -f "$dir/$1/cursors/left_ptr" ]] && return 0
  done
  return 1
}

detect_mode() {
  local mode scheme

  mode="$(normalize_mode "${NOCTALIA_THEME_MODE:-}")"
  if [[ -z "$mode" ]] && command -v noctalia >/dev/null 2>&1; then
    mode="$(normalize_mode "$(noctalia msg theme-mode-get 2>/dev/null || true)")"
  fi
  if [[ -z "$mode" ]] && command -v gsettings >/dev/null 2>&1; then
    scheme="$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null || true)"
    case "$scheme" in
      *prefer-dark*) mode="dark" ;;
      *prefer-light*) mode="light" ;;
    esac
  fi

  printf '%s' "${mode:-dark}"
}

main() {
  local mode cursor

  mode="$(detect_mode)"
  if [[ "$mode" == "light" ]]; then
    cursor="$LIGHT_CURSOR"
  else
    cursor="$DARK_CURSOR"
  fi

  # Not installed (the download failed): leave the current cursor alone.
  theme_installed "$cursor" || exit 0

  # GTK apps that are already open pick this up on the fly.
  if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface cursor-theme "$cursor" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface cursor-size "$CURSOR_SIZE" 2>/dev/null || true
  fi

  # Hyprland and Xwayland.
  if command -v hyprctl >/dev/null 2>&1; then
    hyprctl setcursor "$cursor" "$CURSOR_SIZE" >/dev/null 2>&1 || true
  fi

  # Apps started from now on (uwsm and the Noctalia launcher use systemd user units).
  if command -v systemctl >/dev/null 2>&1; then
    systemctl --user set-environment "XCURSOR_THEME=$cursor" "XCURSOR_SIZE=$CURSOR_SIZE" 2>/dev/null || true
  fi
}

main "$@"
