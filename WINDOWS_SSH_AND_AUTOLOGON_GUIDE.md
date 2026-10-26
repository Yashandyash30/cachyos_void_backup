# Windows Headless Access Guide: OpenSSH on Boot & Autologon with Lock Screen

This guide configures Windows to:
1. **Start OpenSSH Server on boot** (SSH works immediately before anyone touches the PC).
2. **Authenticate with CachyOS SSH keys** (no password prompt).
3. **Auto-login to your user account on boot** (starts background game launchers, Steam, anti-cheat services).
4. **Immediately lock the workstation screen** (physical monitor stays secure at the lock screen).

---

## Part 1: OpenSSH Server on Boot (No Login Needed)

Windows OpenSSH Server runs as a `SYSTEM` service. It starts on cold boot, regardless of whether a user is logged in.

### 1. Install & Enable Service
Open **PowerShell as Administrator** in Windows and run:

```powershell
# 1. Install OpenSSH Server capability
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0

# 2. Set service to start automatically on system boot
Set-Service -Name sshd -StartupType Automatic
Start-Service sshd

# 3. Create Windows Defender Firewall rule for port 22
New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
```

---

### 2. Configure SSH Public Key Authentication (From CachyOS)

#### Step A: Get your CachyOS Public Key
In your CachyOS terminal, display your public key:
```bash
cat ~/.ssh/id_ed25519.pub
# If you use RSA instead:
# cat ~/.ssh/id_rsa.pub
```
Copy the entire output string (e.g. `ssh-ed25519 AAAAC3... void@cachyos`).

#### Step B: Install Key on Windows
In Windows **Admin PowerShell**, run the following (replace the placeholder with your copied key):

```powershell
$PubKey = "PASTE_YOUR_COPIED_CACHYOS_KEY_HERE"

# For Administrator accounts (default for gaming rigs):
$AdminKeyPath = "$env:ProgramData\ssh\administrators_authorized_keys"
Set-Content -Path $AdminKeyPath -Value $PubKey -Encoding ASCII

# CRITICAL: Windows OpenSSH will ignore this file unless permissions are strictly locked
icacls.exe $AdminKeyPath /inheritance:r /grant "Administrators:F" /grant "SYSTEM:F"

# Restart sshd service to apply
Restart-Service sshd
```

> [!IMPORTANT]
> In Windows OpenSSH, accounts in the Administrators group read `$env:ProgramData\ssh\administrators_authorized_keys`, **not** `~/.ssh/authorized_keys`. The `icacls` command is required to remove inherited permissions, or SSH key auth will be rejected.

---

### 3. Set PowerShell as Default SSH Shell (Optional but Recommended)
By default, Windows SSH opens `cmd.exe`. To get PowerShell when you SSH:

```powershell
New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -PropertyType String -Force
```

---

## Part 2: Auto-Login with Immediate Screen Lock

Auto-login ensures that your Windows user profile loads on startup (so anti-cheat daemons, Discord, game updates, and startup tasks initialize). An automated task then immediately locks the screen.

### Method: Official Microsoft Sysinternals Autologon + Lock Task

#### Step 1: Set Up Autologon
1. Download official Microsoft tool: [Sysinternals Autologon](https://learn.microsoft.com/en-us/sysinternals/downloads/autologon).
2. Extract and run `Autologon.exe` as Administrator.
3. Enter your Windows username and password, then click **Enable**.
   *(Credentials are securely encrypted into the Windows Local Security Authority (LSA) secrets).*

#### Step 2: Create Immediate Lock Screen Task
In Windows **Admin PowerShell**, run:

```powershell
# Create a scheduled task that locks the workstation immediately when your user logs in
$Action = New-ScheduledTaskAction -Execute 'rundll32.exe' -Argument 'user32.dll,LockWorkStation'
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

Register-ScheduledTask -TaskName "AutoLockOnBoot" -Action $Action -Trigger $Trigger -Settings $Settings -Description "Locks screen immediately after auto-logon"
```

### Result:
- Computer turns on $\rightarrow$ Logs into your Windows user account $\rightarrow$ Launches startup apps $\rightarrow$ Locks the physical monitor instantly.
- SSH is accessible before and after logon.

---

## Part 3: Anti-Cheat & Windows Update Taming

To keep Windows Update compatible with anti-cheats (Vanguard, BattlEye, EAC) while stopping spontaneous reboots:

Run in Windows **Admin PowerShell**:

```powershell
# Prevent Windows from rebooting automatically if a user is logged on
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoRebootWithLoggedOnUsers /t REG_DWORD /d 1 /f

# Set Windows Update to Notify Only (will not auto-download or auto-reboot)
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AUOptions /t REG_DWORD /d 2 /f
```

---

## Part 4: Seamless `sshrig` from All Devices (Tablet, Laptop, Phone)

To use the exact same `sshrig` command regardless of whether your rig is running **CachyOS** or **Windows**:

### The 3 Dual-Boot SSH Challenges Solved:
1. **Host Key Mismatch:** When OS switches on the same IP, SSH clients see a different host key and block the connection with `REMOTE HOST IDENTIFICATION HAS CHANGED`.
2. **Tailscale IP Difference:** Tailscale assigns `100.106.197.11` to CachyOS (`void-rig-cachyos`) and `100.67.86.64` to Windows (`void-rig`).
3. **Username:** All your client configs connect with `User void`.

---

### Step 1: Configure Windows (Run in Admin PowerShell)

Run this block once on Windows to authorize all your devices and match username `void`:

```powershell
# 1. Ensure user 'void' exists on Windows (if your Windows account is named differently)
if (-not (Get-LocalUser -Name "void" -ErrorAction SilentlyContinue)) {
    Write-Host "Creating local user 'void' on Windows..."
    net user void /add
    net localgroup Administrators void /add
}

# 2. Authorize all client devices (PC, Phone, Tablet)
$AdminKeyPath = "$env:ProgramData\ssh\administrators_authorized_keys"

$AllKeys = @(
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFyywS3hILOxkMSuGb3YpYZ7cBta0AfkooZoFDO+FhRo void@void-pc",
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEZnXAxtzhYF59Sz97/z2T6IpGiw5pTIZJQrV93ggDDy u0_a183@localhost",
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGYEzY9cPzQwATF19HM2Y4W3Yz7P2ncv1Qw4FxpuGRjp u0_a484@localhost"
)

Set-Content -Path $AdminKeyPath -Value $AllKeys -Encoding ASCII

# Lock down permissions (required by Windows OpenSSH)
icacls.exe $AdminKeyPath /inheritance:r /grant "Administrators:F" /grant "SYSTEM:F"

# Restart OpenSSH
Restart-Service sshd
Write-Host "Windows SSH configured for all devices." -ForegroundColor Green
```

---

### Step 2: Configure Client Devices (`~/.ssh/config`)

Update `~/.ssh/config` on your client devices (Laptop, Tablet, Phone) with this dynamic multi-failover block:

```sshconfig
# 1. Local LAN check (fastest, same IP on both CachyOS & Windows)
Match host rig,voidrig,void-rig exec "nc -z -w 1 172.21.1.185 22 2>/dev/null"
    HostName 172.21.1.185

# 2. Tailscale CachyOS check (when outside LAN)
Match host rig,voidrig,void-rig exec "nc -z -w 1 100.106.197.11 22 2>/dev/null"
    HostName 100.106.197.11

# 3. Tailscale Windows check (when outside LAN)
Match host rig,voidrig,void-rig exec "nc -z -w 1 100.67.86.64 22 2>/dev/null"
    HostName 100.67.86.64

# Base configuration for Rig
Host rig voidrig void-rig
    User void
    IdentityFile ~/.ssh/id_ed25519
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    ConnectTimeout 3
```

### Why this works seamlessly:
- **On Home Wi-Fi/LAN:** Automatically routes to `172.21.1.185` on whichever OS is currently running.
- **Outside Home (Tailscale):** Automatically pings CachyOS (`100.106.197.11`); if offline, falls back to Windows (`100.67.86.64`).
- **`StrictHostKeyChecking no` + `UserKnownHostsFile /dev/null`:** Prevents SSH host-key collisions when switching between Linux and Windows.
- **Typing `sshrig`** on any device now connects transparently to the active OS.
