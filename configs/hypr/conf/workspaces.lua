-- Workspace rules. See https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/
--
-- Steam and its games get the two workspaces after the last numbered one
-- (4 and 5 with one monitor and NUM_WPM = 3). They are not persistent: they
-- appear in the bar when a window is on them. The rules that use them are in rules.lua.
-- NUM_WPM workspaces are created for each monitor, numbered in blocks:
-- monitor 1 gets 1..NUM_WPM, monitor 2 the next block, and so on.
-- Only monitors with a name in variables.lua get workspaces (monitor 1 always does).

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

STEAM_WORKSPACE = tostring(id + 1)
GAMES_WORKSPACE = tostring(id + 2)
hl.workspace_rule({ workspace = STEAM_WORKSPACE, monitor = PRIMARY_MONITOR })
hl.workspace_rule({ workspace = GAMES_WORKSPACE, monitor = PRIMARY_MONITOR })

-- For other layouts such as scrolling, add layout = "scrolling" to a rule.
