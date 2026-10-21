# Advanced Bidirectional Remote Environments (Linux Setup & Rebuild Guide)

This guide documents the complete setup for persistent remote sessions, smart path translation, IDE integration, GUI forwarding (Xpra over Wayland/Niri), and **automatic LAN / Tailscale dual-network failover** between your Laptop and Host PC (CachyOS / Arch Linux).

---

## Architecture & Capabilities

1. **Automatic Network Routing (LAN ↔ Tailscale)**:
   * **Local LAN (`172.21.0.174`)**: Used automatically whenever on the home network (sub-millisecond latency, unaffected by ISP Tailscale blocks).
   * **Tailscale (`100.117.73.75`)**: Used as an automatic fallback when away from home.
2. **Smart Path Translation**: Browsing a local network mount (e.g. `/mnt/PC_Home/Downloads`) automatically translates into the real remote path (`/home/void/Downloads`) when jumping or opening the IDE.
3. **Persistent Sessions (Zellij)**: Dropped Wi-Fi or closing the laptop lid never kills long-running tasks.
4. **Wayland-to-Wayland GUI Forwarding (Xpra)**: Bypasses pure Wayland (Niri) X11 forwarding limitations by spinning up an invisible display (`:100`) and seamlessly streaming GUI windows.
5. **Dolphin Context Menu**: Right-click any network folder in Dolphin to open it directly in Antigravity IDE on the PC via SSH.

---

## 1. Prerequisites (Install on Both Laptop and PC)

Run on both machines:

```bash
sudo pacman -S --needed fish openssh openbsd-netcat xpra zellij samba cifs-utils
```

Ensure SSH daemon is enabled and running on the PC:

```bash
sudo systemctl enable --now sshd
```

---

## 2. Dynamic SSH Configuration (`~/.ssh/config`)

Instead of hardcoding IPs into scripts, OpenSSH probes whether the local IP (`172.21.0.174`) responds on port 22 within 1 second using `openbsd-netcat` (`nc`). If it responds, OpenSSH routes traffic over LAN; otherwise, it falls back to Tailscale.

Edit or create `~/.ssh/config` on your **Laptop**:

```ssh-config
# Host PC Dynamic Failover
Match host pc,voidpc,void-pc,100.117.73.75 exec "nc -z -w 1 172.21.0.174 22 2>/dev/null"
    HostName 172.21.0.174
    User void
    IdentityFile ~/.ssh/id_ed25519

Host pc voidpc void-pc
    HostName 100.117.73.75
    User void
    IdentityFile ~/.ssh/id_ed25519
    ConnectTimeout 3
```

Set secure permissions:

```bash
chmod 600 ~/.ssh/config
```

### Verification
Test which IP OpenSSH resolves to:

```bash
# Check resolved hostname (should show 172.21.0.174 when at home)
ssh -G pc | grep -i hostname

# Test connection
ssh pc "hostname && ip -br a"
```

---

## 3. Fish Functions (Laptop Configuration)

Save each function into `~/.config/fish/functions/`:

### 3.1 Dynamic IP Resolver (`~/.config/fish/functions/_get_pc_ip.fish`)

```fish
function _get_pc_ip
    # Check if PC is reachable on local network (172.21.0.174) with a 1s timeout
    if nc -z -w 1 172.21.0.174 22 2>/dev/null
        echo "172.21.0.174"
    else
        echo "100.117.73.75"
    end
end
```

### 3.2 Path Translator (`~/.config/fish/functions/_get_pc_target_dir.fish`)

```fish
function _get_pc_target_dir
    # Helper function to dynamically translate local mount paths to PC absolute paths
    if string match -q "/mnt/PC_Home*" $PWD
        set target_dir (string replace "/mnt/PC_Home" "/home/void" $PWD)
    else if string match -q "/mnt/PC_Storage*" $PWD
        set target_dir (string replace "/mnt/PC_Storage" "/mnt/Storage" $PWD)
    else if string match -q "/home/void*" $PWD
        set target_dir (string replace "/home/void" "/mnt/Laptop_Home" $PWD)
    else
        set target_dir "/home/void"
    end

    echo $target_dir
end
```

### 3.3 Quick SSH Jump (`~/.config/fish/functions/jumppc.fish`)

```fish
function jumppc
    set target_dir (_get_pc_target_dir)
    set pc_ip (_get_pc_ip)

    if not nc -z -w 1 $pc_ip 22 2>/dev/null
        echo "PC is offline at $pc_ip. Sending Wake-on-LAN via voidphone..."
        wakepc
        echo "Waiting 30 seconds for PC to boot..."
        sleep 30
    end

    echo "Jumping to PC ($pc_ip) at $target_dir..."
    ssh -t void@$pc_ip "cd '$target_dir' && exec fish"
end
```

### 3.4 Persistent Zellij Session Jump (`~/.config/fish/functions/jumppcz.fish`)

```fish
function jumppcz
    set target_dir (_get_pc_target_dir)
    set pc_ip (_get_pc_ip)

    if not nc -z -w 1 $pc_ip 22 2>/dev/null
        echo "PC is offline at $pc_ip. Sending Wake-on-LAN..."
        wakepc
        sleep 30
    end

    echo "Jumping to Zellij session on PC ($pc_ip) at $target_dir..."
    ssh -t void@$pc_ip "cd '$target_dir' && exec zellij attach -c astro"
end
```

### 3.5 Remote GUI Application Forwarding (`~/.config/fish/functions/guipc.fish`)

```fish
function guipc
    set app_cmd $argv[1]
    if test -z "$app_cmd"
        echo "Please specify a tool (e.g., guipc pyraf)"
        return 1
    end

    set target_dir (_get_pc_target_dir)
    set pc_ip (_get_pc_ip)

    if not nc -z -w 1 $pc_ip 22 2>/dev/null
        echo "PC is offline at $pc_ip. Sending Wake-on-LAN..."
        wakepc; sleep 30
    end

    echo "Starting Xpra Graphics Tunnel ($pc_ip)..."
    # 1. Start a persistent invisible X11 display (:100) on the Host PC
    ssh void@$pc_ip "xpra start :100 2>/dev/null"

    # 2. Attach the laptop to that display in the background
    # GDK_BACKEND=x11 prevents Wayland/Niri scale artifacts
    env GDK_BACKEND=x11 xpra attach ssh://void@$pc_ip/100 >/dev/null 2>&1 &
    set xpra_pid $last_pid

    echo "Launching $app_cmd on Host PC at $target_dir..."
    # 3. SSH in interactively, point graphics to :100, and launch the tool
    ssh -t void@$pc_ip "cd '$target_dir' && set -x DISPLAY :100 && exec fish -i -C '$app_cmd'"

    # 4. Clean up background Xpra window receiver on exit
    kill $xpra_pid
end
```

### 3.6 Persistent GUI Session (`~/.config/fish/functions/guipcz.fish`)

```fish
function guipcz
    set target_dir (_get_pc_target_dir)
    set pc_ip (_get_pc_ip)

    if not nc -z -w 1 $pc_ip 22 2>/dev/null
        echo "PC is offline at $pc_ip. Sending Wake-on-LAN..."
        wakepc; sleep 30
    end

    echo "Starting Xpra Graphics Tunnel ($pc_ip)..."
    ssh void@$pc_ip "xpra start :100 2>/dev/null"

    env GDK_BACKEND=x11 xpra attach ssh://void@$pc_ip/100 >/dev/null 2>&1 &
    set xpra_pid $last_pid

    echo "Jumping to Zellij (GUI-enabled) session on PC ($pc_ip) at $target_dir..."
    ssh -t void@$pc_ip "cd '$target_dir' && set -x DISPLAY :100 && exec zellij attach -c astro_gui"

    kill $xpra_pid
end
```

### 3.7 Direct SSH (`~/.config/fish/functions/sshpc.fish`)

```fish
function sshpc
    set pc_ip (_get_pc_ip)

    if not nc -z -w 1 $pc_ip 22 2>/dev/null
        echo "PC is offline at $pc_ip. Sending Wake-on-LAN via voidphone..."
        wakepc
        echo "Waiting 30 seconds for PC to boot and connect..."
        sleep 30
    end

    echo "Connecting to PC ($pc_ip)..."
    ssh void@$pc_ip
end
```

---

## 4. Dolphin Right-Click Context Menu Integration

Create the KDE Service Menu:

```bash
mkdir -p ~/.local/share/kio/servicemenus
nano ~/.local/share/kio/servicemenus/antiremote.desktop
```

Paste:

```ini
[Desktop Entry]
Type=Service
MimeType=inode/directory;
Actions=OpenRemote;
X-KDE-Priority=TopLevel

[Desktop Action OpenRemote]
Name=Open PC (Antigravity IDE) Here
Icon=vscode
Exec=bash -c 'target="%f"; if [[ "$target" == /mnt/PC_Home* ]]; then target="${target/\/mnt\/PC_Home/\/home\/void}"; elif [[ "$target" == /mnt/PC_Storage* ]]; then target="${target/\/mnt\/PC_Storage/\/mnt\/Storage}"; elif [[ "$target" == /home/void* ]]; then target="${target/\/home\/void/\/mnt\/Laptop_Home}"; else target="/home/void"; fi; antigravity-ide --folder-uri "vscode-remote://ssh-remote+pc$target"'
```

Register the action:

```bash
chmod +x ~/.local/share/kio/servicemenus/antiremote.desktop
kbuildsycoca6
```

---

## 5. Network Shares (Samba / CIFS Mounts)

### 5.1 Host PC Samba Setup
Ensure Samba is sharing `/home/void` and `/mnt/Storage` on the PC (`/etc/samba/smb.conf`):

```ini
[Home]
   path = /home/void
   browseable = yes
   writable = yes
   valid users = void

[Storage]
   path = /mnt/Storage
   browseable = yes
   writable = yes
   valid users = void
```

Ensure user is created and service active on PC:

```bash
sudo smbpasswd -a void
sudo systemctl enable --now smbd
```

### 5.2 Laptop Mounting (`/etc/fstab`)

1. Save credentials in `/etc/samba/credentials`:
   ```bash
   sudo mkdir -p /etc/samba
   sudo bash -c 'cat > /etc/samba/credentials << EOF
   username=void
   password=YOUR_PASSWORD
   EOF'
   sudo chmod 600 /etc/samba/credentials
   ```

2. Add mount points in `/etc/fstab`:
   ```fstab
   //172.21.0.174/Storage  /mnt/PC_Storage  cifs  credentials=/etc/samba/credentials,uid=1000,gid=1000,users,vers=3.1.1,soft,echo_interval=30,noauto,nofail,_netdev  0  0
   //172.21.0.174/Home     /mnt/PC_Home     cifs  credentials=/etc/samba/credentials,uid=1000,gid=1000,users,vers=3.1.1,soft,echo_interval=30,noauto,nofail,_netdev  0  0
   ```

3. Create the mount targets:
   ```bash
   sudo mkdir -p /mnt/PC_Home /mnt/PC_Storage
   ```

4. Mount on demand (no sudo needed due to `users` option):
   ```bash
   mount /mnt/PC_Home
   mount /mnt/PC_Storage
   ```

---

## 6. Daily Usage Cheat Sheet

| Command | Action |
| :--- | :--- |
| `jumppc` | SSH into PC, landing in the translated active directory |
| `jumppcz` | Re-attach to persistent Zellij session (`astro`) on PC |
| `guipc pyraf` | Launch GUI application on PC, streaming window via Xpra |
| `guipcz` | Attach to persistent GUI-ready Zellij session (`astro_gui`) |
| `sshpc` | Standard SSH connection directly to PC |
| Right-click folder in Dolphin | "Open PC (Antigravity IDE) Here" opens remote workspace |

### Detaching from Zellij Safely
* Press `Ctrl + o`, then `d` to cleanly detach from any Zellij session without stopping background jobs.
* Press `Ctrl + q` inside Zellij to kill the workspace session.
