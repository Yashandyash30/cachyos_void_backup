# CachyOS / Niri System Optimization & ComfyUI Swap Guide

System setup and optimization reference for running Niri Wayland, Dank Material Shell (DMS), and ComfyUI with FLUX / GGUF models on an AMD Radeon GPU (16 GB VRAM) and 16 GB RAM.

---

## 1. System Overview

- **CPU/RAM:** 16 GB Physical RAM + 15.5 GiB ZRAM (`zstd`)
- **GPU:** AMD Radeon RX 9050 / 9060 XT (Navi 44, 16 GiB VRAM)
- **Compositor / Shell:** Niri + Dank Material Shell (QuickShell QML)
- **Filesystem:** Btrfs (`compress=zstd:1`, subvolumes `@`, `@home`, Snapper snapshots)

---

## 2. VRAM & Visual Optimization (Acrylic Glass Preserved)

Dual-kawase blur (`passes 2`) is lightweight; high VRAM usage was caused by duplicate full-screen wallpaper blurs and oversized shadow buffers.

### A. Disable Overview Wallpaper Duplication
In [~/.config/DankMaterialShell/settings.json](file:///home/void/.config/DankMaterialShell/settings.json):
```json
"blurWallpaperOnOverview": false
```
Reload DMS:
```bash
systemctl --user reload dms.service
```
*Result: Reclaims ~150–250 MB VRAM. Normal window acrylic glass remains fully intact.*

### B. Optimize Shadow Buffers in Niri
In [~/.config/niri/config.kdl](file:///home/void/.config/niri/config.kdl):
```kdl
shadow {
    softness 16      // Reduced from 30 to cut shadow texture allocations
    spread 2         // Keeps drop shadows sharp behind glass
    offset x=0 y=4
}

blur {
    passes 2         // Keeps smooth frosted glass diffusion
    offset 4.0
    noise 0.03       // Frosted glass grain
    saturation 1.15  // Vivid glass color pass
}

window-rule {
    opacity 0.70
    background-effect {
        blur true
        xray true    // Blurs backdrop only; avoids costly recursive multi-window blurs
    }
}
```

---

## 3. Background Daemon Pruning (RAM Reclaim)

Keeps **Dolphin**, **KDE Connect**, and **KDE Partition Manager** working while eliminating unneeded Plasma and GNOME daemons.

### A. Disable Unused KDE Activity Daemon
```bash
systemctl --user stop plasma-kactivitymanagerd.service
systemctl --user mask plasma-kactivitymanagerd.service
```

### B. Prune Unused `kded6` Modules
```bash
kwriteconfig6 --file kded6rc --group Module-baloosearchmodule --key autoload false
kwriteconfig6 --file kded6rc --group Module-wpad_detector --key autoload false
kwriteconfig6 --file kded6rc --group Module-donationmessage --key autoload false
kwriteconfig6 --file kded6rc --group Module-plasma_session_shortcuts --key autoload false
```

### C. Mask Duplicate GNOME Filesystem Indexer & Monitors
GNOME Tracker and GVFS run concurrently with KDE KIO / UDisks2:
```bash
# Disable GNOME file indexer
systemctl --user stop localsearch-3.service
systemctl --user mask localsearch-3.service

# Disable GVFS daemon monitors
systemctl --user stop gvfs-daemon.service gvfs-metadata.service gvfs-udisks2-volume-monitor.service
systemctl --user mask gvfs-daemon.service gvfs-metadata.service gvfs-udisks2-volume-monitor.service
```

### D. Disable Unneeded Samba File Server (Optional)
If this machine does not host local network shares:
```bash
sudo systemctl stop smb.service
sudo systemctl disable smb.service
```

---

## 4. Dual-Tier Swap for ComfyUI & Flux Models

### Why Both ZRAM and NVMe Swap Are Needed
- **Flux.1 + T5-xxl GGUF weights** need ~18–23 GB host RAM during pipeline initialization.
- **ZRAM alone fails:** Quantized weights have high entropy and compress poorly (~1.1:1). Pushing 10+ GB of model weights into ZRAM depletes physical RAM and triggers the OOM killer.
- **Btrfs requirement:** `fallocate` fails on Btrfs due to Copy-on-Write (CoW) and compression. Placing a swapfile in `/` breaks Snapper snapshots (`ETXTBSY`).

### Implementation Steps

```bash
# 1. Remove invalid fallocate swapfile if present
sudo rm -f /swapfile

# 2. Create isolated Btrfs subvolume (nested subvolume excluded from Snapper root snapshots)
sudo btrfs subvolume create /swap

# 3. Create NoCoW, uncompressed, contiguous Btrfs swapfile
sudo btrfs filesystem mkswapfile --size 24g /swap/swapfile

# 4. Activate swapfile with lower priority than ZRAM
sudo swapon /swap/swapfile -p 10

# 5. Persist across reboots
echo '/swap/swapfile none swap defaults,pri=10 0 0' | sudo tee -a /etc/fstab
```

---

## 5. Verification Commands

Check active swap priority:
```bash
swapon --show
```
Expected output:
```
NAME           TYPE       SIZE   USED PRIO
/dev/zram0     partition 15.5G     0B  100
/swap/swapfile file        24G     0B   10
```
- Fast memory pages hit **ZRAM** first (priority 100).
- Large ComfyUI model buffers spill over into the **NVMe swapfile** (priority 10).

Check memory status:
```bash
free -h
```
