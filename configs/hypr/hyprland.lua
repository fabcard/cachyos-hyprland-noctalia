-- Hyprland main config (Lua, Hyprland 0.55 or newer).
-- Every topic lives in its own file under conf/. Edit those files, not this one.

local config_home = os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or "") .. "/.config")
package.path = config_home .. "/hypr/?.lua;" .. package.path

require("conf.monitors")
require("conf.input")
require("conf.look")
require("conf.animations")
require("conf.workspaces")
require("conf.rules")
require("conf.keybinds")
require("conf.autostart")
