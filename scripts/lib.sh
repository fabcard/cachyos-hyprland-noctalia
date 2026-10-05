#!/usr/bin/env bash
# Shared helpers. Sourced by install.sh, never executed directly.

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'
  C_BOLD=$'\033[1m'
  C_RED=$'\033[31m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_BLUE=$'\033[34m'
else
  C_RESET="" C_BOLD="" C_RED="" C_GREEN="" C_YELLOW="" C_BLUE=""
fi

info() { printf '%s[INFO]%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
ok()   { printf '%s[ OK ]%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn() { printf '%s[WARN]%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
err()  { printf '%s[FAIL]%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }
die()  { err "$*"; exit 1; }
step() { printf '\n%s==> %s%s\n' "$C_BOLD" "$*" "$C_RESET"; }

# ---------------------------------------------------------------------------
# Prompts
# ---------------------------------------------------------------------------

have_tty() { { : </dev/tty; } 2>/dev/null; }

# Usage: ask_yes_no "Question?" [y|n]
# The second argument is the default answer (n when omitted).
# Returns 0 for yes, 1 for no. Uses the default when there is no terminal
# or when CHN_DEFAULTS=1.
ask_yes_no() {
  local prompt="$1" default="${2:-n}" hint reply

  if [[ "$default" == "y" ]]; then
    hint="[Y/n]"
  else
    hint="[y/N]"
  fi

  if [[ "${CHN_DEFAULTS:-0}" == "1" ]] || ! have_tty; then
    [[ "$default" == "y" ]]
    return
  fi

  while true; do
    read -r -p "$prompt $hint " reply </dev/tty || reply=""
    reply="${reply,,}"
    case "$reply" in
      "") [[ "$default" == "y" ]]; return ;;
      y|yes) return 0 ;;
      n|no) return 1 ;;
      *) echo "Please answer y or n." ;;
    esac
  done
}

# ---------------------------------------------------------------------------
# Backups
# ---------------------------------------------------------------------------

BACKUP_DIR=""

# Copy a file or directory into the backup directory before overwriting it.
backup_path() {
  local target="$1" rel
  [[ -e "$target" || -L "$target" ]] || return 0

  if [[ -z "$BACKUP_DIR" ]]; then
    BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR"
  fi

  rel="${target#"$HOME"/}"
  rel="${rel#/}"
  mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
  cp -a "$target" "$BACKUP_DIR/$rel"
  info "Backed up $target"
}

# ---------------------------------------------------------------------------
# Environment checks
# ---------------------------------------------------------------------------

IS_CACHYOS=0

require_not_root() {
  if [[ $EUID -eq 0 ]]; then
    die "Do not run this installer as root. Run it as your normal user; it uses sudo when needed."
  fi
}

check_distro() {
  local os_id os_id_like

  [[ -r /etc/os-release ]] || die "Cannot read /etc/os-release."
  os_id="$(. /etc/os-release && printf '%s' "${ID:-}")"
  os_id_like="$(. /etc/os-release && printf '%s' "${ID_LIKE:-}")"

  command -v pacman >/dev/null 2>&1 || die "pacman not found. This installer needs an Arch-based system."

  if [[ "$os_id" == "cachyos" ]]; then
    IS_CACHYOS=1
    ok "CachyOS detected."
  elif [[ "$os_id" == "arch" || " $os_id_like " == *" arch "* ]]; then
    warn "This installer was built and tested on CachyOS. Detected: ${os_id:-unknown} (Arch-based)."
    warn "Some packages may only exist in CachyOS repositories and can fail to install here."
    ask_yes_no "Continue anyway?" n || die "Aborted."
  else
    die "Unsupported distribution: ${os_id:-unknown}. This installer needs CachyOS or an Arch-based system."
  fi
}

check_internet() {
  if ! curl -fsS --max-time 10 -o /dev/null https://github.com; then
    die "No internet connection (could not reach github.com)."
  fi
  ok "Internet connection OK."
}

SUDO_KEEPALIVE_PID=""

start_sudo_keepalive() {
  (
    while true; do
      sudo -n true 2>/dev/null || exit
      sleep 50
      kill -0 "$$" 2>/dev/null || exit
    done
  ) </dev/null >/dev/null 2>&1 &
  SUDO_KEEPALIVE_PID=$!
}

stop_sudo_keepalive() {
  if [[ -n "$SUDO_KEEPALIVE_PID" ]]; then
    kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
  fi
}

check_sudo() {
  command -v sudo >/dev/null 2>&1 || die "sudo is required."
  info "Asking for sudo access (needed to install packages and enable services)."
  sudo -v || die "Could not get sudo access."
  start_sudo_keepalive
}

# Warn when another desktop or display manager is already present.
check_existing_desktop() {
  local found=() unit session file

  for unit in sddm gdm lightdm lxdm ly plasmalogin; do
    if systemctl is-enabled --quiet "${unit}.service" 2>/dev/null; then
      found+=("display manager: ${unit}")
    fi
  done

  for file in /usr/share/wayland-sessions/*.desktop /usr/share/xsessions/*.desktop; do
    [[ -e "$file" ]] || continue
    session="$(basename "$file" .desktop)"
    case "$session" in
      hyprland*) continue ;;
    esac
    found+=("session: ${session}")
  done

  if (( ${#found[@]} == 0 )); then
    ok "No existing desktop or display manager found."
    return 0
  fi

  warn "Found an existing desktop setup:"
  printf '  - %s\n' "${found[@]}" >&2
  warn "This installer is meant for a system without a desktop."
  warn "Enabling the Noctalia Greeter will disable any display manager listed above."
  ask_yes_no "Continue anyway?" n || die "Aborted."
}
