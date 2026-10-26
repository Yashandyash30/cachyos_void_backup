# Dual Boot Switching Guide: CachyOS & Windows

This guide documents the setup where:
1. **Shortcuts (`to-win` / `to-cachy`):** Jump directly into the target OS without menus.
2. **rEFInd Memory Sync:** The shortcut updates rEFInd's memory file (`PreviousBoot`), so the target OS becomes the highlighted default in rEFInd for future boots.
3. **Manual Selection in rEFInd:** When booting normally, rEFInd GUI appears with your last-used OS highlighted. If you manually select the other OS in rEFInd, rEFInd updates its memory accordingly.

---

## 1. How It Works Under the Hood

- **rEFInd Config (`use_nvram false`):**
  rEFInd is instructed to store its remembered last-booted OS on disk at `/EFI/refind/vars/PreviousBoot` instead of motherboard NVRAM.
- **When running `to-win` in CachyOS:**
  1. Writes `Windows\0` (in UTF-16LE) into `/boot/EFI/refind/vars/PreviousBoot`.
  2. Sets `efibootmgr -n 0000` (one-shot direct boot to Windows Boot Manager).
  3. Reboots straight into Windows (no menus).
  4. On subsequent cold boots, rEFInd loads with Windows pre-selected.
- **When running `to-cachy` in Windows:**
  1. Mounts EFI partition (`mountvol S: /s`).
  2. Writes `vmlinuz\0` (in UTF-16LE) into `S:\EFI\refind\vars\PreviousBoot`.
  3. Reboots into CachyOS.
  4. On subsequent cold boots, rEFInd loads with CachyOS pre-selected.

---

## 2. One-Time rEFInd Configuration (Run in CachyOS)

Run this command once in CachyOS terminal:

```bash
sudo bash -c '
CONF=$(find /boot -name refind.conf 2>/dev/null | head -n 1)

# 1. Enable disk-based memory so shortcuts can sync with rEFInd
grep -q "^use_nvram" "$CONF" && sed -i "s/^use_nvram.*/use_nvram false/" "$CONF" || echo "use_nvram false" >> "$CONF"

# 2. Remember last selection (defaults to last-used OS across cold boots)
grep -q "^default_selection" "$CONF" && sed -i "s/^default_selection.*/default_selection \"+\"/" "$CONF" || echo "default_selection \"+\"" >> "$CONF"

# 3. 5-second countdown on normal boot
grep -q "^timeout" "$CONF" && sed -i "s/^timeout.*/timeout 5/" "$CONF" || echo "timeout 5" >> "$CONF"

# 4. Hide redundant fallback bootx64.efi so rEFInd only displays 2 entries (CachyOS + Windows)
grep -q "^dont_scan_files" "$CONF" && sed -i "s/^dont_scan_files.*/dont_scan_files bootx64.efi/" "$CONF" || echo "dont_scan_files bootx64.efi" >> "$CONF"

# 5. Enable textmode fallback to help passive DP-to-HDMI display adapters wake up during boot
grep -q "^textmode" "$CONF" || echo "textmode" >> "$CONF"

echo "rEFInd successfully configured: $CONF"
'
```

### What Each Setting Does:
- **`use_nvram false`**: Stores boot memory on disk (`/EFI/refind/vars/PreviousBoot`) instead of motherboard NVRAM. Required for external scripts to tell rEFInd who has priority.
- **`default_selection "+"`**: The `"+"` directs rEFInd to default to the last-launched OS.
- **`dont_scan_files bootx64.efi`**: Omits duplicate Limine fallback binary; leaves a clean 2-icon menu (CachyOS & Windows).
- **`textmode`**: Forces basic text console mode during pre-boot, preventing passive display adapters from remaining asleep.

---

## 3. CachyOS Setup & Usage

### A. One-Time Setup (Passwordless Execution)
Run the pre-generated installer script:
```bash
sudo /home/void/setup-switch.sh
```

*(For reference, `setup-switch.sh` creates `/usr/local/bin/switch-to-windows` and grants passwordless execution via `/etc/sudoers.d/99-switch-to-windows`)*:
```bash
#!/bin/bash
set -e

cat << 'EOF' > /usr/local/bin/switch-to-windows
#!/bin/bash
set -e
mkdir -p /boot/EFI/refind/vars 2>/dev/null || true
echo -en "Windows\0" | iconv -f UTF-8 -t UTF-16LE > /boot/EFI/refind/vars/PreviousBoot 2>/dev/null || true
efibootmgr -n 0000
systemctl reboot
EOF

chmod 755 /usr/local/bin/switch-to-windows
echo "%wheel ALL=(ALL) NOPASSWD: /usr/local/bin/switch-to-windows" > /etc/sudoers.d/99-switch-to-windows
chmod 440 /etc/sudoers.d/99-switch-to-windows
```

### B. Usage:
- **Desktop Shortcut:** Double-click **Switch to Windows** (`~/Desktop/switch-to-windows.desktop`).
- **Fish Terminal:** Run:
  ```fish
  to-win
  ```
Both execute instantly with no password prompt and reboot directly into Windows.

---

## 4. Windows Setup & Usage

### A. One-Time Setup: Desktop & Start Menu Shortcuts (with Icon)
Run this script once in Windows **PowerShell as Administrator**. It saves the batch file to `C:\Scripts\` and creates styled shortcuts on both your Desktop and Start Menu:

```powershell
# 1. Create permanent directory and batch script
$scriptDir = "C:\Scripts"
if (!(Test-Path $scriptDir)) { New-Item -ItemType Directory -Path $scriptDir -Force }
$batPath = "$scriptDir\SwitchToCachyOS.bat"

$batContent = @'
@echo off
net session >nul 2>&1
if %errorLevel% neq 0 (
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)
echo Mounting EFI System Partition...
mountvol S: /s
echo Updating rEFInd priority to CachyOS...
powershell -NoProfile -Command "[System.IO.File]::WriteAllBytes('S:\EFI\refind\vars\PreviousBoot', [System.Text.Encoding]::Unicode.GetBytes('vmlinuz' + [char]0))"
mountvol S: /d

echo Setting direct one-shot boot into CachyOS (bypassing rEFInd GUI)...
powershell -NoProfile -Command "$lines = bcdedit /enum firmware; $id = ''; foreach ($l in $lines) { if ($l -match 'identifier\s+(\{[a-f0-9-]+\})') { $curr = $Matches[1] } if ($l -match 'description\s+UEFI OS') { $id = $curr; break } }; if ($id) { bcdedit /set '{fwbootmgr}' bootsequence $id }"

echo Rebooting into CachyOS...
shutdown /r /t 0
'@

Set-Content -Path $batPath -Value $batContent -Encoding ASCII

# 2. Create shortcuts with restart icon on Desktop and Start Menu
$wsh = New-Object -ComObject WScript.Shell
$shortcutPaths = @(
    [System.IO.Path]::Combine([Environment]::GetFolderPath('Desktop'), "Switch to CachyOS.lnk"),
    [System.IO.Path]::Combine([Environment]::GetFolderPath('StartMenu'), "Programs", "Switch to CachyOS.lnk")
)

foreach ($linkPath in $shortcutPaths) {
    $shortcut = $wsh.CreateShortcut($linkPath)
    $shortcut.TargetPath = $batPath
    $shortcut.WorkingDirectory = $scriptDir
    $shortcut.Description = "Reboot directly into CachyOS"
    # Restart/power icon from shell32.dll
    $shortcut.IconLocation = "$env:SystemRoot\System32\shell32.dll, 238"
    $shortcut.Save()
}

Write-Host "Done! Shortcuts created on Desktop and Start Menu." -ForegroundColor Green
```

### B. PowerShell Function (`to-cachy`)
Open your PowerShell profile in Admin PowerShell:
```powershell
notepad $PROFILE
```
Paste this function (includes admin privilege check and robust `try/finally` cleanup so `S:` is never left mounted):

```powershell
function to-cachy {
    # Check if running as Admin
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Error "Please run PowerShell as Administrator to use to-cachy."
        return
    }

    try {
        mountvol S: /s
        [System.IO.File]::WriteAllBytes("S:\EFI\refind\vars\PreviousBoot", [System.Text.Encoding]::Unicode.GetBytes('vmlinuz' + [char]0))
    }
    finally {
        # Ensures S: is always unmounted even if writing fails
        mountvol S: /d
    }

    # Direct one-shot boot to CachyOS (bypasses rEFInd GUI)
    $lines = bcdedit /enum firmware
    $id = ""
    foreach ($l in $lines) {
        if ($l -match 'identifier\s+(\{[a-f0-9-]+\})') { $curr = $Matches[1] }
        if ($l -match 'description\s+UEFI OS') { $id = $curr; break }
    }
    if ($id) {
        bcdedit /set "{fwbootmgr}" bootsequence $id
    }

    shutdown /r /t 0
}
```

### C. Usage:
- **GUI:** Double-click **Switch to CachyOS** on Desktop or Start Menu (auto-elevates to Admin, updates rEFInd, reboots).
- **PowerShell:** Run `to-cachy` in any Administrator PowerShell window.

---

## 5. Troubleshooting & Recovery

### A. Black Screen During Boot (Dual Monitors & DP-to-HDMI Adapters)
If your primary monitor stays black during BIOS and rEFInd:
- **Root Cause:** AMD GPU firmware (UEFI GOP) sends pre-boot video to the native **`HDMI-A-1` port (MSI MAG 255F monitor)** by default. Passive DP-to-HDMI adapters (HP monitor) stay asleep because they require OS graphics drivers to initialize TMDS signaling over DisplayPort.
- **Hardware Fix (Recommended):** 
  - Plug the **HP monitor into native HDMI**.
  - Plug the **MSI MAG monitor into native DisplayPort** (using a standard DisplayPort cable).
  - This guarantees BIOS/rEFInd displays on the HP monitor, and unlocks full high-refresh-rate bandwidth on the MSI gaming monitor.
- **Software Fix:** Enabling `textmode` in `refind.conf` (included in step 2) forces standard video initialization, helping adapters negotiate resolution.

### B. Boot Priority Recovery
- **If Windows Update overwrites the boot order (boots straight to Windows):**
  1. Boot CachyOS via motherboard boot menu key (`F11`/`F12`).
  2. Restore rEFInd to `#1`:
     ```bash
     sudo efibootmgr -o 0003,0001,0000,0002
     ```
     *(or run `sudo refind-install`)*

- **Related Guides:**
  - Headless SSH & Windows Autologon: [WINDOWS_SSH_AND_AUTOLOGON_GUIDE.md](file:///home/void/cachyos_void_backup/WINDOWS_SSH_AND_AUTOLOGON_GUIDE.md)
