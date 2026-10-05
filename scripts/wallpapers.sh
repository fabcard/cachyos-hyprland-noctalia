#!/usr/bin/env bash
# Wallpaper pack download. Sourced by install.sh, only when the user said yes.
#
# Source: https://github.com/DenverCoder1/minimalistic-wallpaper-collection
# The images are streamed from the repository archive straight into the
# wallpaper folder. Files that already exist are kept, so running again only
# adds what is missing. No git and no temporary copy are needed.

WALLPAPER_REPO="DenverCoder1/minimalistic-wallpaper-collection"
WALLPAPER_REF="main"
WALLPAPER_TARBALL_URL="${WALLPAPER_TARBALL_URL:-https://github.com/${WALLPAPER_REPO}/archive/refs/heads/${WALLPAPER_REF}.tar.gz}"
WALLPAPER_API_URL="https://api.github.com/repos/${WALLPAPER_REPO}"

# Repository size in KB from the GitHub API. Prints nothing when unavailable.
wallpaper_repo_size_kb() {
  curl -fsS --max-time 10 "$WALLPAPER_API_URL" 2>/dev/null \
    | sed -n 's/.*"size": *\([0-9][0-9]*\).*/\1/p' \
    | head -n1
}

install_wallpapers() {
  local dir="${WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}"
  local size_kb avail_kb before after

  step "Downloading wallpapers"

  command -v tar >/dev/null 2>&1 || { warn "tar not found, skipping wallpapers."; return 0; }
  mkdir -p "$dir"

  size_kb="$(wallpaper_repo_size_kb || true)"
  if [[ "$size_kb" =~ ^[0-9]+$ ]]; then
    info "Download size is about $(( size_kb / 1024 )) MB."
    avail_kb="$(df -Pk "$dir" | awk 'NR==2 {print $4}')"
    if [[ "$avail_kb" =~ ^[0-9]+$ ]] && (( avail_kb < size_kb * 12 / 10 )); then
      warn "Not enough free space in $dir ($(( avail_kb / 1024 )) MB free). Skipping wallpapers."
      return 0
    fi
  fi

  info "The wallpapers belong to their original artists; see the repository README for credits."

  before="$(find "$dir" -type f | wc -l)"

  if ! curl -fsSL "$WALLPAPER_TARBALL_URL" \
      | tar -xz -C "$dir" --strip-components=2 --skip-old-files --wildcards '*/images/*'; then
    warn "Wallpaper download failed. Run the installer again later to retry."
    return 0
  fi

  after="$(find "$dir" -type f | wc -l)"
  ok "Wallpapers in $dir: $after files ($(( after - before )) new)."
  info "Pick one in Noctalia: Settings > Wallpaper."
}
