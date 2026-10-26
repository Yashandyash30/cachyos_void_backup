# Voidphone Master Guide: Remote Management & Containerized Command Center

This comprehensive guide merges your remote management tools, Wake-on-LAN (WoL) capabilities, and an always-on containerized Uptime Kuma dashboard into a single, cohesive workflow for your Android phone (**`voidphone`** — Redmi Note 10 Lite running LineageOS, rooted via Magisk), CachyOS PC, and CachyOS Laptop.

> [!IMPORTANT]
> This phone is managed **headlessly** over SSH via Tailscale. Many commands in this guide are designed to be run remotely from your PC or Laptop. Sections that must be run locally on the phone are clearly marked.

---

## Phase 1: Android Phone (`voidphone`) Foundation

### 1. Install Termux & Core Tools

Download and install **Termux** (from F-Droid). Open Termux and install the essential packages, including `proot-distro` for your isolated Linux environment:

```bash
pkg update && pkg upgrade -y
pkg install openssh wol fish sudo arp-scan proot-distro termux-api -y
```

*(Note: To use API features like checking your battery, you must also install the **Termux:API** app from F-Droid).*

Set a password for your SSH access:

```bash
passwd
```

### 2. Set Fish as Your Default Shell

Tell Termux to always open in Fish instead of Bash:

```bash
chsh -s fish
```

Now, type `fish` and press Enter to switch to it for the next steps.

### 3. Configure Prompt & Network Scanner

Run these commands inside your new Fish shell to set up your custom prompt and background services.

**Set the custom `voidphone` prompt:**

```fish
function fish_prompt
    set_color green; echo -n "voidphone"
    set_color normal; echo -n ":"
    set_color blue; echo -n (prompt_pwd)
    set_color normal; echo -n '$ '
end
funcsave fish_prompt
```

**Add your `scanlan` alias for network discovery:**

```fish
function scanlan
    sudo arp-scan -I wlan0 --localnet
end
funcsave scanlan
```

**Auto-start SSH on manual Termux launch:**

```fish
mkdir -p ~/.config/fish
echo 'if not pgrep -x sshd > /dev/null; sshd; end' >> ~/.config/fish/config.fish
source ~/.config/fish/config.fish
```

**Set up Passwordless SSH (SSH Keys):**
To avoid entering your PC or laptop password every time you connect from your phone, generate an SSH key on your phone and copy it to your devices:

```fish
# 1. Generate the key (Press Enter for all prompts to skip the passphrase)
ssh-keygen -t ed25519

# 2. Copy the key to your PC (it will ask for your PC password one last time)
ssh-copy-id void@100.117.73.75

# 3. Copy the key to your Laptop (replace with your Laptop's Tailscale IP)
ssh-copy-id void@100.70.236.70
```

**Add your cross-platform SSH & Wake-on-LAN aliases:**

```fish
function sshpc
    # Ping the PC's Tailscale IP once to see if it is online
    ping -c 1 -W 1 100.117.73.75 > /dev/null
  
    if test $status -ne 0
        echo "PC is offline. Sending Wake-on-LAN locally..."
        wol f0:4e:a4:37:91:66
        echo "Waiting 30 seconds for PC to boot and connect to Tailscale..."
        sleep 30
    end
  
    echo "Connecting to PC..."
    ssh void@100.117.73.75
end
funcsave sshpc

function sshlaptop
    echo "Connecting to Laptop..."
    ssh void@100.70.236.70
end
funcsave sshlaptop
```

---

## Phase 2: Create the Containerized Dashboard

We will use `proot-distro` to create an isolated, standard Ubuntu server environment to run Node.js without Termux compiler limits.

### 1. Install the Ubuntu Container

In your Termux Fish shell:

```fish
proot-distro install ubuntu
proot-distro login ubuntu
```

*(Your prompt will change—you are now operating inside the Ubuntu environment).*

### 2. Install Uptime Kuma

Run these commands while logged into the Ubuntu container to install Node.js 20 and setup the dashboard:

```bash
apt update && apt install curl git ca-certificates -y
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install nodejs -y

git clone https://github.com/louislam/uptime-kuma.git
cd uptime-kuma
npm run setup
```

Once finished, exit the container to return to Termux:

```bash
exit
```

---

## Phase 3: The Unified Auto-Boot Script (Magisk + ADB Fallback)

Since you are rooted, the most robust way to start your services is via a Magisk boot script. This ensures Uptime Kuma, SSH, and Wireless ADB all run as independent background processes at the system level. **Even if you accidentally swipe Termux away, your services will never be killed.**

*(Note: You do not need the Termux:Boot app for this. You can uninstall it).*

### 1. Create the Magisk Script

Open Termux (make sure you are at the native Termux `~ $` prompt, not inside Ubuntu) and run this:

```fish
echo '#!/system/bin/sh
until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 2; done

# Load Termux environment and start services as your Termux user
su u0_a183 -c "source /data/data/com.termux/files/usr/etc/profile && sshd"
su u0_a183 -c "source /data/data/com.termux/files/usr/etc/profile && nohup proot-distro login ubuntu -- bash -c \"cd ~/uptime-kuma && node server/server.js --port=3001\" > /data/data/com.termux/files/home/uptime-kuma-server.log 2>&1 &"

# Enable Wireless ADB on port 5555 as an ultimate fallback
# This allows recovery via "adb connect" even if Termux/SSH is completely dead
setprop service.adb.tcp.port 5555
stop adbd
start adbd' > ~/termux_services.sh
```

> [!NOTE]
> The Wireless ADB block at the end is your **safety net**. Because Magisk runs this script at the system level (before any Android app launches), ADB will *always* be listening on port `5555` after every boot, regardless of what happens to Termux. See [Recovery &amp; Troubleshooting](#recovery--troubleshooting) for how to use it.

### 2. Install to Magisk & Enable

```fish
sudo mv ~/termux_services.sh /data/adb/service.d/
sudo chmod +x /data/adb/service.d/termux_services.sh
```

*(If Magisk asks for root permission, click Grant).*

Your phone will now silently boot all services directly from Android's init system every time you restart!

---

## Phase 4: Network & Android Configuration

### 1. Install and Configure Tailscale

* Install **Tailscale** from the Play Store or F-Droid and log in.
* Go to the [Tailscale Admin Console](https://login.tailscale.com/admin/machines) in a browser, rename your phone to **`voidphone`**. *(Note its Tailscale IP, e.g., `100.103.187.97`).*
* In Android **Settings** > **Network & Internet** > **VPN**, tap the gear icon next to Tailscale and enable **Always-on VPN**.

### 2. Enable USB Debugging & Wireless ADB

In Android **Developer Options**:

* Turn on **USB Debugging** so your computers can interface with it over a physical USB cable.
* The Magisk boot script (Phase 3) automatically enables **Wireless ADB on port 5555** at every boot, so you do not need to manually configure this.

---

## Phase 5: Uptime Kuma First-Time Setup

Grab your laptop or PC, ensure Tailscale is connected, and open your web browser to **`http://100.103.187.97:3001`** *(replace with your phone's Tailscale IP if different)*.

**1. Initial Configuration:**

* **Database:** Select **SQLite** (Ultra-lightweight and perfect for mobile containers).
* Create your admin username and password.

**2. Add Your Core Network Monitors (Ping):**
Click **+ Add New Monitor** and change the **Monitor Type** to **Ping**:

* **Target 1:** CachyOS PC (Hostname: `100.117.73.75`, Heartbeat: 60)
* **Target 2:** CachyOS Laptop (Hostname: *Your laptop's Tailscale IP*, Heartbeat: 60)
* **Target 3:** Institute Wi-Fi Gateway (Hostname: `172.21.3.254`, Heartbeat: 60)

**3. Add Your SSH Service Monitors (TCP Port):**
To ensure your SSH services are actively listening and haven't crashed, monitor their specific TCP ports.
Click **+ Add New Monitor** and change the **Monitor Type** to **TCP Port**:

* **Target 1: CachyOS PC SSH**
  * Friendly Name: CachyOS PC - SSH
  * Hostname: `100.117.73.75`
  * Port: `22`
  * Heartbeat Interval: 60
* **Target 2: voidphone SSH**
  * Friendly Name: voidphone - SSH
  * Hostname: `100.103.187.97`
  * Port: `8022`
  * Heartbeat Interval: 60

Just hit **Save** once you enter those, and your dashboard will immediately start monitoring your actual remote access connections!

---

## Phase 6: Target Devices Setup (PC & Laptop)

### 1. CachyOS PC Setup (The Target)

**Enable Wake-on-LAN (BIOS & OS):**

* Enable **Wake on LAN** (or PCI-E Wake) in your motherboard BIOS.
* Enable WoL in the OS:

```bash
sudo pacman -S ethtool tailscale
sudo ethtool -s enp2s0 wol g
nmcli connection modify "Wired connection 1" 802-3-ethernet.wake-on-lan magic
```

**Tailscale & Dynamic Phone Alias:**

```bash
sudo systemctl enable --now tailscaled
sudo tailscale up
```

*(Optional but highly recommended)* Set up passwordless SSH by sending your PC's SSH key to the phone:

```bash
ssh-copy-id -p 8022 u0_a183@100.103.187.97
```

*(If you don't have an SSH key, run `ssh-keygen -t ed25519` first).*

Open your Fish terminal and create the `sshphone` alias :

```fish
function sshphone
    ssh u0_a183@100.103.187.97 -p 8022
end
funcsave sshphone
```

### 2. CachyOS Laptop Setup (The Commander)

Install Tailscale:

```bash
sudo pacman -S tailscale
sudo systemctl enable --now tailscaled
sudo tailscale up
```

*(Optional but highly recommended)* Set up passwordless SSH by sending your laptop's SSH key to the phone:

```bash
ssh-copy-id -p 8022 u0_a183@100.103.187.97
```

**Dynamic Phone & Remote Wake Aliases:**
Paste these into your laptop's Fish terminal:

```fish
function sshphone
    ssh u0_a183@100.103.187.97 -p 8022
end
funcsave sshphone

function wakepc
    ssh u0_a183@100.103.187.97 -p 8022 "wol f0:4e:a4:37:91:66"
end
funcsave wakepc
```

---

## Phase 7: Mounting Phone Storage to PC/Laptop (Over Tailscale)

You can seamlessly mount your phone's internal storage directly into Dolphin on your PC or Laptop using your existing Tailscale SSH connection. No Samba or KSMBD configuration is required on the phone.

### 1. Grant Storage Permissions (Run Once)

Since you manage the phone headlessly, force-grant the necessary storage permissions to Termux via root by running this from your PC:

> [!WARNING]
> **This will instantly kill your SSH connection!** When Android grants major system permissions (like Storage or Camera) to a running app, it forcefully kills the app's entire process tree to apply the new UID group rules. If your SSH connection dies immediately after running this command, **do not panic**. Use the [ADB Fallback](#method-1-adb-fallback-no-physical-access-needed) to restart `sshd`, or simply restart the phone. See [Known Pitfalls](#known-pitfalls--android-gotchas) for a detailed explanation.

```bash
ssh -p 8022 u0_a183@100.103.187.97 "sudo appops set com.termux MANAGE_EXTERNAL_STORAGE allow; sudo pm grant com.termux android.permission.READ_EXTERNAL_STORAGE; sudo pm grant com.termux android.permission.WRITE_EXTERNAL_STORAGE"
```

### 2. Method A: The Dolphin SFTP Way (Zero-Config)

This is the fastest and most stable method. It uses Dolphin's native SFTP support.

1. Open **Dolphin**.
2. Click the address bar (`Ctrl+L`).
3. Paste the following exact address and press Enter:
   `sftp://u0_a183@100.103.187.97:8022/storage/emulated/0`
4. Right-click any empty space in Dolphin's left sidebar (under "Network" or "Places") and select **Add to Places**.
5. Right-click the new shortcut, select **Edit**, and rename it to **Voidphone Storage**.

### 3. Method B: The `/etc/fstab` Way (System-Level Mount)

If you prefer the drive to be mounted at `/mnt/` exactly like your KSMBD network drives (dormant on boot, mounts on click):

1. Install SSHFS on your CachyOS PC:
   ```bash
   sudo pacman -S sshfs
   ```
2. Create the mount point:
   ```bash
   sudo mkdir -p /mnt/Voidphone
   sudo chown void:void /mnt/Voidphone
   ```
3. Add this line to `/etc/fstab` (it uses the same `noauto,nofail,users,_netdev` flags as your other network drives so it only mounts when clicked in Dolphin):
   ```text
   u0_a183@100.103.187.97:/storage/emulated/0  /mnt/Voidphone  fuse.sshfs  port=8022,IdentityFile=/home/void/.ssh/id_ed25519,users,noauto,nofail,_netdev  0  0
   ```
4. Reload system daemons to activate the new entry:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl restart local-fs.target
   ```

---

## Phase 8: Remote Camera Capture & Automation

You can silently trigger your phone's front camera remotely and instantly download the image to your current folder on your PC or Laptop.

### 1. Grant Camera Permissions (Run Once)

Since you manage the phone headlessly, force-grant the camera permissions to Termux via root by running this from your PC:

> [!WARNING]
> Just like the storage permission, **running this command will instantly kill your SSH connection** as Android forcefully restarts Termux to apply the camera permissions. Use the [ADB Fallback](#method-1-adb-fallback-no-physical-access-needed) to restart `sshd`, or simply restart the phone.

```bash
ssh -p 8022 u0_a183@100.103.187.97 "sudo pm grant com.termux.api android.permission.CAMERA; sudo pm grant com.termux android.permission.CAMERA"
```

### 2. Add the Fish Alias (For PC & Laptop)

Paste this into your Fish terminal on your PC or Laptop. This creates a `takephonepic` command that snaps a photo and downloads it directly to whatever folder you are currently in.

> [!IMPORTANT]
> **Why does this wake up the screen?** Starting with Android 11, apps that access the camera while the screen is completely off are treated as a privacy violation. Android will forcefully kill the entire app (Termux + SSH) to stop it. By using root to briefly wake the screen via `input keyevent 224` (KEYCODE_WAKEUP), Termux is temporarily treated as a "foreground-visible" context, bypassing the restriction. The screen is immediately put back to sleep via `input keyevent 223` (KEYCODE_SLEEP) after the capture.

```fish
function phonepic
    echo "📸 Snapping photo from voidphone front camera..."
  
    # Wake the screen up (even if locked) to bypass background camera restrictions
    ssh -p 8022 u0_a183@100.103.187.97 "sudo input keyevent 224; sleep 1"
  
    # Take the photo and save it temporarily on the phone
    ssh -p 8022 u0_a183@100.103.187.97 "termux-camera-photo -c 1 ~/latest_pic.jpg"
    set photo_status $status
  
    # Immediately put the screen back to sleep
    ssh -p 8022 u0_a183@100.103.187.97 "sudo input keyevent 223"
  
    if test $photo_status -eq 0
        # Generate a timestamped filename
        set filename "voidphone_pic_"(date +%Y%m%d_%H%M%S)".jpg"
      
        echo "📥 Downloading to $PWD/$filename..."
        scp -q -P 8022 u0_a183@100.103.187.97:~/latest_pic.jpg ./$filename
      
        echo "✅ Done!"
    else
        echo "❌ Failed to take photo. Make sure permissions are granted."
    end
end
funcsave phonepic
```

**Usage:** Open your terminal, navigate to any folder where you want to save the picture, and simply type `takephonepic`.

---

## Daily Maintenance & Workflow

* **Network Scanning:** Type `scanlan` on the phone to map connected devices.
* **Phone Management:** From anywhere via Tailscale, type `sshphone`.
* **Remote Management from Phone:** Type `sshpc` on the phone to wake and connect to the PC, or `sshlaptop` to connect to the Laptop.
* **Remote PC Wakeup (from Laptop):** From the laptop, type `wakepc`. Wait 15–30s for the PC to boot and connect to Tailscale, then SSH into it via `100.117.73.75` (or just use `sshpc`).
* **Dashboard Logs:** To view live Uptime Kuma logs, run `cat ~/uptime-kuma-server.log` on the phone.
* **Verify Container:** Run `pgrep -a proot` on the phone to ensure the container is active.

---

## Recovery & Troubleshooting

You have **two layers of remote recovery** available, so you should never need physical access to the phone again.

### Accidentally Closed Termux?

Because you are using the Magisk Boot Script (Phase 3), **you do not need to worry about this!** Android's app-killer cannot touch processes started by Magisk. You can freely swipe Termux away from your recent apps, and SSH + Uptime Kuma will remain 100% online.

If for some reason you ever need to manually restart the services without rebooting your phone, you can run:

```bash
sudo /data/adb/service.d/termux_services.sh
```

### SSH is dead (`Connection refused` on port 8022)?

This means the Termux process was killed by Android (usually due to granting permissions or background camera access — see [Known Pitfalls](#known-pitfalls--android-gotchas)). Use one of these recovery methods:

#### Method 1: ADB Fallback (No physical access needed)

The Magisk boot script enables Wireless ADB on port `5555` at every boot. Because this runs at the system level, it survives even when Android kills Termux. From your PC or Laptop:

1. **Install ADB** (if not already installed):

   ```bash
   sudo pacman -S android-tools
   ```
2. **Connect to the phone via ADB over Tailscale:**

   ```bash
   adb connect 100.103.187.97:5555
   ```
3. **Force Termux's SSH server to restart:**

   ```bash
   adb shell su -c 'su u0_a183 -c "source /data/data/com.termux/files/usr/etc/profile && sshd"'
   ```
4. **Verify SSH is back:**

   ```bash
   nc -zvw1 100.103.187.97 8022
   ```

   You should see `Connection succeeded!`. Now `sshphone` will work again.
5. **Disconnect ADB when done:**

   ```bash
   adb disconnect 100.103.187.97:5555
   ```

#### Method 2: Full Reboot (If ADB also fails)

If both SSH and ADB are unresponsive (e.g. the phone completely froze or Tailscale disconnected due to deep sleep), you will need physical access to restart the phone. Once it reboots, the Magisk boot script will automatically bring everything back online.

> [!TIP]
> To prevent Tailscale from disconnecting during deep sleep, make sure **Always-on VPN** is enabled for Tailscale in Android Settings > Network & Internet > VPN. Also exempt both Termux and Tailscale from battery optimization in Settings > Apps > Battery.

---

## Known Pitfalls & Android Gotchas

These are real-world issues that have caused SSH lockouts in the past. Understanding them will save you time.

### 1. Granting Permissions Kills SSH

**What happens:** When you run `pm grant` or `appops set` to give Termux a major permission (Storage, Camera, etc.), Android's `ActivityManager` forcefully kills the entire Termux process tree to apply the new UID group rules. Since `sshd` runs under Termux, your SSH connection instantly dies.

**When it happens:** Only when granting permissions for the first time (the "Run Once" steps in Phases 7 and 8). Once permissions are granted, they persist across reboots.

**How to recover:** Use the [ADB Fallback](#method-1-adb-fallback-no-physical-access-needed) to restart `sshd`.

**How to avoid:** If you need to grant multiple permissions, batch them into a single command so you only lose the connection once. Then recover via ADB.

### 2. Background Camera Access Kills Termux

**What happens:** Starting with Android 11, accessing the camera while the phone screen is completely off is treated as a privacy violation. Android will kill the entire app (Termux) to stop the camera access, taking your SSH server down with it.

**When it happens:** Every time you run `termux-camera-photo` (or the old `takephonepic` alias) while the phone screen is asleep.

**How to recover:** Use the [ADB Fallback](#method-1-adb-fallback-no-physical-access-needed) to restart `sshd`.

**How to avoid:** The updated `takephonepic` alias (Phase 8) now uses root to briefly wake the screen before taking the photo and immediately puts it back to sleep afterward. This tricks Android into treating Termux as a foreground app during the capture. **Always use the updated alias.**

### 3. Android Doze Mode Disconnects Tailscale

**What happens:** After extended idle time with the screen off, Android's Doze mode aggressively suspends network activity. Tailscale loses its VPN tunnel, and the phone becomes completely unreachable — even ADB over Tailscale won't work.

**When it happens:** Usually after several hours of inactivity, especially on battery.

**How to prevent:**

* Enable **Always-on VPN** for Tailscale (Settings > Network & Internet > VPN).
* Set Tailscale to **Unrestricted** battery usage (Settings > Apps > Tailscale > Battery).
* Set Termux to **Unrestricted** battery usage as well.
* Keep Termux's **wakelock** acquired (swipe down notification shade > tap "Acquire wakelock" on the Termux notification, or run `termux-wake-lock`).
