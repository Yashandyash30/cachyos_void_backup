#!/usr/bin/env bash
set -e

BACKUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$BACKUP_DIR"

echo "============================================="
echo "   CachyOS Configuration & Package Restore   "
echo "============================================="

# 1. Packages
read -p "Do you want to install Native & AUR packages now? (y/N): " -r install_pkg
if [[ $install_pkg =~ ^[Yy]$ ]]; then
    echo "==> Updating system databases..."
    sudo pacman -Sy

    # Keeping power-profiles-daemon as system power daemon (tuned/tuned-ppd removed from pkglist)

    # Read native packages into array
    native_pkgs=()
    if [ -f pkglist/packages-native.txt ]; then
        while IFS= read -r line || [ -n "$line" ]; do
            pkg=$(echo "$line" | sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
            [ -n "$pkg" ] && native_pkgs+=("$pkg")
        done < pkglist/packages-native.txt
    fi

    if [ ${#native_pkgs[@]} -gt 0 ]; then
        echo "==> Installing ${#native_pkgs[@]} Native packages..."
        if ! sudo pacman -S --needed --noconfirm "${native_pkgs[@]}"; then
            echo "==> Batch install hit an error. Retrying individual packages..."
            for pkg in "${native_pkgs[@]}"; do
                sudo pacman -S --needed --noconfirm "$pkg" 2>/dev/null || echo "  [!] Skipped: $pkg"
            done
        fi
    fi

    # Ensure AUR helper (paru) exists; CachyOS has it in its official repos
    if ! command -v paru &>/dev/null && ! command -v yay &>/dev/null; then
        echo "==> AUR helper not found. Installing paru from CachyOS repository..."
        sudo pacman -S --needed --noconfirm paru || true
    fi

    # Read AUR packages into array
    aur_pkgs=()
    if [ -f pkglist/packages-aur.txt ]; then
        while IFS= read -r line || [ -n "$line" ]; do
            pkg=$(echo "$line" | sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
            [ -n "$pkg" ] && aur_pkgs+=("$pkg")
        done < pkglist/packages-aur.txt
    fi

    if [ ${#aur_pkgs[@]} -gt 0 ]; then
        echo "==> Installing ${#aur_pkgs[@]} AUR packages..."
        AUR_HELPER=""
        command -v paru &>/dev/null && AUR_HELPER="paru"
        [ -z "$AUR_HELPER" ] && command -v yay &>/dev/null && AUR_HELPER="yay"

        if [ -n "$AUR_HELPER" ]; then
            if ! "$AUR_HELPER" -S --needed --noconfirm "${aur_pkgs[@]}"; then
                echo "==> Batch AUR install hit an error. Retrying individual AUR packages..."
                for apkg in "${aur_pkgs[@]}"; do
                    "$AUR_HELPER" -S --needed --noconfirm "$apkg" 2>/dev/null || echo "  [!] Skipped AUR package: $apkg"
                done
            fi
        else
            echo "  [!] Neither paru nor yay is available. Skipping AUR packages."
        fi
    fi

    # Flatpaks
    if [ -f pkglist/flatpaks.txt ] && command -v flatpak &>/dev/null; then
        echo "==> Installing Flatpaks..."
        while IFS= read -r app || [ -n "$app" ]; do
            app_clean="$(echo "$app" | tr -d '\r\n[:space:]')"
            [ -n "$app_clean" ] && flatpak install -y flathub "$app_clean" 2>/dev/null || true
        done < pkglist/flatpaks.txt
    fi
fi

# Miniforge3 (conda / mamba) check
if [ ! -d "$HOME/miniforge3" ]; then
    echo ""
    read -p "Miniforge3 (conda/mamba) is not installed in ~/miniforge3. Download & install now? (y/N): " -r install_mamba
    if [[ $install_mamba =~ ^[Yy]$ ]]; then
        echo "==> Downloading and installing Miniforge3..."
        curl -L -o /tmp/Miniforge3.sh "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh"
        bash /tmp/Miniforge3.sh -b -p "$HOME/miniforge3"
        rm -f /tmp/Miniforge3.sh
        echo "  [✓] Miniforge3 installed to $HOME/miniforge3"
    fi
fi

# 2. Configurations
echo "==> Restoring desktop, window manager, and shell configurations..."
mkdir -p ~/.config

# Niri
if [ -d "$BACKUP_DIR/niri" ]; then
    if [ -d ~/.config/niri ] && [ ! -L ~/.config/niri ]; then
        echo "  [*] Backing up existing ~/.config/niri directory..."
        mv ~/.config/niri ~/.config/niri.bak_$(date +%s)
    fi
    ln -sfn "$BACKUP_DIR/niri" ~/.config/niri
    echo "  [✓] Linked ~/.config/niri"
fi

# DankMaterialShell
if [ -d "$BACKUP_DIR/DankMaterialShell" ]; then
    mkdir -p ~/.config/DankMaterialShell
    rsync -av --no-owner --no-group "$BACKUP_DIR/DankMaterialShell/" ~/.config/DankMaterialShell/
    echo "  [✓] Restored ~/.config/DankMaterialShell"
fi

# Fish shell
if [ -d "$BACKUP_DIR/fish" ]; then
    mkdir -p ~/.config/fish
    rsync -av "$BACKUP_DIR/fish/" ~/.config/fish/
    echo "  [✓] Restored ~/.config/fish (including all custom functions)"
fi

# GTK Themes & Styling
if [ -d "$BACKUP_DIR/gtk" ]; then
    [ -d "$BACKUP_DIR/gtk/gtk-3.0" ] && rsync -av "$BACKUP_DIR/gtk/gtk-3.0/" ~/.config/gtk-3.0/
    [ -d "$BACKUP_DIR/gtk/gtk-4.0" ] && rsync -av "$BACKUP_DIR/gtk/gtk-4.0/" ~/.config/gtk-4.0/
    echo "  [✓] Restored GTK-3.0 & GTK-4.0 styles"
fi

# Terminal & System tools
if [ -d "$BACKUP_DIR/terminal" ]; then
    [ -d "$BACKUP_DIR/terminal/alacritty" ] && rsync -av "$BACKUP_DIR/terminal/alacritty/" ~/.config/alacritty/
    [ -d "$BACKUP_DIR/terminal/ghostty" ] && rsync -av "$BACKUP_DIR/terminal/ghostty/" ~/.config/ghostty/
    [ -d "$BACKUP_DIR/terminal/cava" ] && rsync -av "$BACKUP_DIR/terminal/cava/" ~/.config/cava/
    [ -d "$BACKUP_DIR/terminal/fastfetch" ] && rsync -av "$BACKUP_DIR/terminal/fastfetch/" ~/.config/fastfetch/
    [ -d "$BACKUP_DIR/terminal/btop" ] && rsync -av "$BACKUP_DIR/terminal/btop/" ~/.config/btop/
    echo "  [✓] Restored Alacritty, Ghostty, Cava, Fastfetch, and Btop"
fi

# Environment
if [ -d "$BACKUP_DIR/environment.d" ]; then
    mkdir -p ~/.config/environment.d
    rsync -av "$BACKUP_DIR/environment.d/" ~/.config/environment.d/
    echo "  [✓] Restored ~/.config/environment.d"
fi

# 3. Enable Desktop Services
echo "==> Enabling desktop and user services..."
systemctl --user daemon-reload
systemctl --user enable --now dms.service 2>/dev/null || true
systemctl --user enable --now syncthing.service 2>/dev/null || true

# 4. Live Reload Compositor
if command -v niri &>/dev/null && [ -n "$WAYLAND_DISPLAY" ]; then
    echo "==> Reloading Niri configuration live..."
    niri msg action reload-config 2>/dev/null || true
fi

# 5. Configure SDDM Autologin
echo ""
read -p "Do you want to configure SDDM Autologin into Niri (as per autologin.md)? (y/N): " -r setup_autologin
if [[ $setup_autologin =~ ^[Yy]$ ]]; then
    echo "==> Configuring SDDM Autologin for user $(whoami) into Niri..."
    sudo mkdir -p /etc/sddm.conf.d
    sudo tee /etc/sddm.conf.d/autologin.conf > /dev/null << EOF
[Autologin]
User=$(whoami)
Session=niri
EOF
    echo "  [✓] Configured /etc/sddm.conf.d/autologin.conf"

    if command -v sddm &>/dev/null; then
        sudo systemctl disable greetd.service 2>/dev/null || true
        sudo systemctl enable sddm.service 2>/dev/null || true
        echo "  [✓] Enabled sddm.service (DMS will lock screen on startup)"
    fi
fi

echo ""
echo "============================================="
echo "   Restore Completed Successfully!          "
echo "   DankMaterialShell & Niri are active.     "
echo "============================================="
