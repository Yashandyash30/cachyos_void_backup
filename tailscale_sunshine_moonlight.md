# Headless Game Streaming with Virtual Displays (Niri & Sunshine)

Here is the complete, start-to-finish guide for your dynamic, hardware-accelerated headless streaming setup on CachyOS. This updated version correctly isolates your standard Niri session from your experimental streaming session.

> [!IMPORTANT]
> ### 🛑 Choose Your Path: HDMI Dummy Plug vs. Virtual Outputs
> 
> Before proceeding, determine whether you are using an **HDMI Dummy Plug** or running **Pure Software Headless**:
> 
> * **If you have an HDMI Dummy Plug plugged in (Recommended):**
>   * **Skip `niri-virtual` and Phase 1–4:** The dummy plug already provides a real hardware display output (e.g. `HDMI-A-2`). You can simply boot into standard, stable CachyOS `niri`.
>   * **Do NOT use Privacy Mode or `ddcutil` (Phase 5–7):** A dummy plug emits no light and has no panel. You already have 100% privacy. Running `ddcutil` on a dummy plug causes I2C bus hangs because dummy plugs lack DDC/CI microcontrollers.
>   * **Do NOT create virtual outputs on top of a dummy plug:** Creating a virtual output at `(0, 0)` while a dummy plug is active confuses Sunshine's `wlgrab` monitor selector and causes the Intel GPU driver (`i915`) to leak dozens of gigabytes of framebuffers into `shmem`, triggering kernel Out-Of-Memory (OOM) crashes.
>   * **Sunshine Configuration:** Simply use the standard **Desktop** mode in Sunshine with **NO** Do/Undo commands.
> 
> * **If you have NO dummy plug and NO monitor (Pure Virtual Displays):**
>   * Follow Phase 1 through Phase 8 below to build the custom compositor and dynamically spawn virtual outputs.

---

## Phase 1: Build the Experimental Niri Compositor

To utilize virtual outputs, you need the specific Niri build that includes the unmerged virtual display pull request (PR #3800).

**1. Install the Rust toolchain and dependencies (if needed):**
```bash
sudo pacman -S rustup
rustup default stable
```

**2. Clone the Niri repository and check out the pull request:**
```bash
git clone https://github.com/YaLTeR/niri.git
cd niri
git fetch origin pull/3800/head:virtual-outputs
git checkout virtual-outputs
```

**3. Build the binary in release mode:**
```bash
cargo build --release
```

**4. Move the compiled binary to your local binaries folder:**
This ensures it doesn't overwrite your stable CachyOS Niri installation.
```bash
sudo cp target/release/niri /usr/local/bin/niri-virtual
```

---

## Phase 2: Create the Dynamic Systemd Wrapper

This script handles the heavy lifting. When launched, it temporarily hijacks systemd to boot your custom binary, hands control to the CachyOS session manager, and then cleans up after itself when you log out so your standard Niri session remains untouched.

**1. Open a new wrapper script file:**
```bash
sudo nano /usr/local/bin/niri-virtual-session
```

**2. Paste this exact configuration:**
```bash
#!/bin/bash

# 1. Create a temporary systemd override
mkdir -p "$HOME/.config/systemd/user/niri.service.d"

cat << 'EOF' > "$HOME/.config/systemd/user/niri.service.d/virtual-override.conf"
[Service]
ExecStart=
ExecStartPre=/usr/bin/sleep 1
ExecStart=/usr/local/bin/niri-virtual --session
EOF

systemctl --user daemon-reload

# 2. Hand control back to the standard CachyOS session manager
/usr/bin/niri-session

# 3. Clean up the override upon logout/shutdown
rm -f "$HOME/.config/systemd/user/niri.service.d/virtual-override.conf"
systemctl --user daemon-reload
```

**3. Make the script executable:**
```bash
sudo chmod +x /usr/local/bin/niri-virtual-session
```

---

## Phase 3: Register the Custom Desktop Session

SDDM needs to know this script exists so you can log into it.

**1. Create a new Wayland session file:**
```bash
sudo nano /usr/share/wayland-sessions/niri-virtual.desktop
```

**2. Paste this configuration inside:**
```ini
[Desktop Entry]
Name=Niri Virtual
Comment=Niri Wayland compositor with experimental virtual outputs
Exec=/usr/local/bin/niri-virtual-session
Type=Application
```

---

## Phase 4: Configure SDDM Autologin

Set SDDM to automatically boot into your new, isolated streaming environment on startup.

**1. Open your SDDM autologin configuration:**
```bash
sudo nano /etc/sddm.conf.d/autologin.conf
```

**2. Update the file to target the new session:**
```ini
[Autologin]
User=void
Session=niri-virtual
```

---

## Phase 5: Hardware Monitor Control (DDC/CI)

To prevent Wayland pipeline crashes, we bypass OS-level sleep and command the monitors to enter electrical standby via their HDMI/DisplayPort cables.

> [!WARNING]
> **Do NOT run `ddcutil` on an HDMI Dummy Plug:**
> DDC/CI commands are only understood by real monitors with internal display controller boards and physical backlights. An HDMI dummy plug has no DDC/CI chip; sending VCP commands to it causes I2C communication timeouts and kernel bus stalls. Only target physical monitors (e.g., HP monitors) with `ddcutil`.

**1. Ensure `ddcutil` is installed and your user is in the `i2c` group:**
```bash
sudo pacman -S ddcutil
sudo usermod -aG i2c $USER
```
*(A reboot is required if you just added yourself to the group).*

**2. Verify your monitor IDs (typically `1` and `2` for a dual-monitor setup):**
```bash
ddcutil detect
```

---

## Phase 6: The "Panic Button" Safeguard

If a Moonlight stream crashes, the exit script won't run, leaving your physical monitors in hardware sleep. You need a dedicated Niri keybind to wake them up.

**1. Open your Niri configuration:**
```bash
nano ~/.config/niri/config.kdl
```

**2. Add this command to your binds section:**
```kdl
    // Emergency Monitor Wake-Up (Panic Button via DDC/CI Hardware Standby)
    Mod+Shift+Backspace { spawn "bash" "-c" "ddcutil -d 1 setvcp 0xd6 0x01 || true; ddcutil -d 2 setvcp 0xd6 0x01 || true"; }
```
*(Note: If you are entirely locked out of the PC, you can trigger these same commands remotely via SSH from your laptop—see the SSH/Tailscale guide for those commands).*

---

## Phase 7: Automate Sunshine

Configure Sunshine to handle streaming smoothly.

> [!TIP]
> **Configuration Profiles: Dummy Plug vs. Physical Monitor**
> 
> * **If using an HDMI Dummy Plug:**
>   * Use the standard **Desktop** profile in Sunshine.
>   * **Leave Do Command and Undo Command empty.** You do not need to create virtual displays or call `ddcutil`.
>   * In Sunshine Web UI (**Configuration -> Audio/Video**), set your encoder priority explicitly to **VAAPI** (Intel QuickSync) to prevent Sunshine from failing on NVENC/Vulkan and looping.
> * **If using a Physical Monitor (and you want it to go dark while streaming):**
>   * Use the **Desktop-Privacy** configuration below to sleep the panel via DDC/CI.

**1. Navigate to the Configuration Screen:**
Open the Sunshine Web UI (`https://localhost:47990`) and navigate to **Application -> edit (for first Desktop)**.

**2. Rename the Default Desktop (For Physical Monitor Privacy):**
Change the name from **Desktop** to **Desktop-Privacy**.

**3. Configure the Pre/Post Commands:**
Below the command preparation section, set the **Do Command** to spin up the virtual screen and put the physical monitors to sleep:
```bash
sh -c "/usr/local/bin/niri-virtual msg create-virtual-output --name sunshine --width ${SUNSHINE_CLIENT_WIDTH} --height ${SUNSHINE_CLIENT_HEIGHT} --refresh-rate ${SUNSHINE_CLIENT_FPS} || true; sleep 2; ddcutil -d 1 setvcp 0xd6 0x04 || true; ddcutil -d 2 setvcp 0xd6 0x04 || true"
```

Set the **Undo Command** to wake your physical monitors and destroy the virtual output upon disconnect:
```bash
sh -c "ddcutil -d 1 setvcp 0xd6 0x01 || true; ddcutil -d 2 setvcp 0xd6 0x01 || true; /usr/local/bin/niri-virtual msg remove-virtual-output sunshine || true"
```
Click **Save** at the bottom to apply changes.

**4. Add a Standard Desktop Entry (For Normal / Dummy Plug Streaming):**
To add a normal Desktop entry without privacy scripts:
* Click on **Add New**.
* Enter **Desktop** in the **Application Name** box.
* Leave **Do Command** and **Undo Command** completely blank.
* Click on **Find Cover** in the Image Section to choose an appropriate icon.
* Click **Save** at the bottom to apply changes.

---

## Phase 8: Fix Moonlight Cursor Boundaries (Input Mapping)

When streaming a single display on a multi-monitor Wayland host, or when disconnecting a physical monitor, Moonlight's absolute mouse/touch mapping (used by phones and tablets) can hit an invisible wall or only move halfway across the screen. This happens because Wayland maps absolute coordinates globally across the entire combined desktop width (e.g., 3840px across two 1080p monitors) instead of scaling to the single stream output.

### Path A: Virtual Output (`niri-virtual`)
If using pure software virtual displays, tell Niri to spawn Sunshine's virtual output directly at origin `(0, 0)`:

1. Open `~/.config/niri/config.kdl`:
   ```kdl
   output "sunshine" {
       position x=0 y=0
   }
   ```
2. When Sunshine creates the virtual display, it overlaps at the origin, eliminating cursor offset without needing to power down physical panels.

---

### Path B: Physical Multi-Monitor Hosts (e.g. Rig: MSI Left + HP Right)
If using real physical monitors (e.g., MSI MAG on Left at `0, 0` and HP on Right at `1920, 0`), streaming the right-side monitor (`DP-1`) causes absolute touches on 0–50% of your tablet screen to land on the off-stream MSI monitor!

**Permanent Fix: Dynamic Alignment via Sunshine Do/Undo Script**
Do **not** statically hardcode `DP-1` to `(0, 0)` in `config.kdl`—that reverses your physical desk layout. Instead, let `~/.local/bin/sunshine-rig-prep.sh` dynamically shift the outputs:

- **When Moonlight Connects (`do`):**
  Temporarily moves `DP-1` to `(0, 0)` and `HDMI-A-1` to `(1920, 0)` so Moonlight's absolute cursor maps 1:1 with zero boundary issues, and locks refresh rate to `$SUNSHINE_CLIENT_FPS`.
- **When Moonlight Disconnects (`undo`):**
  Automatically restores your physical desk arrangement:
  - MSI MAG (`HDMI-A-1`): Left at `(0, 0)` @ 200 Hz.
  - HP (`DP-1`): Right at `(1920, 0)` @ 100 Hz.
- **Single-Monitor Away Mode:** If MSI is unplugged or powered off before leaving home, `DP-1` automatically starts and stays at `(0, 0)`.

**Emergency Reset Command:**
If a stream ever terminates abruptly and leaves monitors swapped, run:
```fish
resetmonitors
```
This restores MSI MAG to Left (200 Hz) and HP to Right (100 Hz) instantly.

---

## Further Reading & Performance Optimization

For complete refresh rate cadence math, on-the-fly refresh rate switching via Sunshine/SSH, and Wayland double-VSync elimination, refer to the dedicated guide:
👉 [09_Low_Latency_Streaming_Optimization.md](file:///home/void/Cachyos-installation/Configuration/09_Low_Latency_Streaming_Optimization.md)
