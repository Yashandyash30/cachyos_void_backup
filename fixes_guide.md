# Master Troubleshooting & Setup Guide

This guide consolidates all diagnostic findings, fixes, and setups configured on this system into a clean, step-by-step reference.

---

## Part 1: Cloudflare WARP & Tailscale Coexistence & DNS Fix

### Problem

1. When WARP connected, internet and local access dropped because local subnet routes and Tailscale traffic were swallowed by the tunnel.
2. `/etc/resolv.conf` was a static file instead of a symlink, causing `systemd-resolved` to operate in `foreign` mode. This triggered Tailscale warnings (`systemd-resolved and NetworkManager are wired together incorrectly`) and caused WARP to overwrite `/etc/resolv.conf`, breaking all domain name resolution.
3. After reboot, Tailscale was stuck logged out (`unexpected state: NoState` with `register request ... context deadline exceeded`). Cloudflare WARP installed policy routing rule `5207: not from all fwmark 0x100cf lookup 65743` which took precedence over Tailscale's bypass rule `5210: from all fwmark 0x80000/0xff0000 lookup main` (and custom rule `5208`). Outbound Tailscale control plane traffic bound to the physical NIC IP was intercepted and dropped by the `CloudflareWARP` tunnel.
4. Local network router advertised an IPv6 DNS server (`fe80::360a:33ff:fe5e:bfe6`) via Router Advertisements (RA) that sinkholed `controlplane.tailscale.com` to `192.0.2.1` (RFC 5737 dummy address), causing Tailscale login failure: `fetch control key: Get "https://controlplane.tailscale.com/key?v=148": dial tcp 192.0.2.1:443: connect: network is unreachable`.
5. Exiting Cloudflare WARP GUI tray spawned a new instance automatically because `/usr/lib/systemd/user/warp-taskbar.service` was configured with `Restart=always`.

### Resolution Steps

#### 1. Exclude Local Subnet & Tailscale from WARP

Run in terminal (no `sudo` required):

```bash
# Correct the local subnet route (exclude local router gateway)
warp-cli tunnel ip remove-range 172.21.3.203/22 2>/dev/null || true
warp-cli tunnel ip add-range 172.21.0.0/22

# Exclude Tailscale hosts from the tunnel
warp-cli tunnel host add ts.net
warp-cli tunnel host add tailscale.com
warp-cli tunnel host add tailscale.net
warp-cli tunnel host add tailscale.io

# Route Tailscale MagicDNS domains through local resolver instead of Cloudflare DNS
warp-cli dns fallback add ts.net
warp-cli dns fallback add tailscale.net
warp-cli dns fallback add tailscale.com
```

#### 2. Switch `/etc/resolv.conf` to `systemd-resolved` Stub Mode

```bash
sudo rm -f /etc/resolv.conf
sudo ln -s /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
sudo systemctl restart NetworkManager systemd-resolved
```

#### 3. Fix Policy Routing Priority on Boot (`tailscale-warp-rule.service`)

Create `/etc/systemd/system/tailscale-warp-rule.service` so Tailscale's socket mark (`0x80000`) is evaluated at priority `5206` before WARP's `5207`:

```ini
[Unit]
Description=Tailscale and Cloudflare WARP routing compatibility fix
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/sh -c "ip rule del pref 5206 2>/dev/null || true; ip rule add pref 5206 fwmark 0x80000/0xff0000 lookup main; ip -6 rule del pref 5206 2>/dev/null || true; ip -6 rule add pref 5206 fwmark 0x80000/0xff0000 lookup main"
ExecStop=/bin/sh -c "ip rule del pref 5206 2>/dev/null || true; ip -6 rule del pref 5206 2>/dev/null || true"

[Install]
WantedBy=multi-user.target
```

Enable and start the service (and clean up any stale `5208` rule):

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now tailscale-warp-rule.service
sudo ip rule del pref 5208 2>/dev/null || true
sudo ip -6 rule del pref 5208 2>/dev/null || true
```

#### 4. Disable IPv6 Automatic DNS from Router (Prevent 192.0.2.1 Sinkhole)

Block local router RA from injecting its IPv6 DNS resolver into systemd-resolved:

```bash
nmcli connection modify "Wired connection 1" ipv6.ignore-auto-dns yes
nmcli device reapply enp5s0
```

#### 5. Disable Auto-Respawn on Exit for Cloudflare WARP Taskbar

Create `~/.config/systemd/user/warp-taskbar.service.d/override.conf`:

```ini
[Service]
Restart=no
```

Apply changes:

```bash
systemctl --user daemon-reload
```

#### Verification

```bash
# Verify resolv.conf is a symlink
ls -l /etc/resolv.conf
# Expected: /etc/resolv.conf -> /run/systemd/resolve/stub-resolv.conf

# Verify stub mode
resolvectl status | grep "resolv.conf mode"
# Expected: resolv.conf mode: stub

# Verify priority 5206 rule is active
ip rule show pref 5206
# Expected: 5206: from all fwmark 0x80000/0xff0000 lookup main

# Verify controlplane.tailscale.com resolves to real Tailscale IPs (not 192.0.2.1)
resolvectl query controlplane.tailscale.com

# Verify Tailscale status is active and healthy
tailscale status
```

---

## Part 2: Mounting Host PC Share (`PC_Home`) via Samba CIFS

### Problem

`/etc/fstab` contained the CIFS mount entry with the `users` option, but:

1. The mount folder `/mnt/PC_Home` did not exist.
2. `/etc/samba/credentials` did not exist.
3. Heredocs (`<< 'EOF'`) threw syntax errors in `fish` shell.
4. Setting `/etc/samba/credentials` permissions to `600` (root-only) blocked unprivileged user mounts (`error 13: Permission denied`).

### Resolution Steps

#### 1. Create the Mount Directory

```bash
sudo mkdir -p /mnt/PC_Home
```

#### 2. Create the Credentials File (Fish & Bash compatible)

```bash
printf "username=void\npassword=YOUR_SAMBA_PASSWORD\n" | sudo tee /etc/samba/credentials
```

> [!IMPORTANT]
> Replace `YOUR_SAMBA_PASSWORD` with the password configured on `void-pc` via `sudo smbpasswd -a void`.

#### 3. Set Proper Permissions for User Mounting

Because `/etc/fstab` uses the `users` mount option, the invoking user (`void`) and Dolphin require read access:

```bash
sudo chown root:void /etc/samba/credentials
sudo chmod 640 /etc/samba/credentials
```

#### 4. Reload Systemd and Mount

```bash
sudo systemctl daemon-reload
mount /mnt/PC_Home
```

#### 5. Verify Mount

```bash
ls -la /mnt/PC_Home
df -h /mnt/PC_Home
```

---

## Part 3: Dolphin Context Menus (KDE 6 Service Menus)

Three context menu actions were configured in `~/.local/share/kio/servicemenus/` so they appear at the top level when right-clicking folders in Dolphin:

### 1. "Open PC (Antigravity IDE) Here" (Remote SSH Tunnel)

File: `~/.local/share/kio/servicemenus/antiremote.desktop`

* Automatically translates local mount paths to remote host paths:
  * `/mnt/PC_Home/...` &rarr; `/home/void/...`
  * `/mnt/PC_Storage/...` &rarr; `/mnt/Storage/...`
  * `/home/void/...` &rarr; `/mnt/Laptop_Home/...`
* Launches Antigravity IDE directly inside the remote SSH workspace:

```ini
[Desktop Entry]
Type=Service
MimeType=inode/directory;
Actions=OpenIDE;
X-KDE-Priority=TopLevel

[Desktop Action OpenIDE]
Name=Open PC (Antigravity IDE) Here
Icon=antigravity-ide
Exec=bash -c 'target="%f"; if [[ "$target" == /mnt/PC_Home* ]]; then target="${target/\/mnt\/PC_Home/\/home\/void}"; elif [[ "$target" == /mnt/PC_Storage* ]]; then target="${target/\/mnt\/PC_Storage/\/mnt\/Storage}"; elif [[ "$target" == /home/void* ]]; then target="${target/\/home\/void/\/mnt\/Laptop_Home}"; else target="/home/void"; fi; antigravity-ide --folder-uri "vscode-remote://ssh-remote+void@100.117.73.75$target"'
```

### 2. "Open in Antigravity IDE" (Local)

File: `~/.local/share/kio/servicemenus/antigravity.desktop`

```ini
[Desktop Entry]
Type=Service
MimeType=inode/directory;
Actions=OpenAntigravity;
X-KDE-Priority=TopLevel

[Desktop Action OpenAntigravity]
Name=Open in Antigravity IDE
Icon=antigravity-ide
Exec=antigravity-ide "%f"
```

### 3. "Open in Zed" (Local)

File: `~/.local/share/kio/servicemenus/zed.desktop`

```ini
[Desktop Entry]
Type=Service
MimeType=inode/directory;
Actions=OpenZed;
X-KDE-Priority=TopLevel

[Desktop Action OpenZed]
Name=Open in Zed
Icon=zed
Exec=zeditor "%f"
```

### 4. Apply & Refresh KDE Cache

```bash
chmod +x ~/.local/share/kio/servicemenus/*.desktop
kbuildsycoca6
```

*(A symlink was also created at `~/.local/bin/zed -> /usr/bin/zeditor` for convenient terminal usage).*

---

## Part 4: Fixing `btop` UTF-8 Locale on CachyOS

### Root Cause

Even though `/etc/locale.conf` was updated to `en_IN.UTF-8`:

1. `/etc/default/locale` still contained legacy `en_IN` (without `.UTF-8`). On login, PAM (`pam_env.so`) reads `/etc/default/locale` and overrode the session back to `en_IN`.
2. Existing open terminal sessions retained the inherited `LANG=en_IN` environment variables in memory.

### Actions Applied Automatically

1. Created `~/.config/fish/conf.d/locale.fish` to export `en_IN.UTF-8` across all interactive and login fish shell sessions.
2. Created `~/.config/environment.d/locale.conf` and updated `systemctl --user` environment to propagate UTF-8 to all user services and terminals.

### Final Step (Sync PAM Config)

To ensure SDDM/PAM never resets the locale on future logins:

```bash
sudo cp /etc/locale.conf /etc/default/locale
```

### In Your Current Terminal

In the terminal window where `btop` failed, reload the variables:

```bash
source ~/.config/fish/conf.d/locale.fish
btop
```

*(Any new terminal window will work automatically without running anything)*.
