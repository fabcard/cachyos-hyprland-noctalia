-- Monitors. See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- The output names come from variables.lua.
--
-- Examples:
--   mode = "highrr"           highest refresh rate
--   mode = "2560x1440@144"    fixed resolution and refresh rate
--   scale = 1                 fixed scale instead of "auto"

hl.monitor({
  output   = MONITOR1,
  mode     = "preferred",
  position = "auto",
  scale    = "auto",
})
