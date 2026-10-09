# CachyOS Personal Configuration & Backup

Clean backup of dotfiles, shell functions, window manager settings, themes, and curated package lists.

## Structure

- `DankMaterialShell/`: Full DankMaterialShell settings, custom themes (`gruvboxMulti`, `catppuccin`, `retrobox`), plugins, and CSS overrides.
- `fish/`: Complete Fish shell configuration including 35+ custom functions (`pcsunshinescreen`, `mountsurya`, `transfer`, `ssh*`, etc.).
- `niri/`: Niri Wayland scrollable-tiling window manager configuration.
- `gtk/`: GTK-3.0 and GTK-4.0 styling and custom CSS.
- `terminal/`: Alacritty, Cava, Fastfetch, and Btop configs.
- `environment.d/`: Desktop environment variables.
- `pkglist/`:
  - `packages-native.txt`: Curated native Arch/CachyOS packages (Nvidia drivers removed for AMD desktop).
  - `packages-aur.txt`: Curated AUR packages (laptop battery drivers removed).
  - `flatpaks.txt`: User Flatpak applications.

## How to Restore on a Fresh Install

1. Clone this repository:
   ```bash
   git clone https://github.com/Yashandyash30/cachyos_void_backup.git ~/cachyos_void_backup
   cd ~/cachyos_void_backup
   ```
2. Run the restore script:
   ```bash
   ./restore.sh
   ```
3. Log out and log back into your Niri session.

## How to Sync Changes in the Future

Run:
```bash
./sync.sh
```
