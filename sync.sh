#!/usr/bin/env bash
set -e

BACKUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$BACKUP_DIR"

echo "==> Updating package lists..."
mkdir -p pkglist
pacman -Qen | awk '{print $1}' | grep -v -iE "nvidia|bbswitch|bumblebee|prime|optimus|asus|envycontrol" > pkglist/packages-native.txt
pacman -Qqem | grep -v -iE "acer-wmi|nvidia" > pkglist/packages-aur.txt
flatpak list --columns=application | grep -v -iE "nvidia|Application ID" | sed '/^$/d' | sort -u > pkglist/flatpaks.txt

echo "==> Syncing live configs..."
rsync -av --delete --exclude='.git' /home/void/.config/DankMaterialShell/ DankMaterialShell/
rsync -av --delete /home/void/.config/fish/ fish/

mkdir -p gtk terminal environment.d
rsync -av --delete /home/void/.config/gtk-3.0/ gtk/gtk-3.0/
rsync -av --delete /home/void/.config/gtk-4.0/ gtk/gtk-4.0/
rsync -av --delete /home/void/.config/alacritty/ terminal/alacritty/
[ -d /home/void/.config/ghostty ] && rsync -av --delete /home/void/.config/ghostty/ terminal/ghostty/
rsync -av --delete /home/void/.config/cava/ terminal/cava/
rsync -av --delete /home/void/.config/fastfetch/ terminal/fastfetch/
rsync -av --delete /home/void/.config/btop/ terminal/btop/
rsync -av --delete /home/void/.config/environment.d/ environment.d/

echo "==> Staging changes in git..."
git add .

if git diff --cached --quiet; then
    echo "No changes to commit."
else
    git commit -m "Auto-update configs: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "==> Pushing to origin..."
    git push origin master
fi
echo "==> Done!"
