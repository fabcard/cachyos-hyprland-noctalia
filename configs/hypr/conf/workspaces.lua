-- Workspace rules. See https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/
--
-- "gaming" is the workspace games are sent to. The rules for it are in rules.lua.
-- NUM_WPM workspaces are created for each monitor, numbered in blocks:
-- monitor 1 gets 1..NUM_WPM, monitor 2 the next block, and so on.
-- Only monitors with a name in variables.lua get workspaces (monitor 1 always does).

hl.workspace_rule({ workspace = "name:gaming", monitor = PRIMARY_MONITOR })

local monitors = { MONITOR1, MONITOR2, MONITOR3 }
local id = 0

for index, monitor in ipairs(monitors) do
  if monitor ~= "" or index == 1 then
    for i = 1, NUM_WPM do
      id = id + 1
      hl.workspace_rule({
        workspace = tostring(id),
        monitor = monitor,
        default = (i == 1),
        persistent = true,
      })
    end
  end
end

-- For other layouts such as scrolling, add layout = "scrolling" to a rule.
