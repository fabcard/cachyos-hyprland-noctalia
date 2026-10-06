-- Miscellaneous settings. Mostly from the CachyOS Hyprland setup (tuned for games).
-- See https://wiki.hypr.land/Configuring/Basics/Variables/

hl.config({
  dwindle = {
    preserve_split = true,
  },
  ecosystem = {
    no_update_news = true,
    no_donation_nag = true,
  },
  misc = {
    col = {
      splash = CACHYLGREEN,
    },
    -- Noctalia draws the wallpaper, so hide the Hyprland ones.
    force_default_wallpaper = 0,
    disable_hyprland_logo = true,

    middle_click_paste = false,
    enable_swallow = true,
    swallow_regex = "(kitty|ghostty|[Kk]onsole|Alacritty|gnome-terminal|xfce[0-9]?-terminal)",
    vrr = 3, -- adaptive sync only for fullscreen games
  },
  render = {
    direct_scanout = 2, -- only for games
    -- Use the option below if games black screen for a couple of seconds
    -- whenever direct scanout turns on or off:
    -- non_shader_cm = 0,
  },
  xwayland = {
    force_zero_scaling = true,
  },
})
