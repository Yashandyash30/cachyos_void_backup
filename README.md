# CachyOS Personal Configuration & Backup

Complete backup repository for dotfiles, shell functions, window manager settings, themes, and curated package lists.

## 🚀 Quick Setup on Fresh Install

For a full step-by-step walkthrough covering disk partitioning, Windows dual-boot order, and post-install services, see:
👉 **[SETUP_GUIDE.md](./SETUP_GUIDE.md)**

### Quick Restore Commands

1. **Clone this repository:**
   ```bash
   git clone https://github.com/Yashandyash30/cachyos_void_backup.git ~/cachyos_void_backup
   cd ~/cachyos_void_backup
   ```
2. **Run the automated restore script:**
   ```bash
   ./restore.sh
   ```
3. **Restore SSH keys & wallpapers from your USB:**
   ```bash
   tar -xzvf /path/to/usb/ssh_and_secrets_backup.tar.gz -C ~/
   chmod 700 ~/.ssh && chmod 600 ~/.ssh/id_ed25519
   tar -xzvf /path/to/usb/wallpapers_backup.tar.gz -C ~/Pictures/
   ```
4. **Log out and log back in.**

---

## 📂 Repository Structure

- `DankMaterialShell/`: Full DMS settings, custom themes (`gruvboxMulti`, `catppuccin`, `retrobox`), plugins, and CSS overrides.
- `fish/`: Complete Fish shell configuration including 35+ custom functions (`pcsunshinescreen`, `mountsurya`, `transfer`, `ssh*`, etc.).
- `niri/`: Niri Wayland window manager configuration (dual-monitor setup, input, rules, DMS includes).
- `gtk/`: GTK-3.0 and GTK-4.0 styling and custom CSS.
- `terminal/`: Alacritty, Ghostty, Cava (shaders/themes), Fastfetch, and Btop configs.
- `environment.d/`: Desktop environment variables.
- `etc/greetd/`: Greetd login manager and DMS greeter configurations.
- `pkglist/`:
  - `packages-native.txt`: Curated native Arch/CachyOS packages (Nvidia drivers removed).
  - `packages-aur.txt`: Curated AUR packages (laptop battery drivers removed).
  - `flatpaks.txt`: User Flatpak applications.
  - `vscode-extensions.txt`: Installed VS Code extensions.
- `restore.sh`: Interactive 1-click restore script.
- `sync.sh`: Script to automatically push future updates to GitHub.
- `SETUP_GUIDE.md`: Comprehensive fresh installation guide.

---

## 🔄 How to Sync Changes in the Future

Whenever you make changes to your dotfiles or install new packages:
```bash
~/cachyos_void_backup/sync.sh
```
