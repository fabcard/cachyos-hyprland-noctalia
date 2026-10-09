# Changelog

## v0.1.0

First tagged release.

- Installer for Hyprland (0.55+, Lua config, UWSM session), Noctalia Shell and Noctalia Greeter on CachyOS without a desktop.
- GNOME apps, Brave, kitty, GTK and Qt theming from Noctalia templates (btop, GTK 3, GTK 4, KColorScheme, kitty, Qt), plus the community templates for Brave Origin and fastfetch.
- Wallpaper pack (optional) and passwordless wallpaper sync to the login screen (optional).
- Bibata Modern Ice (dark) and Bibata Modern Classic (light) cursors. The cursor follows the Noctalia theme mode through a Noctalia hook.
- Install a fixed version with `CHN_REF=<tag>`.
- `--uninstall`: disables the greeter, moves the installed configs aside, restores the old files from the backup and removes the cursors.
- CI: ShellCheck, `bash -n`, TOML and Lua syntax checks.
