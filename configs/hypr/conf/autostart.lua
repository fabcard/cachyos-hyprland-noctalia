-- Autostart. Noctalia is started by the compositor, as its documentation recommends.
-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

hl.on("hyprland.start", function()
  hl.exec_cmd("noctalia")
  hl.exec_cmd("hyprctl setcursor @CURSOR_THEME@ 24")

  -- First login only: create the user folders and add them to the Nautilus
  -- sidebar. GNOME and KDE do this on their own, Hyprland does not.
  -- Once the bookmarks file exists this does nothing.
  hl.exec_cmd("test -f ~/.config/gtk-3.0/bookmarks || xdg-user-dirs-gtk-update")
end)
