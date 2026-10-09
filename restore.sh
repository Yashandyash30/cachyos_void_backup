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

    echo "==> Installing Native packages (excluding Nvidia)..."
    if [ -f pkglist/packages-native.txt ]; then
        sudo pacman -S --needed --noconfirm - < pkglist/packages-native.txt || true
    fi

    echo "==> Installing AUR packages..."
    if [ -f pkglist/packages-aur.txt ]; then
        if command -v paru &>/dev/null; then
            paru -S --needed --noconfirm - < pkglist/packages-aur.txt || true
        elif command -v yay &>/dev/null; then
            yay -S --needed --noconfirm - < pkglist/packages-aur.txt || true
        else
            echo "Neither paru nor yay found! Please install paru first."
        fi
    fi

    echo "==> Installing Flatpaks..."
    if [ -f pkglist/flatpaks.txt ] && command -v flatpak &>/dev/null; then
        while read -r app; do
            [ -n "$app" ] && flatpak install -y flathub "$app" || true
        done < pkglist/flatpaks.txt
    fi
fi

# 2. Configurations
echo "==> Restoring desktop, window manager, and shell configurations..."
mkdir -p ~/.config

# Niri
if [ -d "$BACKUP_DIR/niri" ]; then
    ln -sfn "$BACKUP_DIR/niri" ~/.config/niri
    echo "  [✓] Linked ~/.config/niri"
fi

# DankMaterialShell
if [ -d "$BACKUP_DIR/DankMaterialShell" ]; then
    mkdir -p ~/.config/DankMaterialShell
    rsync -av "$BACKUP_DIR/DankMaterialShell/" ~/.config/DankMaterialShell/
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

echo ""
echo "============================================="
echo "   Restore Completed Successfully!          "
echo "   Please log out and log back in.          "
echo "============================================="
