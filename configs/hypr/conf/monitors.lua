-- Monitors. Default: every monitor at its preferred mode, placed automatically.
-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
--
-- Examples:
--   mode = "highrr"           highest refresh rate
--   mode = "2560x1440@144"    fixed resolution and refresh rate
--   scale = 1                 fixed scale instead of "auto"

hl.monitor({
  output = "",
  mode = "preferred",
  position = "auto",
  scale = "auto",
})
