-- Default apps. keybinds.lua starts them with "uwsm app --".
TERMINAL     = "kitty"
FILE_MANAGER = "nautilus"
BROWSER      = "@BROWSER_DESKTOP@"
EDITOR       = "gnome-text-editor --new-window"
CALCULATOR   = "gnome-calculator"

-- Monitors. The installer fills these in from the connected outputs.
-- Run `hyprctl monitors` to see the names (for example DP-1 or HDMI-A-1).
-- An empty name means "any monitor". PRIMARY_MONITOR and MONITOR1 are usually the same.
MONITOR1 = "@MONITOR1@"
MONITOR2 = "@MONITOR2@"
MONITOR3 = "@MONITOR3@"
PRIMARY_MONITOR = MONITOR1

-- Workspaces per monitor (maximum 10).
NUM_WPM = 3
