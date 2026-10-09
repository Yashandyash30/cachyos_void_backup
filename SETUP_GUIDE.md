# Fresh Installation & Reconfiguration Setup Guide

This guide walks you through migrating **Windows to the 512 GB SSD** and setting up a fresh **CachyOS on the 1 TB SSD** using this backup repository.

---

## Phase 1: Pre-Install Checklist (On Current Machine)

Before wiping or formatting any drive:

1. **Copy your local archives to a USB thumb drive:**
   * `/home/void/ssh_and_secrets_backup.tar.gz` (SSH keys & keyrings)
   * `/home/void/wallpapers_backup.tar.gz` (All wallpapers)
2. **Make sure your installers are ready:**
   * Windows 10/11 bootable USB (created via Rufus or Media Creation Tool)
   * CachyOS bootable USB (created via BalenaEtcher or Ventoy)

---

## Phase 2: OS Installation Order

> [!IMPORTANT]
> **Always install Windows first, then CachyOS second.**
> This ensures Windows cannot overwrite Linux's EFI bootloader.

### Step 1: Install Windows on the 512 GB SSD
1. Boot from the Windows installation USB.
2. Choose **Custom: Install Windows only (advanced)**.
3. Select your **512 GB SSD** (`WDC PC SN530`), delete existing Linux partitions on it, and install Windows.
4. Leave the 1 TB SSD untouched.

### Step 2: Install CachyOS on the 1 TB SSD
1. Boot from the CachyOS live USB.
2. Launch the **CachyOS Calamares Installer**.
3. Select the **1 TB NVMe SSD** (`KIOXIA EXCERIA PLUS`).
4. Choose **Erase disk** with filesystem **Btrfs**.
5. Select **systemd-boot** (or Limine/GRUB) as your bootloader.
6. When prompted for username, set username to **`void`** (matching all paths in your configs).
7. Complete installation and reboot. CachyOS will automatically detect Windows and add it to your boot menu.

---

## Phase 3: Reconfiguration on Fresh CachyOS

Log into your new CachyOS installation and follow these steps in a terminal:

### Step 1: Clone This Backup Repository
```bash
git clone https://github.com/Yashandyash30/cachyos_void_backup.git ~/cachyos_void_backup
cd ~/cachyos_void_backup
```

### Step 2: Run the Automated Restore Script
```bash
./restore.sh
```
This script will:
* Install curated Native packages (with Nvidia drivers removed).
* Install curated AUR packages via `paru` (with laptop battery drivers removed).
* Install your Flatpaks (`Gear Lever`, `KTailctl`).
* Symlink your Niri desktop configs (`~/.config/niri -> ~/cachyos_void_backup/niri`).
* Restore DankMaterialShell, themes, plugins, and CSS.
* Restore Fish shell with all 35 custom functions.
* Restore GTK-3/4 styles, Alacritty, Ghostty, Cava, Fastfetch, and Btop.

---

### Step 3: Restore SSH Keys & Keyrings (From USB)
Plug in your USB drive with `ssh_and_secrets_backup.tar.gz` and run:

```bash
# Extract to home directory
tar -xzvf /path/to/usb/ssh_and_secrets_backup.tar.gz -C ~/

# Enforce secure Linux file permissions
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/config ~/.ssh/id_ed25519.pub ~/.ssh/authorized_keys ~/.ssh/known_hosts 2>/dev/null || true
chmod 700 ~/.local/share/keyrings
```

---

### Step 4: Restore Wallpapers (From USB)
```bash
mkdir -p ~/Pictures
tar -xzvf /path/to/usb/wallpapers_backup.tar.gz -C ~/Pictures/
```

---

### Step 5: Set Default Shell to Fish
If fish is not already your login shell:
```bash
chsh -s /usr/bin/fish
```

Install Fisher and plugins (if not automatically loaded):
```bash
fish -c "fisher update"
```

---

### Step 6: Enable Essential Services
Enable user-level services:
```bash
systemctl --user daemon-reload
systemctl --user enable --now dms.service
systemctl --user enable --now syncthing.service
systemctl --user enable --now app-dev.lizardbyte.app.Sunshine.service 2>/dev/null || true
```

Enable system-level hardware and networking services:
```bash
sudo systemctl enable --now bluetooth.service
sudo systemctl enable --now tailscaled.service
sudo systemctl enable --now sshd.service
```

---

### Step 7: (Optional) Restore Greetd & DMS Greeter
To have the DMS greeter and autologin setup as before:
```bash
sudo cp ~/cachyos_void_backup/etc/greetd/config.toml /etc/greetd/config.toml
sudo cp -r ~/cachyos_void_backup/etc/greetd/niri /etc/greetd/
sudo systemctl enable greetd.service
```

---

### Step 8: (Optional) Rebuild Astrophysics Distrobox Container
If you use the IRAF / PyRAF pipeline configured in `config.fish`:
```bash
distrobox create --name astro-box --image docker.io/library/ubuntu:22.04
```

---

### Step 9: Reboot
```bash
systemctl reboot
```
You are fully configured! Your exact Niri desktop, DankMaterialShell theme, dual monitors, custom terminal shortcuts, and server connections will be live.
