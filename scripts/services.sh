#!/usr/bin/env bash
# Services and greetd setup. Sourced by install.sh.
#
# greetd is only enabled, never started. Starting it from the TTY that runs
# this installer would kill the session. The login screen appears on reboot.

GREETD_CONFIG="/etc/greetd/config.toml"
OTHER_DISPLAY_MANAGERS=(sddm gdm lightdm lxdm ly plasmalogin)

unit_exists() { systemctl cat "$1" >/dev/null 2>&1; }

# Print the user set in the [default_session] section, if any.
greetd_existing_user() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  awk '
    /^[[:space:]]*\[/ { in_ds = ($0 ~ /^[[:space:]]*\[default_session\][[:space:]]*$/) }
    in_ds && /^[[:space:]]*user[[:space:]]*=/ {
      gsub(/^[^"]*"/, ""); gsub(/".*$/, ""); print; exit
    }
  ' "$file"
}

# Print a greetd config whose [default_session] runs the Noctalia Greeter.
# Other sections and keys of an existing file are kept as they are.
# Usage: render_greetd_config <existing-file> <session-command> <greeter-user>
render_greetd_config() {
  local input="$1" session_cmd="$2" greeter_user="$3"

  if [[ ! -f "$input" ]]; then
    printf '[terminal]\nvt = 1\n\n[default_session]\ncommand = "%s"\nuser = "%s"\n' \
      "$session_cmd" "$greeter_user"
    return 0
  fi

  awk -v cmd="command = \"$session_cmd\"" -v usr="user = \"$greeter_user\"" '
    function flush() {
      if (in_ds) {
        if (!c) print cmd
        if (!u) print usr
      }
      in_ds = 0
    }
    /^[[:space:]]*\[/ {
      flush()
      if ($0 ~ /^[[:space:]]*\[default_session\][[:space:]]*$/) {
        in_ds = 1; found = 1; c = 0; u = 0
      }
      print
      next
    }
    in_ds && /^[[:space:]]*command[[:space:]]*=/ { print cmd; c = 1; next }
    in_ds && /^[[:space:]]*user[[:space:]]*=/    { print usr; u = 1; next }
    { print }
    END {
      flush()
      if (!found) {
        print ""
        print "[default_session]"
        print cmd
        print usr
      }
    }
  ' "$input"
}

configure_greetd() {
  local session_cmd greeter_user tmp

  session_cmd="$(command -v noctalia-greeter-session || true)"
  [[ -n "$session_cmd" ]] || die "noctalia-greeter-session not found. Is noctalia-greeter installed?"

  greeter_user="$(greetd_existing_user "$GREETD_CONFIG")"
  greeter_user="${greeter_user:-greeter}"
  id "$greeter_user" >/dev/null 2>&1 \
    || die "The greetd user '$greeter_user' does not exist. Is greetd installed?"

  tmp="$(mktemp)"
  render_greetd_config "$GREETD_CONFIG" "$session_cmd" "$greeter_user" >"$tmp"

  if [[ -f "$GREETD_CONFIG" ]] && cmp -s "$tmp" "$GREETD_CONFIG"; then
    ok "greetd already points to the Noctalia Greeter."
  else
    backup_path "$GREETD_CONFIG"
    sudo install -D -m 0644 "$tmp" "$GREETD_CONFIG"
    ok "Wrote $GREETD_CONFIG (session: $session_cmd, user: $greeter_user)."
  fi

  rm -f "$tmp"
}

# Two display managers enabled together compete for the login screen.
disable_other_display_managers() {
  local unit
  for unit in "${OTHER_DISPLAY_MANAGERS[@]}"; do
    if systemctl is-enabled --quiet "${unit}.service" 2>/dev/null; then
      warn "Disabling display manager: $unit"
      sudo systemctl disable "${unit}.service"
    fi
  done
}

enable_system_units() {
  local units=(NetworkManager.service greetd.service) unit

  if [[ "${INSTALL_BLUETOOTH:-0}" == "1" ]]; then
    units+=(bluetooth.service)
  fi

  for unit in "${units[@]}"; do
    if unit_exists "$unit"; then
      sudo systemctl enable "$unit"
    elif [[ "$unit" == "greetd.service" ]]; then
      die "greetd.service not found. Is greetd installed?"
    else
      warn "Unit $unit not found, skipped."
    fi
  done
}

# PipeWire normally starts through socket activation. Enabling the units is
# harmless and covers systems where the presets did not do it.
enable_user_units() {
  local unit

  if ! systemctl --user show-environment >/dev/null 2>&1; then
    warn "No systemd user session available. Skipping user services (PipeWire usually starts on its own)."
    return 0
  fi

  for unit in pipewire.socket pipewire-pulse.socket wireplumber.service; do
    if systemctl --user cat "$unit" >/dev/null 2>&1; then
      systemctl --user enable "$unit" || warn "Could not enable $unit."
    fi
  done
}

enable_services() {
  step "Configuring greetd"
  configure_greetd

  step "Enabling services"
  disable_other_display_managers
  enable_system_units
  enable_user_units
  ok "Services done. greetd starts on the next boot."
}
