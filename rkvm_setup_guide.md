# rkvm setup guide (CachyOS + Niri)

`rkvm` shares one physical keyboard and mouse across Linux machines over TLS. It reads and injects events at the kernel level through `evdev` and `/dev/uinput`, so Niri compositor keybinds (such as `Mod` shortcuts) work on remote clients the same way they do on the host.

## Current topology

- Server (physical keyboard and mouse): `void-rig-cachyos`, Tailscale IP `100.106.197.11`, LAN IP `172.21.2.26`, runs `rkvm-server`
- Client (laptop, reachable via `ssh laptop`): `void`, Tailscale IP `100.70.236.70`, runs `rkvm-client`
- Port: `5258/tcp`
- Switch shortcut: `Right Alt + Right Shift` (avoids Moonlight's `Ctrl + Alt + Shift + Q`)

Using the Tailscale IP keeps the connection stable across DHCP changes and routes directly over LAN when both machines are on the same network.

## Prerequisites

Confirm `/dev/uinput` exists on every machine:

```bash
ls -l /dev/uinput
```

If `/dev/uinput` is missing, load the module and make it persistent:

```bash
sudo modprobe uinput
echo uinput | sudo tee /etc/modules-load.d/uinput.conf
```

Install build and runtime dependencies if they are not already present:

```bash
sudo pacman -S --needed libevdev clang pkgconf openssl rust
```

## Installation

### Option 1: Install from AUR on each machine

```bash
paru -S rkvm
```

### Option 2: Build once and install on both x86_64 machines

```bash
mkdir -p /tmp/rkvm-build && cd /tmp/rkvm-build
paru -G rkvm
cd rkvm
makepkg -f
sudo pacman -U rkvm-*.pkg.tar.zst
```

Copy the built package to the laptop and install it there:

```bash
scp rkvm-*.pkg.tar.zst laptop:/tmp/
ssh -t laptop 'sudo pacman -U /tmp/rkvm-*.pkg.tar.zst'
```

## TLS certificate and password

Generate a self-signed certificate on the server using `rkvm-certificate-gen`. Include both the Tailscale IP and LAN IP as SANs so you can switch between them later without regenerating the cert:

```bash
sudo install -d -m 755 /etc/rkvm
sudo rkvm-certificate-gen /etc/rkvm/certificate.pem /etc/rkvm/key.pem \
  -i 100.106.197.11 \
  -i 172.21.2.26 \
  -D 3650
sudo chmod 644 /etc/rkvm/certificate.pem
sudo chmod 600 /etc/rkvm/key.pem
```

Copy only the public certificate to the laptop (never copy `key.pem`):

```bash
scp /etc/rkvm/certificate.pem laptop:/tmp/certificate.pem
ssh -t laptop 'sudo install -d -m 755 /etc/rkvm && sudo install -m 644 /tmp/certificate.pem /etc/rkvm/certificate.pem && rm /tmp/certificate.pem'
```

Generate a shared password to place in both configs:

```bash
openssl rand -hex 16
```

## Configuration

### Server (`/etc/rkvm/server.toml`)

Create `/etc/rkvm/server.toml` on the host machine:

```toml
listen = "0.0.0.0:5258"
switch-keys = ["right-alt", "right-shift"]
propagate-switch-keys = false
certificate = "/etc/rkvm/certificate.pem"
key = "/etc/rkvm/key.pem"
password = "REPLACE_WITH_SHARED_PASSWORD"
```

Lock down permissions:

```bash
sudo chmod 600 /etc/rkvm/server.toml
```

For other key names supported in `switch-keys`, see `switch-keys.md` in the `htrefil/rkvm` repository. Restart `rkvm-server` after any config change.

### Client (`/etc/rkvm/client.toml`)

Create `/etc/rkvm/client.toml` on the laptop:

```toml
server = "100.106.197.11:5258"
certificate = "/etc/rkvm/certificate.pem"
password = "REPLACE_WITH_SHARED_PASSWORD"
```

Lock down permissions:

```bash
sudo chmod 600 /etc/rkvm/client.toml
```

### Firewall (UFW)

Open port `5258/tcp` on the server:

```bash
sudo ufw allow 5258/tcp comment 'rkvm'
```

The client only makes outbound connections and does not need an inbound UFW rule.

## First test run

Because `rkvm-server` grabs all local input devices, run a timed test on the server before enabling the service:

```bash
sudo rkvm-server /etc/rkvm/server.toml --shutdown-after 15
```

Move the mouse and type during those 15 seconds to verify Niri receives virtual input normally. If input freezes, wait 15 seconds for the process to exit on its own.

## Automatic activation on boot and resume

### Boot auto-start

Enable and start the systemd services on both machines:

```bash
# On server
sudo systemctl enable --now rkvm-server

# On laptop
ssh -t laptop 'sudo systemctl enable --now rkvm-client'
```

Both unit files shipped by the package already handle restarts:

- `rkvm-server.service` uses `Restart=always` and `RestartSec=5`.
- `rkvm-client.service` uses `After=network-online.target`, `Restart=always`, `RestartSec=5`, and `StartLimitIntervalSec=0`, so the client retries every 5 seconds until the server and Tailscale are reachable.

### Reconnect automatically after laptop sleep/resume

When the laptop suspends and wakes up, the existing TCP socket to the server can go stale until a timeout expires. Add a systemd sleep hook on the laptop so `rkvm-client` restarts immediately on resume:

```bash
sudo tee /usr/lib/systemd/system-sleep/rkvm >/dev/null <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "post" ]; then
    systemctl restart rkvm-client
fi
EOF
sudo chmod 755 /usr/lib/systemd/system-sleep/rkvm
```

## Adding another Linux client

1. Install `rkvm` on the new machine.
2. Copy `/etc/rkvm/certificate.pem` from the server to `/etc/rkvm/certificate.pem` on the new machine.
3. Create `/etc/rkvm/client.toml` with the same `server` address and `password`.
4. Run `sudo systemctl enable --now rkvm-client`.

Pressing `switch-keys` cycles through the host (`idx=0`) and each connected client (`idx=1`, `idx=2`, and so on).

## Troubleshooting

### Check service status and logs

```bash
# Server
systemctl status rkvm-server
journalctl -u rkvm-server -n 30 --no-pager

# Laptop
ssh laptop 'systemctl status rkvm-client'
ssh laptop 'journalctl -u rkvm-client -n 30 --no-pager'
```

A healthy connection logs `Connected`, `TLS connected`, and `Authenticated successfully` on the server, followed by `Created new device` lines on the client.

### Switch shortcut stays on `idx=0`

`journalctl -u rkvm-server` shows `Switched client idx=0` when no client is connected. Check `journalctl -u rkvm-client` on the laptop to see why it has not connected.

### Connection refused or timed out

- Verify Tailscale is up on both machines (`tailscale status`).
- Verify the server is listening: `ss -tlnp | grep 5258`.
- Verify UFW allows `5258/tcp` on the server: `sudo ufw status | grep 5258`.
- Test TCP reachability from the laptop: `nc -zv 100.106.197.11 5258`.

### TLS certificate validation error

The IP or hostname in `client.toml` must match a SAN embedded in `/etc/rkvm/certificate.pem`. Inspect the current cert SANs:

```bash
openssl x509 -in /etc/rkvm/certificate.pem -noout -text | grep -A1 "Subject Alternative Name"
```

If the server IP changed, regenerate the cert with the new IP via `rkvm-certificate-gen`, copy the updated `certificate.pem` to every client, and restart both services.

### Authentication failed

Passwords in `/etc/rkvm/server.toml` and `/etc/rkvm/client.toml` do not match. Fix the mismatch and restart both services.

### Client hangs after laptop wake

Restart the client manually or install the sleep hook above:

```bash
ssh -t laptop 'sudo systemctl restart rkvm-client'
```

### Input stuck on host after bad config

SSH into the server from another device and stop the service:

```bash
sudo systemctl stop rkvm-server
```
