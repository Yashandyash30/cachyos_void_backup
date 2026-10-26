# Pure Shortcut-Only Dual Boot Switching: CachyOS & Windows

This guide documents the direct UEFI priority toggle between **CachyOS** and **Windows**, without any intermediate boot menus (rEFInd / GRUB).

---

## 1. How It Works

- **No Bootloader Menus:** No rEFInd, no timeouts, no black screens.
- **Persistent BIOS Priority:**
  - When in CachyOS $\rightarrow$ CachyOS is `#1` in motherboard BIOS. It boots straight to CachyOS forever on every boot/shutdown/restart.
  - When in Windows $\rightarrow$ Windows is `#1` in motherboard BIOS. It boots straight to Windows forever on every boot/shutdown/restart/Windows update.
- **Switching OS:**
  - **In CachyOS:** Click **Switch to Windows** (or type `to-win`). Sets Windows as `#1` priority in UEFI and reboots.
  - **In Windows:** Double-click **Switch to CachyOS** (or run `to-cachy`). Sets CachyOS as `#1` priority in UEFI and reboots.

---

## 2. CachyOS Setup & Usage

### A. One-Time Setup (Removes rEFInd & Installs Switcher):
Run this command in terminal:
```bash
sudo /home/void/remove-refind-and-fix.sh
```

*(What it does)*:
1. Deletes `rEFInd` entry (`0003`) from UEFI NVRAM.
2. Sets `BootOrder` to `0001,0000` (CachyOS #1, Windows #2).
3. Deletes `/boot/EFI/refind` folder and removes `refind` package.
4. Installs `/usr/local/bin/switch-to-windows` (`efibootmgr -o 0000,0001 && systemctl reboot`).
5. Adds `/etc/sudoers.d/99-switch-to-windows` for passwordless execution.

### B. Usage in CachyOS:
- **Desktop:** Double-click **Switch to Windows** (`~/Desktop/switch-to-windows.desktop`).
- **Fish Terminal:** Run:
  ```fish
  to-win
  ```
Reboots straight into Windows with zero menus.

---

## 3. Windows Setup & Usage

*(Already updated directly on your Windows partition).*

### A. Desktop / Start Menu Shortcut (`SwitchToCachyOS.bat`):
Located at `C:\Scripts\SwitchToCachyOS.bat`:
```bat
@echo off
net session >nul 2>&1
if %errorLevel% neq 0 (
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo Setting CachyOS as top UEFI priority...
powershell -NoProfile -Command "$lines = bcdedit /enum firmware; $id = ''; foreach ($l in $lines) { if ($l -match 'identifier\s+(\{[a-f0-9-]+\})') { $curr = $Matches[1] } if ($l -match 'description\s+UEFI OS') { $id = $curr; break } }; if ($id) { bcdedit /set '{fwbootmgr}' displayorder $id '{bootmgr}' }"

echo Rebooting into CachyOS...
shutdown /r /t 0
```

### B. PowerShell Function (`to-cachy`):
In PowerShell profile (`$PROFILE`):
```powershell
function to-cachy {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Error "Please run PowerShell as Administrator to use to-cachy."
        return
    }

    $lines = bcdedit /enum firmware
    $id = ""
    foreach ($l in $lines) {
        if ($l -match 'identifier\s+(\{[a-f0-9-]+\})') { $curr = $Matches[1] }
        if ($l -match 'description\s+UEFI OS') { $id = $curr; break }
    }

    if ($id) {
        Write-Host "Setting CachyOS as primary bootloader..." -ForegroundColor Green
        bcdedit /set "{fwbootmgr}" displayorder $id "{bootmgr}"
        shutdown /r /t 0
    } else {
        Write-Error "CachyOS (UEFI OS) entry not found in BCD."
    }
}
```

### C. Usage in Windows:
- Double-click **Switch to CachyOS** on Desktop or Start Menu.
- Or run `to-cachy` in Admin PowerShell.
Reboots straight into CachyOS with zero menus.

---

## 4. Summary Table

| Action | Command Executed | Result |
|---|---|---|
| **CachyOS $\rightarrow$ Windows** | `efibootmgr -o 0000,0001` | Windows becomes `#1` in BIOS. Reboots to Windows. Future boots stay in Windows. |
| **Windows $\rightarrow$ CachyOS** | `bcdedit /set {fwbootmgr} displayorder <CachyOS_ID> {bootmgr}` | CachyOS becomes `#1` in BIOS. Reboots to CachyOS. Future boots stay in CachyOS. |
