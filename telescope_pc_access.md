# Telescope PC (CCDPC) Remote Access & File Transfer Guide

This document records the network configuration, credentials, and connection methods for the Windows 7 Telescope & Andor CCD acquisition workstation (`172.20.2.42`).

---

## 1. Host Information

| Parameter | Value |
| :--- | :--- |
| **IP Address** | `172.20.2.42` |
| **NetBIOS / Computer Name** | `CCDPC` |
| **Workgroup** | `WORKGROUP` |
| **Operating System** | Windows 7 |
| **Role** | Telescope Control & Andor CCD Camera Acquisition (`Andor Solis`) |

---

## 2. VNC Remote Desktop Access (KRDC)

The system runs an RFB 3.8 VNC server on port `5900`. Use this when visual inspection of the desktop or telescope software is required.

* **Connection URL:** `vnc://172.20.2.42:5900`
* **VNC Password:** `password`
* **Recommended Client:** `krdc` (KDE Remote Desktop Client)

### Launch from Linux Terminal:
```bash
krdc vnc://172.20.2.42:5900
```

> [!NOTE]
> * In the KRDC connection dialog, select **High Quality (LAN, direct connection)** for sharp text and responsive display.
> * VNC mirrors the physical screen. Moving the mouse cursor inside VNC is visible to operators looking at the physical monitor or other remote viewers.

---

## 3. Seamless Background File Transfer (SMB / Dolphin)

Windows File Sharing (SMB on port `445`) allows pulling and pushing data files (such as FITS images) completely in the background without moving the cursor, launching pop-ups, or interrupting running observation/acquisition software.

### Connection Parameters:
* **Protocol / Share Path:** `smb://172.20.2.42/TelescopeData`
* **Target Windows Directory:** `C:\2026B`
* **Username:** `transfer`
* **Password:** *(the password set during setup, e.g. `123456`)*
* **Workgroup / Domain:** `WORKGROUP` *(or leave blank)*

### Access via Dolphin (GUI):

> [!IMPORTANT]
> **Avoid "Timeout on server 172.20.2.42":**
> Under Wayland compositors (such as Niri), KWallet/Secret Service prompts may fail or lose focus (`org.freedesktop.Secret.Collection not found`). If credentials are not sent immediately, Windows 7 drops the unauthenticated cross-subnet connection, resulting in a **"Timeout on server 172.20.2.42"** error. Always pass credentials inline or pin to Places.

1. In Dolphin, press `Ctrl + L` and enter the full URL with inline credentials:
   ```
   smb://transfer:123456@172.20.2.42/TelescopeData
   ```
2. **Pin permanently to Sidebar:** Once opened, right-click the folder background or address breadcrumb and select **"Add to Places"** (or add directly to `~/.local/share/user-places.xbel`) so it stays under **Places / Remote** without re-typing.

### Access via Linux Terminal / CLI:
```bash
# Interactive SMB prompt
smbclient //172.20.2.42/TelescopeData -U transfer%123456

# Or mount directly to your Linux filesystem:
sudo mkdir -p /mnt/telescope_data
sudo mount -t cifs //172.20.2.42/TelescopeData /mnt/telescope_data -o username=transfer,password=123456,uid=1000,gid=1000,vers=2.1
```

#### Permanent `/etc/fstab` Mount Entry (Optional):
```fstab
//172.20.2.42/TelescopeData  /mnt/telescope_data  cifs  username=transfer,password=123456,uid=1000,gid=1000,vers=2.1,noauto,users,nofail,_netdev  0  0
```

---

## 4. Windows Host-Side Setup & Maintenance Reference

If the Windows machine is ever reinstalled or the share needs to be re-created, run these commands in an **Administrator PowerShell / Command Prompt** on the Windows 7 PC:

```cmd
:: 1. Create the dedicated transfer user
net user transfer 123456 /add

:: 2. Ensure Windows uses classic authentication instead of Guest mapping
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v ForceGuest /t REG_DWORD /d 0 /f

:: 3. Grant NTFS file system read/execute permissions
icacls "C:\2026B" /grant "transfer:(OI)(CI)RX" /T

:: 4. Create the SMB network share
cmd /c "net share TelescopeData=C:\2026B /grant:transfer,FULL"

:: (Optional) Delete share if no longer needed:
:: net share TelescopeData /delete
```

---

## 5. Port Reference & Diagnostics

| Port | Service | Status | Notes |
| :--- | :--- | :--- | :--- |
| **22** | SSH | Closed (`Connection refused`) | Windows 7 lacks native OpenSSH capability |
| **135, 445** | RPC / SMB | **Open** | Used for Windows File Sharing (`TelescopeData`) |
| **3389** | RDP | **Open** | Single-session limit; connecting will disconnect active sessions |
| **5900** | VNC (RFB 3.8) | **Open** | Shared desktop view via `krdc` (`vnc://172.20.2.42:5900`) |
| **5985** | WinRM (HTTP) | Configured | Native Windows Remote Management |
