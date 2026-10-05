-- Keyboard and mouse.
-- The layout is read from the system by the installer.

hl.config({
  input = {
    kb_layout = "@KB_LAYOUT@",
    kb_variant = "@KB_VARIANT@",
    kb_model = "",
    kb_options = "",
    kb_rules = "",

    follow_mouse = 1,
    sensitivity = 0, -- -1.0 to 1.0, 0 means no modification

    touchpad = {
      natural_scroll = false,
    },
  },
})
