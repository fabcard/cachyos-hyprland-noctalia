-- Autostart.
-- Noctalia is started by the compositor, as its documentation recommends.
-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

hl.on("hyprland.start", function()
  hl.exec_cmd("noctalia")
  hl.exec_cmd("hyprctl setcursor Adwaita 24")
end)
