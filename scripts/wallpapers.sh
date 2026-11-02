#!/usr/bin/env bash
# Wallpaper pack download. Sourced by install.sh, only when the user said yes.
#
# Sources:
#   https://github.com/DenverCoder1/minimalistic-wallpaper-collection
#     -> ~/Pictures/Wallpapers/Minimalistic
#   https://gitlab.com/dwt1/wallpapers
#     -> ~/Pictures/Wallpapers/DT
# The images are streamed from the repository archive straight into the
# wallpaper folder. Files that already exist are kept, so running again only
# adds what is missing. No git and no temporary copy are needed.

WALLPAPER_REPO="DenverCoder1/minimalistic-wallpaper-collection"
WALLPAPER_REF="main"
WALLPAPER_TARBALL_URL="${WALLPAPER_TARBALL_URL:-https://github.com/${WALLPAPER_REPO}/archive/refs/heads/${WALLPAPER_REF}.tar.gz}"
WALLPAPER_API_URL="https://api.github.com/repos/${WALLPAPER_REPO}"

# Derek Taylor's collection (GitLab, branch master, images in the repo root).
DT_WALLPAPER_TARBALL_URL="${DT_WALLPAPER_TARBALL_URL:-https://gitlab.com/dwt1/wallpapers/-/archive/master/wallpapers-master.tar.gz}"

# Repository size in KB from the GitHub API. Prints nothing when unavailable.
wallpaper_repo_size_kb() {
  curl -fsS --max-time 10 "$1" 2>/dev/null \
    | sed -n 's/.*"size": *\([0-9][0-9]*\).*/\1/p' \
    | head -n1
}

# download_wallpapers NAME DIR URL API_URL STRIP PATTERN...
# API_URL may be empty: the size check is skipped then.
download_wallpapers() {
  local name="$1" dir="$2" url="$3" api="$4" strip="$5"
  shift 5
  local size_kb avail_kb before after

  step "Downloading wallpapers: $name"
  mkdir -p "$dir"

  size_kb=""
  [[ -n "$api" ]] && size_kb="$(wallpaper_repo_size_kb "$api" || true)"
  if [[ "$size_kb" =~ ^[0-9]+$ ]]; then
    info "Download size is about $(( size_kb / 1024 )) MB."
    avail_kb="$(df -Pk "$dir" | awk 'NR==2 {print $4}')"
    if [[ "$avail_kb" =~ ^[0-9]+$ ]] && (( avail_kb < size_kb * 12 / 10 )); then
      warn "Not enough free space in $dir ($(( avail_kb / 1024 )) MB free). Skipping $name."
      return 0
    fi
  fi

  before="$(find "$dir" -type f | wc -l)"

  if ! curl -fsSL "$url" \
      | tar -xz -C "$dir" --strip-components="$strip" --skip-old-files --wildcards "$@"; then
    warn "Wallpaper download failed ($name). Run the installer again later to retry."
    return 0
  fi

  # Keep images only; drop anything else the archive brought, then empty folders.
  find "$dir" -type f ! \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \
    -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.bmp' \) -delete
  find "$dir" -mindepth 1 -type d -empty -delete

  after="$(find "$dir" -type f | wc -l)"
  ok "Wallpapers in $dir: $after files ($(( after - before )) new)."
}

install_wallpapers() {
  local base="${WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}"

  command -v tar >/dev/null 2>&1 || { warn "tar not found, skipping wallpapers."; return 0; }

  info "The wallpapers belong to their original artists; see each repository README for credits."

  if [[ "$INSTALL_WALLPAPERS_MINIMALISTIC" == "1" ]]; then
    download_wallpapers "Minimalistic" "$base/Minimalistic" "$WALLPAPER_TARBALL_URL" \
      "$WALLPAPER_API_URL" 2 '*/images/*'
  fi
  if [[ "$INSTALL_WALLPAPERS_DT" == "1" ]]; then
    download_wallpapers "DT" "$base/DT" "$DT_WALLPAPER_TARBALL_URL" "" 1 \
      --exclude='*/README*' --exclude='*/LICENSE*' --exclude='*/.git*'
  fi
  info "Pick one in Noctalia: Settings > Wallpaper."
}
