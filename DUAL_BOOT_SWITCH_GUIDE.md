# Dual Boot Switching Guide: CachyOS & Windows

This guide documents the setup where:
1. **Shortcuts (`to-win` / `to-cachy`):** Jump directly into the target OS without menus.
2. **rEFInd Memory Sync:** The shortcut also updates rEFInd's memory file (`PreviousBoot`), so the target OS becomes the highlighted default in rEFInd for future boots.
3. **Manual Selection in rEFInd:** When booting normally, rEFInd GUI appears with your last-used OS highlighted. If you manually select the other OS in rEFInd, rEFInd updates its memory accordingly.

---

## 1. How It Works Under the Hood

- **rEFInd Config (`use_nvram false`):**
  rEFInd is instructed to store its remembered last-booted OS on disk at `/EFI/refind/vars/PreviousBoot` instead of motherboard NVRAM.
- **When running `to-win` in CachyOS:**
  1. Writes `Windows\0` (in UTF-16LE) into `/boot/EFI/refind/vars/PreviousBoot`.
  2. Sets `efibootmgr -n 0000` (one-shot direct boot).
  3. Reboots straight into Windows (no menus).
  4. On subsequent cold boots, rEFInd loads with Windows highlighted.
- **When running `to-cachy` in Windows:**
  1. Mounts EFI partition (`mountvol S: /s`).
  2. Writes `vmlinuz\0` (in UTF-16LE) into `S:\EFI\refind\vars\PreviousBoot`.
  3. Reboots into CachyOS.
  4. On subsequent cold boots, rEFInd loads with CachyOS highlighted.

---

## 2. One-Time rEFInd Configuration (Run in CachyOS)

Run this command once in CachyOS terminal:

```bash
sudo bash -c '
CONF=$(find /boot -name refind.conf 2>/dev/null | head -n 1)

# Enable disk-based memory so shortcuts can sync with rEFInd
grep -q "^use_nvram" "$CONF" && sed -i "s/^use_nvram.*/use_nvram false/" "$CONF" || echo "use_nvram false" >> "$CONF"

# Remember last selection
grep -q "^default_selection" "$CONF" && sed -i "s/^default_selection.*/default_selection \"+\"/" "$CONF" || echo "default_selection \"+\"" >> "$CONF"

# 5-second countdown on normal boot
grep -q "^timeout" "$CONF" && sed -i "s/^timeout.*/timeout 5/" "$CONF" || echo "timeout 5" >> "$CONF"

echo "rEFInd successfully configured: $CONF"
'
```

---

## 3. CachyOS Usage

- **Desktop Shortcut:** Double-click **Switch to Windows** (`~/Desktop/switch-to-windows.desktop`).
- **Fish Terminal:** Run:
  ```fish
  to-win
  ```
Both execute `/home/void/.local/bin/switch-to-windows`, syncing rEFInd and booting Windows immediately.

---

## 4. Windows Usage

### Desktop Shortcut (`SwitchToCachyOS.bat`)
Create a file named `SwitchToCachyOS.bat` on your Windows Desktop:

```bat
@echo off
net session >nul 2>&1
if %errorLevel% neq 0 (
    powershell -Command "Start-Process cmd -ArgumentList '/c %~fnx0' -Verb RunAs"
    exit /b
)

echo Mounting EFI System Partition...
mountvol S: /s

echo Updating rEFInd priority to CachyOS...
powershell -NoProfile -Command "[System.IO.File]::WriteAllBytes('S:\EFI\refind\vars\PreviousBoot', [System.Text.Encoding]::Unicode.GetBytes(\"vmlinuz`0\"))"

mountvol S: /d

echo Rebooting into CachyOS...
shutdown /r /t 0
```

### PowerShell Command (`to-cachy`)
Open your PowerShell profile in Admin PowerShell:
```powershell
notepad $PROFILE
```
Add:
```powershell
function to-cachy {
    mountvol S: /s
    [System.IO.File]::WriteAllBytes("S:\EFI\refind\vars\PreviousBoot", [System.Text.Encoding]::Unicode.GetBytes("vmlinuz`0"))
    mountvol S: /d
    shutdown /r /t 0
}
```
Run `to-cachy` in any Administrator PowerShell window.
