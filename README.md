# cachyos-hyprland-noctalia

Installer for a lean Hyprland desktop with the Noctalia Shell and the Noctalia Greeter, made for a fresh CachyOS install without a desktop.

The look, the keybinds, the animations and the window rules follow the CachyOS Hyprland + Noctalia setup. This project adds an installer for a minimal system, GNOME apps, a wallpaper pack, wallpaper sync to the login screen without a password, and the Bibata cursor.

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
3. Runs a full system update (`pacman -Syu`), installs the packages and downloads the cursor theme.
4. Writes the greetd configuration and enables the services.
5. Installs the configuration files, backing up anything it replaces.

### Packages

- Session: `hyprland`, `uwsm`, `xdg-desktop-portal-hyprland`, `xdg-desktop-portal-gtk`, `noctalia`, `greetd`, `noctalia-greeter`
- System: `pipewire`, `wireplumber`, `pipewire-pulse`, `networkmanager`, `polkit`, `gnome-keyring`, `dconf`, `xdg-utils`
- Clipboard, screenshots and tools: `wl-clipboard`, `grim`, `slurp`, `satty`, `hyprpicker`, `btop`, `fastfetch`
- Terminal and theme: `kitty`, `nwg-look`, `adw-gtk-theme`, `adwaita-icon-theme`, `breeze-icons`, `qt6ct`, `qt6-wayland`
- Apps: `nautilus`, `loupe`, `papers`, `gnome-text-editor`, `gnome-calculator`, `decibels`, `showtime`, `brave-origin-bin`
- Disks and files: `gvfs`, `gvfs-mtp`, `udisks2`, `exfatprogs`, `ntfs-3g`, `xdg-user-dirs-gtk`
- Fonts: `ttf-jetbrains-mono-nerd`, `noto-fonts`, `noto-fonts-emoji`
- Optional: `bluez`, `bluez-utils`, `gvfs-smb`

Everything comes from the repositories, except the cursor theme (see below). No AUR helper is installed. If a package is missing from the repositories, the installer only tries the AUR when `shelly`, `paru` or `yay` is already on the system, and it asks first.

### Cursor

Bibata Modern Ice (dark mode) and Bibata Modern Classic (light mode) are downloaded from the [upstream releases](https://github.com/ful1e5/Bibata_Cursor/releases) (version pinned in `scripts/packages.sh`, SHA-256 pinned) and installed to `/usr/share/icons`. Every toolkit searches that folder, and every user can read it, including the greeter, which runs as a different user. If the Ice download fails, the installer uses the Adwaita cursor and keeps going. If the Classic download fails, light mode keeps the dark cursor.

The cursor is applied to Hyprland, GTK, X11 apps, Qt and the login screen (Ice).

The cursor follows the Noctalia theme mode. `~/.config/noctalia/hooks.toml` runs `~/.config/noctalia/hooks/cursor-sync.sh` when Noctalia starts and whenever the mode changes. The script sets `gsettings` (open GTK apps change at once), `hyprctl setcursor` and `XCURSOR_THEME` in the systemd user environment (apps started later). Qt apps that are already open keep the old cursor until restarted. No Noctalia reload is needed.

The folders are not owned by any package. If a package ever ships the same folders, remove them first: `sudo rm -rf /usr/share/icons/Bibata-Modern-Ice /usr/share/icons/Bibata-Modern-Classic`.

### Services

`NetworkManager` and `greetd` are enabled (plus `bluetooth` if you chose it). `greetd` is not started right away, because that would end the TTY the installer runs in. The login screen appears after a reboot.

### Configuration

Files are copied to `~/.config`. The installer fills in the keyboard layout (read from the system, default `us`), the browser desktop file, the cursor theme and the names of the connected monitors (read from `/sys/class/drm`).

- `~/.config/hypr/hyprland.lua` loads one file per topic from `~/.config/hypr/conf/`: `colors`, `variables`, `monitors`, `input`, `look`, `animations`, `misc`, `workspaces`, `rules`, `keybinds` and `autostart`. App names and monitor names live in `variables.lua`.
- `~/.config/hypr/xdph.conf`: screen sharing remembers its permission.
- `~/.config/noctalia/`: dark mode, wallpaper folder, the polkit agent, the theme templates (see below) and the cursor hook.
- `~/.config/kdeglobals`: selects the Noctalia color scheme for KDE-framework apps. Created only if it does not exist, because Noctalia may edit it later.
- `~/.config/uwsm/env` and `env-hyprland`: cursor, Qt and Electron variables.
- `~/.config/kitty/kitty.conf`, `~/.config/gtk-3.0/`, `~/.config/gtk-4.0/`, `~/.config/qt6ct/qt6ct.conf`, `~/.icons/default/index.theme`
- `~/.config/mimeapps.list`: Brave, Nautilus, Loupe, Showtime, Decibels, Papers and GNOME Text Editor. Entries for apps that are not installed are left out.
- `/etc/greetd/config.toml` and `/var/lib/noctalia-greeter/greeter.toml` for the login screen.

Dark mode is on, with `adw-gtk3-dark` and the Adwaita icons for GTK apps, and the Breeze Dark icons for Qt and KDE-framework apps (`breeze-icons`).

### Theme templates

Noctalia colors these apps, and the installer turns the templates on: GTK 3 and GTK 4 (GNOME apps), Qt (through `qt6ct`), KColorScheme (apps built with KDE frameworks, such as EasyEffects), kitty and btop. Community templates for Brave Origin and fastfetch are on too. Noctalia fetches them from `api.noctalia.dev`, so they need internet on the first theme change. Other templates (other terminals, editors, compositors) are off. Turn them on in Noctalia Settings > Templates if you install those apps.

Qt apps need two things to open dark. `qt6ct` gives the palette to plain Qt apps. The KColorScheme template and `~/.config/kdeglobals` give the colors to apps built with KDE frameworks, which ignore `qt6ct`.

Choices you make later in the Noctalia settings window are saved by Noctalia in `~/.local/state/noctalia/settings.toml`. They take priority over the files in `~/.config/noctalia/`, and the installer never touches that file.

## Gaming

Games are sent to a workspace named `gaming` on the primary monitor. The rules match Steam games (`steam_app.*`), `gamescope`, and windows that report themselves as games. They also start those games fullscreen. Adaptive sync (`vrr`) and direct scanout are on for fullscreen games only.

## Keybinds

These are the CachyOS keybinds. `SUPER` is the main key. Run `hyprctl binds` to see them all.

Apps:
- `SUPER + Return`: terminal
- `SUPER + E`: files
- `SUPER + W`: browser
- `SUPER + T`: text editor
- `SUPER + C`: calculator
- `CONTROL + SHIFT + Escape`: btop
- `SUPER + P`: color picker

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
- `SUPER + Escape`: click a window to kill it
- `SUPER + arrows`: move focus, add `SHIFT` to move the window
- `ALT + Tab`: cycle windows
- `SUPER + mouse drag`: move (left button) or resize (right button)
- `SUPER + minus` and `SUPER + plus`: zoom

Workspaces and monitors:
- `SUPER + ALT + 1..0`: go to a workspace by number
- `SUPER + CONTROL + 1..0`: go to a workspace of the current monitor (with 3 workspaces per monitor)
- `SUPER + CONTROL + left/right`: previous or next workspace, `down`: next empty one
- `SUPER + SHIFT + CONTROL + 1..0`: move the window to a workspace of the current monitor, use `ALT` instead of `CONTROL` to stay where you are
- `SUPER + 1..3`: focus monitor 1 to 3, add `SHIFT` to move the window there
- `SUPER + S`: scratchpad, `SUPER + SHIFT + S`: move the window to it

Volume, media and brightness keys work through Noctalia.

The number of workspaces per monitor is `NUM_WPM` in `~/.config/hypr/conf/variables.lua`.

## After the install

1. Reboot.
2. At the login screen, the Hyprland (uwsm-managed) session is already selected.
3. Pick a wallpaper in the Noctalia settings.
4. If the Qt theme looks off, open `qt6ct` once, select the `noctalia` color scheme and apply. In the Noctalia settings under Templates, check that GTK 3, GTK 4, Qt, KColorScheme, kitty and btop are on.

## Backups and rerunning

Before replacing a file, the installer copies the old one to `~/.config-backup-YYYYMMDD-HHMMSS/`. Running the installer again is safe: packages already installed are skipped, files that did not change are left alone, and wallpapers you already have are kept.

To restore a file, copy it back from the backup folder.

## Login screen sync

If you answer yes to the sync question, the installer runs `sudo noctalia-greeter passwordless-sync enable "$USER"` and turns on `auto_sync` in `~/.config/noctalia/greeter-sync.toml`. Changing the wallpaper or the theme then updates the login screen without a password prompt. The login screen also uses the synced colors.

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
- **Wrong monitor name or no workspaces:** run `hyprctl monitors` and edit `MONITOR1` in `~/.config/hypr/conf/variables.lua`.

## Credits

- [Hyprland](https://hypr.land/) and its [wiki](https://wiki.hypr.land/)
- [Noctalia](https://docs.noctalia.dev/)
- The [CachyOS Hyprland + Noctalia setup](https://github.com/CachyOS/cachyos-hypr-noctalia): keybinds, animations, window rules, colors, look and miscellaneous settings, adapted here.
- [Bibata Cursor](https://github.com/ful1e5/Bibata_Cursor) by ful1e5, downloaded at install time.
- Wallpapers (optional download): [minimalistic-wallpaper-collection](https://github.com/DenverCoder1/minimalistic-wallpaper-collection). The images belong to their original artists.

## License

The installer and the files written for this project are under the MIT license. See [LICENSE](LICENSE). The files adapted from the CachyOS setup keep the license of the original project, so check its repository before reusing them.
