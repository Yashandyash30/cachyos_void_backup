# Tablet Remote Access & Dual-Network Failover Guide (Tab S9 ↔ Rig ↔ Office PC)

This guide documents the architecture, bidirectional SSH key exchange, and **automatic LAN / Tailscale dual-network failover** between your Samsung Galaxy Tab S9 (Android / Termux), your main Rig PC (`void-rig-cachyos`), and your Office PC (`void-pc`).

---

## 1. Network & Host Mapping

| Device | Hostname / NetBIOS | OS & Shell | User | Local LAN IP / Subnet | Tailscale IP | SSH Port |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Tablet** | `yashs-tab-s9` | Android (Termux / Fish) | `u0_a484` | `172.21.3.148` *(DHCP)* | `100.78.165.3` | `8022` |
| **Main Rig** | `void-rig-cachyos` | CachyOS / Linux (Fish) | `void` | `172.21.1.185` | `100.106.197.11` | `22` |
| **Office PC** | `void-pc` | CachyOS / Linux (Fish) | `void` | `172.21.0.174` | `100.117.73.75` | `22` |

> [!NOTE]
> * Tablet Wi-Fi MAC Address: `2e:b9:53:fd:2f:81` (used by PC for dynamic ARP lookup if the tablet's local DHCP IP shifts).
> * The failover logic tests the local LAN IP first via a 1-second `nc` (netcat) probe. If reachable, traffic flows directly over LAN at sub-millisecond speeds. If unreachable (different subnet, AP isolation, or away from home), OpenSSH transparently falls back to Tailscale.

---

## 2. Tablet Setup (Android / Termux)

### 2.1 Core Packages Installation
Open Termux and install OpenSSH, Fish shell, and `netcat-openbsd` (required for OpenSSH `Match exec` probes):

```bash
pkg update && pkg install openssh fish netcat-openbsd -y
```

Set a login password for SSH / key installation:
```bash
passwd
```

Set Fish as your default shell in Termux:
```bash
chsh -s fish
```

### 2.2 Auto-Start SSH Daemon on Launch
Add this to `~/.config/fish/config.fish` so SSH server runs automatically in the background whenever Termux opens:

```fish
mkdir -p ~/.config/fish
echo 'if not pgrep -x sshd > /dev/null; sshd; end' >> ~/.config/fish/config.fish
sshd
```

### 2.3 Dynamic SSH Configuration (`~/.ssh/config`)
> [!CAUTION]
> **Fish Shell Heredoc Gotcha**: Do not use `cat << 'EOF'` in Fish shell; it corrupts quotes and breaks OpenSSH configs. Use `printf` or single-quoted echo.

Create or replace `~/.ssh/config` on the Tablet:

```fish
printf '# 1. Rig (void-rig-cachyos)\nMatch host rig,voidrig,void-rig,100.106.197.11 exec "nc -z -w 1 172.21.1.185 22 2>/dev/null"\n    HostName 172.21.1.185\n    User void\n    IdentityFile ~/.ssh/id_ed25519\n\nHost rig voidrig void-rig\n    HostName 100.106.197.11\n    User void\n    IdentityFile ~/.ssh/id_ed25519\n    ConnectTimeout 3\n\n# 2. Office PC (void-pc)\nMatch host pc,voidpc,void-pc,100.117.73.75 exec "nc -z -w 1 172.21.0.174 22 2>/dev/null"\n    HostName 172.21.0.174\n    User void\n    IdentityFile ~/.ssh/id_ed25519\n\nHost pc voidpc void-pc\n    HostName 100.117.73.75\n    User void\n    IdentityFile ~/.ssh/id_ed25519\n    ConnectTimeout 3\n' > ~/.ssh/config
chmod 600 ~/.ssh/config
```

### 2.4 Dedicated Fish Shortcut Functions (Tablet)
Save these inside `~/.config/fish/functions/` on the tablet:

* **Connect to Rig (`~/.config/fish/functions/sshrig.fish`)**:
  ```fish
  function sshrig
      ssh rig $argv
  end
  ```

* **Connect to Office PC (`~/.config/fish/functions/sshpc.fish`)**:
  ```fish
  function sshpc
      ssh pc $argv
  end
  ```

---

## 3. Main Rig Setup (`void-rig-cachyos`)

### 3.1 Enable Host SSH Daemon
Ensure the SSH server is running on the Rig to accept connections from the tablet:

```bash
sudo systemctl enable --now sshd
```

### 3.2 Dynamic OpenSSH Config (`~/.ssh/config`)
Add the Tablet dynamic failover block to `~/.ssh/config`:

```ssh-config
# Tablet Dynamic Failover
Match host tab,tablet,voidtab,voidtablet,100.78.165.3 exec "nc -z -w 1 172.21.3.148 8022 2>/dev/null"
    HostName 172.21.3.148
    Port 8022
    User u0_a484
    IdentityFile ~/.ssh/id_ed25519

Host tab tablet voidtab voidtablet
    HostName 100.78.165.3
    Port 8022
    User u0_a484
    IdentityFile ~/.ssh/id_ed25519
    ConnectTimeout 3
```

Set correct permissions:
```bash
chmod 600 ~/.ssh/config
```

### 3.3 Dynamic IP & ARP Resolver (`~/.config/fish/functions/_get_tab_ip.fish`)
Handles dynamic DHCP IP changes by scanning the local ARP cache for the tablet's MAC address:

```fish
function _get_tab_ip
    # 1. Test last known local LAN IP
    if nc -z -w 1 172.21.3.148 8022 2>/dev/null
        echo "172.21.3.148"
        return
    end

    # 2. Check ARP table for tablet MAC (2e:b9:53:fd:2f:81) if DHCP IP shifted
    set lan_ip (ip neigh 2>/dev/null | grep -i "2e:b9:53:fd:2f:81" | awk '{print $1}')
    if test -n "$lan_ip"
        if nc -z -w 1 $lan_ip 8022 2>/dev/null
            echo "$lan_ip"
            return
        end
    end

    # 3. Fallback to Tailscale IP
    echo "100.78.165.3"
end
```

### 3.4 Rig Shortcut Function (`~/.config/fish/functions/sshtab.fish`)
```fish
function sshtab
    set tab_ip (_get_tab_ip)
    echo "Connecting to Tablet ($tab_ip:8022)..."
    ssh -p 8022 u0_a484@$tab_ip $argv
end
```

---

## 4. Bidirectional SSH Key Authentication

### 4.1 Tablet &rarr; Host PCs (Passwordless login from Tablet)
On the Tablet:
1. Generate key:
   ```bash
   ssh-keygen -t ed25519
   ```
2. Copy key to Rig:
   ```bash
   ssh-copy-id void@172.21.1.185
   # (Or over Tailscale: ssh-copy-id void@100.106.197.11)
   ```
3. Copy key to Office PC:
   ```bash
   ssh-copy-id void@172.21.0.174
   # (Or over Tailscale: ssh-copy-id void@100.117.73.75)
   ```

### 4.2 Rig &rarr; Tablet (Passwordless login from Rig)
On the Rig:
```bash
ssh-copy-id -p 8022 u0_a484@172.21.3.148
# (Or over Tailscale: ssh-copy-id -p 8022 u0_a484@100.78.165.3)
```

---

## 5. File Manager Integration (Dolphin SFTP)

You can mount and browse the tablet's full Android storage directly in Dolphin over SSH / SFTP:

1. Open **Dolphin** on your Rig or Office PC.
2. Press `Ctrl + L` to focus the path bar.
3. Enter:
   ```
   sftp://u0_a484@100.78.165.3:8022/storage/emulated/0
   ```
4. Right-click inside the folder or address bar and click **"Add to Places"**.
5. Name it **"Tab S9 Storage"**.

---

## 6. Daily Usage Cheat Sheet

| Action | Command | Executed From | Target | Routing |
| :--- | :--- | :--- | :--- | :--- |
| **Connect to Tablet** | `sshtab` or `ssh tab` | Rig | Tablet (`u0_a484`) | LAN `172.21.3.148:8022` &rarr; Failover `100.78.165.3:8022` |
| **Connect to Rig** | `sshrig` or `ssh rig` | Tablet | Main Rig (`void`) | LAN `172.21.1.185:22` &rarr; Failover `100.106.197.11:22` |
| **Connect to Office PC** | `sshpc` or `ssh pc` | Tablet | Office PC (`void`) | LAN `172.21.0.174:22` &rarr; Failover `100.117.73.75:22` |
| **Remote Command Execution** | `sshtab whoami` | Rig | Tablet | Direct output without interactive shell |
| **Tablet SFTP Browse** | Dolphin Places | Rig / PC | Tablet storage | Native GUI file transfer |

---

## 7. Troubleshooting & Gotchas

1. **`invalid quotes` error in OpenSSH on Android**:
   * Occurs when heredocs (`cat << 'EOF'`) in Fish shell truncate quotes or mobile keyboards convert ASCII quotes to Unicode smart quotes (`“”`).
   * Fix: Use `printf` to generate `~/.ssh/config`, or copy from PC using `scp -P 8022 config u0_a484@<IP>:~/.ssh/config`.

2. **`fish: Unknown command: nc`**:
   * Termux doesn't ship `nc` by default.
   * Fix: Run `pkg install netcat-openbsd -y`.

3. **Wi-Fi / Ethernet Subnet Routing (Connection timed out on LAN)**:
   * When Rig is on Ethernet (`172.21.1.x`) and Tablet is on Wi-Fi (`172.21.3.x`), certain institutional routers isolate wireless clients from wired nodes.
   * OpenSSH `Match exec` probe handles this gracefully: when `nc` probe times out (1s), it immediately routes through Tailscale (`100.106.197.11` / `100.78.165.3`) with zero manual intervention.
