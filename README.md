# cachyos-hyprland-noctalia

Installer for a lean Hyprland desktop with the Noctalia Shell and the Noctalia Greeter, made for a fresh CachyOS install without a desktop.

> **Status:** early release. Built for CachyOS. Other Arch-based systems may work, but the installer warns you first.

## Install

Run this from a TTY, as your normal user (not root):

```sh
curl -fsSL https://raw.githubusercontent.com/fabcard/cachyos-hyprland-noctalia/main/install.sh | bash
```

Piping a script into a shell runs code you have not read. To read it first:

```sh
curl -fsSL https://github.com/fabcard/cachyos-hyprland-noctalia/archive/refs/heads/main.tar.gz | tar -xz
cd cachyos-hyprland-noctalia-main
less install.sh scripts/*.sh
bash install.sh
```

## Requirements

- CachyOS installed without a desktop environment or window manager.
- A working internet connection and a user with `sudo`.
- Hyprland 0.55 or newer, because the configuration is written in Lua. The installer stops if the version is older.
- On CachyOS, the `cachyos-extra-v3` repository must be enabled. The `noctalia` package comes from it.

## What it does

1. Checks the system: not root, CachyOS or Arch-based, internet, sudo, and no other desktop or display manager (it asks before continuing if it finds one).
2. Asks four questions, then runs without interruptions:
   - Install Bluetooth packages and enable the service? (default: no)
   - Install network share (SMB) support for Nautilus? (default: no)
   - Download the wallpaper pack to `~/Pictures/Wallpapers`? (default: no)
   - Sync wallpaper and colors to the login screen without a password prompt? (default: no)
3. Runs a full system update (`pacman -Syu`) and installs the packages.
4. Writes the greetd configuration and enables the services.
5. Installs the configuration files, backing up anything it replaces.

### Packages

- Session: `hyprland`, `uwsm`, `xdg-desktop-portal-hyprland`, `xdg-desktop-portal-gtk`, `noctalia`, `greetd`, `noctalia-greeter`
- System: `pipewire`, `wireplumber`, `pipewire-pulse`, `networkmanager`, `polkit`, `gnome-keyring`, `dconf`, `xdg-utils`
- Clipboard and screenshots: `wl-clipboard`, `grim`, `slurp`, `satty`
- Terminal and theme: `kitty`, `nwg-look`, `adw-gtk-theme`, `adwaita-icon-theme`, `qt6ct`, `qt6-wayland`
- Apps: `nautilus`, `loupe`, `papers`, `gnome-text-editor`, `gnome-calculator`, `decibels`, `showtime`, `brave-origin-bin`
- Disks and files: `gvfs`, `gvfs-mtp`, `udisks2`, `exfatprogs`, `ntfs-3g`
- Fonts: `ttf-jetbrains-mono-nerd`, `noto-fonts`, `noto-fonts-emoji`
- Optional: `bluez`, `bluez-utils`, `gvfs-smb`

Everything comes from the repositories. No AUR helper is installed. If a package is missing from the repositories, the installer only tries the AUR when `shelly`, `paru` or `yay` is already on the system, and it asks first.

### Services

`NetworkManager` and `greetd` are enabled (plus `bluetooth` if you chose it). `greetd` is not started right away, because that would end the TTY the installer runs in. The login screen appears after a reboot.

### Configuration

Files are copied to `~/.config` with the keyboard layout (read from the system, default `us`) and the browser desktop file filled in.

- `~/.config/hypr/hyprland.lua` loads one file per topic from `~/.config/hypr/conf/`: monitors, input, look, animations, workspaces, rules, keybinds and autostart.
- `~/.config/noctalia/`: dark theme, wallpaper folder, and the GTK and Qt theme templates.
- `~/.config/uwsm/env` and `env-hyprland`: cursor and Qt theme variables.
- `~/.config/kitty/kitty.conf`, `~/.config/gtk-3.0/settings.ini`, `~/.config/gtk-4.0/settings.ini`, `~/.config/qt6ct/qt6ct.conf`
- `~/.config/mimeapps.list`: Brave, Nautilus, Loupe, Showtime, Decibels, Papers and GNOME Text Editor. Entries for apps that are not installed are left out.
- `/etc/greetd/config.toml` and `/var/lib/noctalia-greeter/greeter.toml` for the login screen.

Dark mode is on, with `adw-gtk3-dark`, the Adwaita icons and the Adwaita cursor.

Choices you make later in the Noctalia settings window are saved by Noctalia in `~/.local/state/noctalia/settings.toml`. They take priority over the files in `~/.config/noctalia/`, and the installer never touches that file.

## Keybinds

The layout follows the CachyOS Hyprland + Noctalia setup. `SUPER` is the main key.

Apps:
- `SUPER + Return`: terminal
- `SUPER + E`: files
- `SUPER + W`: browser
- `SUPER + T`: text editor
- `SUPER + C`: calculator

Noctalia:
- `SUPER + Space`: launcher
- `SUPER + .`: emoji picker
- `SUPER + V`: clipboard history
- `SUPER + X`: control center
- `SUPER + A`: notifications
- `SUPER + Z`: Noctalia settings
- `SUPER + SHIFT + W`: wallpaper picker
- `SUPER + L`: lock screen
- `SUPER + ALT + C`: session menu (lock, log out, reboot, shut down)
- `SUPER + Tab`: window switcher
- `Print`: screenshot of a region, `SUPER + Print`: full screen

Windows:
- `SUPER + Q`: close
- `SUPER + F`: fullscreen, `SUPER + D`: maximize
- `SUPER + ALT + Space`: toggle floating
- `SUPER + J`: toggle split
- `SUPER + arrows`: move focus, add `SHIFT` to move the window
- `SUPER + Escape`: click a window to kill it
- `SUPER + mouse drag`: move (left button) or resize (right button)
- `SUPER + minus` and `SUPER + plus`: zoom

Workspaces:
- `SUPER + 1..0`: switch workspace, add `SHIFT` to move the window there
- `SUPER + CONTROL + left/right`: previous or next workspace, add `SHIFT` to move the window
- `SUPER + CONTROL + down`: next empty workspace
- `SUPER + S`: scratchpad, `SUPER + SHIFT + S`: move the window to it

Volume, media and brightness keys work through Noctalia.

## After the install

1. Reboot.
2. At the login screen, pick the **Hyprland (uwsm-managed)** session. The greeter remembers your choice.
3. Pick a wallpaper in the Noctalia settings.
4. If the Qt theme looks off, open `qt6ct` once, select the `noctalia` color scheme and apply. In the Noctalia settings under Templates, check that GTK 3, GTK 4 and Qt are on.

## Backups and rerunning

Before replacing a file, the installer copies the old one to `~/.config-backup-YYYYMMDD-HHMMSS/`. Running the installer again is safe: packages already installed are skipped, files that did not change are left alone, and wallpapers you already have are kept.

To restore a file, copy it back from the backup folder.

## Login screen sync

If you answer yes to the sync question, the installer runs `sudo noctalia-greeter passwordless-sync enable "$USER"` and turns on `auto_sync` in `~/.config/noctalia/greeter-sync.toml`. Changing the wallpaper or the theme then updates the login screen without a password prompt.

The rule written by the greeter only allows its constrained appearance sync, only for your user, and only from an active local session. It needs Noctalia Greeter 1.5.0 or newer. If the command fails, the installer leaves auto-sync off.

To undo it:

```sh
sudo noctalia-greeter passwordless-sync disable "$USER"
rm ~/.config/noctalia/greeter-sync.toml
```

## Options

Set these before the command:

- `CHN_REF=<branch, tag or commit>`: version to download when you use `curl | bash`. The default is `main`.
- `CHN_DEFAULTS=1`: never ask questions, use the default answer for each one.

```sh
curl -fsSL https://raw.githubusercontent.com/fabcard/cachyos-hyprland-noctalia/main/install.sh | CHN_DEFAULTS=1 bash
```

## Troubleshooting

- **Black screen or no login screen:** press `Ctrl + Alt + F2`, log in, then run `sudo systemctl disable greetd` and reboot.
- **Check the Noctalia config:** `noctalia config validate`
- **Hyprland too old:** run `sudo pacman -Syu` and try again. The installer needs 0.55 or newer.
- **`noctalia` not found:** the `cachyos-extra-v3` repository is missing from `/etc/pacman.conf`, or the CPU does not support x86-64-v3.

## Credits

- [Hyprland](https://hypr.land/) and its [wiki](https://wiki.hypr.land/)
- [Noctalia](https://docs.noctalia.dev/)
- The CachyOS Hyprland setup, used as a reference for the config layout and keybinds
- Wallpapers (optional download): [minimalistic-wallpaper-collection](https://github.com/DenverCoder1/minimalistic-wallpaper-collection). The images belong to their original artists.

## License

MIT. See [LICENSE](LICENSE).
