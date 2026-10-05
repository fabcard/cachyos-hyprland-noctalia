-- Persistent workspaces keep empty workspaces visible in the Noctalia bar.
-- To pin workspaces to a monitor, add: monitor = "DP-1"
-- See https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/

for i = 1, 5 do
  hl.workspace_rule({ workspace = tostring(i), persistent = true })
end
