# 09 - Low-Latency Stutter-Free Streaming & Dynamic Refresh Rate Optimization

This guide provides the complete blueprint for achieving smooth, zero-stutter, and low-latency bidirectional game and desktop streaming between your **Host PC** and **Laptop** using **Sunshine**, **Moonlight**, and the **Niri Wayland Compositor**.

---

## 1. The Core Stutter Problem: The Math of Refresh Rates

Streaming over a sub-millisecond local network (`0.27 ms`) can still feel choppy and laggy if frame pacing mathematics do not align.

### The "Rule of Three"

For completely fluid motion, three values must either **match exactly** or divide into an **exact whole integer**:

1. **Host Display Refresh Rate** (what the host renders)
2. **Stream Target FPS** (what Sunshine captures and encodes)
3. **Client Display Refresh Rate** (the physical screen showing the stream)

---

### The "100 FPS Trap" (Why Your Stream Stuttered)

Earlier, Moonlight on the laptop was configured to **`fps=100`** with **`vsync=true`**.

* **On the 120 Hz External Monitor (MSI MAG 255F):**

  $$
  \frac{120 \text{ Hz}}{100 \text{ FPS}} = 1.2 \quad (\text{Uneven cadence!})
  $$

  A 120 Hz screen refreshes every 8.33 ms. A 100 FPS stream sends a frame every 10 ms. Because 1.2 is not an integer, the monitor alternates between showing a frame for 1 refresh cycle (8.3 ms) and 2 refresh cycles (16.6 ms). To the human eye, this irregular cadence feels like **constant micro-stutter, mouse jitter, and hitching**.
* **On the 60 Hz Laptop Built-in Screen:**

  $$
  \frac{100 \text{ FPS}}{60 \text{ Hz}} = 1.66 \quad (\text{Dropped frames!})
  $$

  The screen can only display 60 frames per second. Moonlight drops 40 frames every second in an irregular pattern, creating heavy stutter.

---

### The "60 FPS" Magic Cadence

By locking your stream to **60 FPS**, the math aligns cleanly on **both** your screens:

$$
\frac{120 \text{ Hz}}{60 \text{ FPS}} = 2.0 \quad (\text{Exact integer: Every frame is shown for exactly 2 refreshes})
$$

$$
\frac{60 \text{ Hz}}{60 \text{ FPS}} = 1.0 \quad (\text{Exact integer: Every frame is shown for exactly 1 refresh})
$$

* **Result:** Zero dropped frames, zero frame-pacing oscillation, and perfectly smooth motion.

---

## 2. Hardware Profiles of Your Setup

| Machine                                | GPU Hardware                               | Active Displays                                           | Refresh Rates Supported                                                |
| :------------------------------------- | :----------------------------------------- | :-------------------------------------------------------- | :--------------------------------------------------------------------- |
| **Rig** (`void-rig-cachyos`)           | AMD Radeon RX 9060 XT (Navi 44)            | `DP-1` (HP 324pv) + `HDMI-A-1` (MSI MAG 255F)             | `DP-1`: 60 Hz, 74.9 Hz, 100 Hz<br>`HDMI-A-1`: 60 Hz, 120 Hz to 200 Hz |
| **Host PC** (`void-pc`)                | Intel UHD Graphics 770 (Raptor Lake-S GT1) | `HDMI-A-2` (HP 324pv or Dummy Plug)                       | 60 Hz, 74.9 Hz, 100 Hz                                                 |
| **Laptop** (`void`)                    | AMD Lucienne APU + NVIDIA GTX 1650 Mobile  | `eDP-1` (Internal) + `HDMI-A-1` (MSI MAG 255F)            | `eDP-1`: 60 Hz<br>`HDMI-A-1`: 60 Hz, 120 Hz (up to 200 Hz)             |

---

## 3. Dynamic "On-The-Fly" Refresh Rate Switching

You can switch the refresh rate of your PC's HP monitor or HDMI Dummy Plug **dynamically without restarting Niri, logging out, or interrupting running applications**.

Niri supports instant mode switching through its IPC interface:

```bash
niri msg output <OUTPUT_NAME> mode <WIDTH>x<HEIGHT>@<REFRESH_RATE>
```

> [!IMPORTANT]
> **Why `NIRI_SOCKET` is Required for Scripts and SSH**:
> Niri communicates over a UNIX domain socket in `/run/user/1000/`. When running commands over SSH or background daemon scripts, the non-interactive shell does not inherit `NIRI_SOCKET`. Always export it before running `niri msg`:
>
> ```bash
> export NIRI_SOCKET=$(echo /run/user/1000/niri.*.sock)
> ```

---

### Method A: Automated Refresh Rate Matching via Sunshine (Recommended)

Sunshine can automatically detect the FPS that Moonlight requests, switch the host display to match it upon connection, and restore 100 Hz (or 200 Hz) when the session ends.

#### 1. Rig Setup (`void-rig-cachyos`):
On the Rig, use the automated dynamic prep script located at `~/.local/bin/sunshine-rig-prep.sh`:
* Configured in `~/.config/sunshine/apps.json` under **Desktop**, **Low Res Desktop**, and **Steam Big Picture**:
  * **Do Command:** `/home/void/.local/bin/sunshine-rig-prep.sh do`
  * **Undo Command:** `/home/void/.local/bin/sunshine-rig-prep.sh undo`
* **Dynamic FPS & Boundary Alignment:**
  * **While Streaming (`do`):** Temporarily maps `DP-1` to `(0, 0)` so Moonlight touch/mouse has zero offset, and switches display to `$SUNSHINE_CLIENT_FPS` (e.g. 60 or 120 Hz).
  * **When Disconnecting (`undo`):** Automatically restores the physical dual-monitor layout:
    - MSI MAG 255F (`HDMI-A-1`): Left at `(0, 0)` @ 200 Hz.
    - HP 324pv (`DP-1`): Right at `(1920, 0)` @ 100 Hz.
  * **Away Mode:** If MSI is disconnected or powered off before leaving, `DP-1` runs at `(0, 0)` with no dead phantom coordinate space.

* **Rig Sunshine Service Management & Systemd Override:**
  To eliminate boot race conditions with DMS DankBar and ensure high reliability:
  * Drop-in: `~/.config/systemd/user/app-dev.lizardbyte.app.Sunshine.service.d/override.conf`:
    ```ini
    [Service]
    ExecStartPre=
    ExecStartPre=/bin/sleep 10
    Restart=always
    RestartSec=3s
    ```
  * Quick Fish Commands on Rig:
    - `resetmonitors`: Restore physical monitor layout (MSI Left, HP Right).
    - `sunshineweb`: Open Sunshine Web UI (`https://localhost:47990`).
    - `stopsunshine`: Stop Sunshine service cleanly (e.g. to free VRAM for ComfyUI).
    - `startsunshine`: Start Sunshine background service.
    - `restartsunshine`: Restart Sunshine background service.

#### 2. Host PC Setup (`void-pc`):
1. Open Sunshine Web UI on Host PC: `https://localhost:47990`
2. Navigate to **Applications** → click **Edit** on your **Smart-Desktop** (or **Desktop**) application.
3. Configure the **Command Preparation** fields:

* **Do Command (Runs automatically when Moonlight connects):**

  ```bash
  sh -c "export NIRI_SOCKET=$(echo /run/user/1000/niri.*.sock); niri msg output HDMI-A-2 mode 1920x1080@${SUNSHINE_CLIENT_FPS}.000 || niri msg output HDMI-A-2 mode 1920x1080@60.000 || true"
  ```
* **Undo Command (Runs automatically when Moonlight disconnects):**

  ```bash
  sh -c "export NIRI_SOCKET=$(echo /run/user/1000/niri.*.sock); niri msg output HDMI-A-2 mode 1920x1080@100.000 || true"
  ```

> [!WARNING]
> **Do not escape the `$` symbol with `\`!**
> Enter `$(echo ...)` and `${SUNSHINE_CLIENT_FPS}` exactly as shown without a preceding backslash. If escaped (`\$`), Sunshine's Boost command parser treats it as an invalid escape sequence, corrupts `NIRI_SOCKET`, and Moonlight will throw:
> `Host returned error: Failed to start the specified application (Error 0)`.

4. Click **Save** at the bottom.

---

### Method B: On-Demand Remote / Local Control (`setrigrefreshrate` & `setpcrefreshrate`)

Fish functions are installed on both the **Rig** and **Laptop**. When executed locally on the Rig, it runs directly. When run from the Laptop over SSH, it automatically routes to the Rig's IP.

#### Reusable Fish Function (`setrigrefreshrate`):

```fish
function setrigrefreshrate -d "Change refresh rate on Rig's displays (DP-1 or HDMI-A-1)"
    set hz $argv[1]
    set target_output $argv[2]
    if test -z "$hz"; set hz 60; end

    if test -z "$target_output"
        set conf "$HOME/.config/sunshine/sunshine.conf"
        if test -f "$conf"
            set val (grep -E "^output_name" "$conf" 2>/dev/null | awk -F'=' '{print $2}' | tr -d ' ')
            switch "$val"
                case 0 dp DP-1; set target_output "DP-1"
                case 1 hdmi HDMI-A-1; set target_output "HDMI-A-1"
                case "*"; set target_output "DP-1"
            end
        else
            set target_output "DP-1"
        end
    end

    if string match -q "*rig*" (hostname)
        set -gx NIRI_SOCKET (echo /run/user/1000/niri.*.sock)
        niri msg output $target_output mode 1920x1080@$hz.000
    else
        set rig_ip (_get_rig_ip)
        ssh void@$rig_ip "export NIRI_SOCKET=\$(echo /run/user/1000/niri.*.sock); niri msg output $target_output mode 1920x1080@$hz.000"
    end
    echo "Rig $target_output mode set to $hz Hz"
end
```

`setpcrefreshrate` is aliased to `setrigrefreshrate` for backwards compatibility.

Usage:
```bash
setrigrefreshrate 60             # Sets active Rig display (e.g. DP-1) to 60 Hz
setrigrefreshrate 100            # Sets active Rig display to 100 Hz
setrigrefreshrate 120 HDMI-A-1   # Sets MSI monitor on Rig to 120 Hz
setpcrefreshrate 60              # Backward-compatible alias
```

---

### Method C: Laptop Refresh Rate Switching (`HDMI-A-1` External Monitor)

Your laptop has two displays:
* **`eDP-1` (Inbuilt Panel):** Fixed at **60.05 Hz**.
* **`HDMI-A-1` (MSI MAG 255F):** Supports **60 Hz, 120 Hz, 165 Hz, 180 Hz, and 200 Hz**.

#### 1. Instant One-Liners for Laptop Screen:

* **Locally on Laptop:**
  ```bash
  export NIRI_SOCKET=$(echo /run/user/1000/niri.*.sock); niri msg output HDMI-A-1 mode 1920x1080@120.000
  ```
* **Remotely from Host PC over SSH:**
  ```bash
  ssh void@100.70.236.70 "export NIRI_SOCKET=\$(echo /run/user/1000/niri.*.sock); niri msg output HDMI-A-1 mode 1920x1080@120.000"
  ```

#### 2. Reusable Fish Function / Alias (`setlaptoprefreshrate`):

This smart function is installed on **both** your Host PC and Laptop. It automatically detects where you are and applies the change locally or over SSH:

```fish
function setlaptoprefreshrate -d "Change refresh rate on Laptop's external monitor (HDMI-A-1)"
    set hz $argv[1]
    if test -z "$hz"
        set hz 120
    end

    if test (hostname) = "void-pc"
        ssh void@100.70.236.70 "export NIRI_SOCKET=\$(echo /run/user/1000/niri.*.sock); niri msg output HDMI-A-1 mode 1920x1080@$hz.000"
    else
        set -gx NIRI_SOCKET (echo /run/user/1000/niri.*.sock)
        niri msg output HDMI-A-1 mode 1920x1080@$hz.000
    end
    echo "Laptop HDMI-A-1 (MSI MAG 255F) set to $hz Hz"
end
```

Usage:
```bash
setlaptoprefreshrate 60     # Sets MSI monitor on laptop to 60 Hz
setlaptoprefreshrate 120    # Sets MSI monitor on laptop to 120 Hz
setlaptoprefreshrate 180    # Sets MSI monitor on laptop to 180 Hz
```

#### 3. Automated Matching via Laptop Sunshine:

If you are streaming your laptop's screen to another device and want Sunshine to automatically match Moonlight's requested FPS:
1. Open Laptop Sunshine Web UI: `https://100.70.236.70:47990`
2. Go to **Applications** → **Desktop** → **Edit**.
3. Set **Do Command**:
   ```bash
   sh -c "export NIRI_SOCKET=$(echo /run/user/1000/niri.*.sock); niri msg output HDMI-A-1 mode 1920x1080@${SUNSHINE_CLIENT_FPS}.000 || niri msg output HDMI-A-1 mode 1920x1080@60.000 || true"
   ```
4. Set **Undo Command**:
   ```bash
   sh -c "export NIRI_SOCKET=$(echo /run/user/1000/niri.*.sock); niri msg output HDMI-A-1 mode 1920x1080@120.000 || true"
   ```

> [!WARNING]
> **Do not escape the `$` symbol with `\`!**
> In Sunshine Web UI text boxes, paste `$(echo ...)` and `${SUNSHINE_CLIENT_FPS}` directly. Escaping them (`\$`) breaks Boost parsing and causes Error 0.


---

## 4. Wayland (Niri) Optimization: Eliminating Double-VSync

A major source of input lag on Linux streaming is **Double-VSync**:

1. Niri (as a Wayland compositor) **always enforces hardware VSync** at the display pipeline level.
2. When Moonlight's in-app **VSync** is also enabled, frames are queued twice: once by Moonlight's client timer, and again by Niri's presentation engine. This adds **15–30 ms of input latency** and creates frame queue stalls.

### The Correct Moonlight Client Settings:

In Moonlight on your Laptop (and PC):

1. **Resolution:** Match your target window (`1920x1080`).
2. **Frame Rate:** Set to **`60 FPS`** (to match the 60 Hz panel / 120 Hz 2:1 cadence).
3. **VSync:** **OFF (Unchecked)** — Let the Wayland compositor handle vblank.
4. **Frame Pacing:** Set to **Balanced with frame drops** or **Lowest Latency**.

---

## 5. Network Configuration: Direct LAN vs. Tailscale

Tailscale automatically establishes direct peer-to-peer LAN connections (`0.27 ms` ping on your network). However, for high-bitrate video, consider the following:

* **Direct LAN IP (`172.21.0.174`):**
  * Uses standard **1500 MTU**.
  * Zero WireGuard encryption/decryption CPU overhead.
  * Best for absolute lowest frame-jitter when at home.
* **Tailscale IP (`100.117.73.75`):**
  * WireGuard clamps MTU to **1280 bytes** (causes slight packet fragmentation at bitrates > 35 Mbps).
  * Ideal when streaming remotely away from home.

---

## 6. Sunshine Hardware Encoder Settings

### Rig (`void-rig-cachyos` - AMD Radeon RX 9060 XT)

* Sunshine auto-detects Mesa RADV Vulkan and Mesa `radeonsi` VAAPI hardware encoders:
  * **Vulkan:** `hevc_vulkan`, `av1_vulkan`, `h264_vulkan`
  * **VAAPI:** `hevc_vaapi`, `h264_vaapi`, `av1_vaapi`
* Video Adapter: `/dev/dri/renderD128` (or default).
* Zero-copy DMA-BUF capture via `wlgrab` under Niri Wayland gives < 2ms encode times.

### Host PC (Intel QuickSync UHD 770)

* Open Sunshine Web UI → **Configuration** → **Audio/Video**:
  * **Encoder Priority:** Force **VAAPI** (`hevc_vaapi` or `h264_vaapi`).
  * **Video Adapter:** Leave default or set to `/dev/dri/renderD128`.
  * *Prevents Sunshine from cycling through failing NVENC/Vulkan encoders and restarting in a loop.*

### Laptop Host (AMD Lucienne APU + NVIDIA GTX 1650)

* Open Sunshine Web UI on Laptop → **Configuration** → **Audio/Video**:
  * For desktop streaming on Niri Wayland: Set adapter to AMD APU (`/dev/dri/renderD129`) with **VAAPI** to prevent cross-GPU memory sharing crashes.

---

## 7. Selecting Which Screen Sunshine Captures on Rig / Host PC (DP vs. HDMI)

Your Rig (`void-rig-cachyos`) GPU (AMD RX 9060 XT) exposes:
* **DisplayPort:** `DP-1` (HP 324pv - Monitor 0)
* **HDMI:** `HDMI-A-1` (MSI MAG 255F - Monitor 1)

Under Niri Wayland, Sunshine's `wlgrab` capture subsystem recognizes connector names and numeric indices:
```text
[wlgrab] Monitor 0 is DP-1: HP Inc. - HP 324pv - DP-1
[wlgrab] Monitor 1 is HDMI-A-1: Microstep - MAG 255F E20 - HDMI-A-1
```

Sunshine reads `output_name` in `~/.config/sunshine/sunshine.conf`. You can supply either the connector name (`DP-1`, `HDMI-A-1`) or numeric index (`0`, `1`).

---

### Method A: Instant Switcher Fish Function (`rigsunshinescreen` & `pcsunshinescreen`)

A smart Fish function is installed on **both** your Rig and Laptop. When executed on the Rig, it runs locally; when run from the Laptop, it automatically tunnels over SSH:

```fish
function rigsunshinescreen -d "Switch which screen Sunshine captures on Rig (DP vs HDMI)"
    set target $argv[1]

    set script '
        target="'$target'"
        conf="$HOME/.config/sunshine/sunshine.conf"
        export NIRI_SOCKET=$(echo /run/user/1000/niri.*.sock 2>/dev/null)

        if [ -z "$target" ] || [ "$target" = "status" ] || [ "$target" = "current" ]; then
            echo "=== Sunshine Rig Current Setting ==="
            grep "output_name" "$conf" 2>/dev/null || echo "output_name is not set (defaulting to primary/Monitor 0 - DP-1)"
            echo ""
            echo "=== Active Displays in Niri ==="
            niri msg outputs 2>/dev/null | grep -E "(Output|Current mode)" || echo "No Niri session detected"
            echo ""
            echo "=== Detected Monitors in Sunshine Logs ==="
            grep -m 4 "Monitor [0-9]" "$HOME/.config/sunshine/sunshine.log" 2>/dev/null || true
            exit 0
        fi

        case "$(echo "$target" | tr "[:upper:]" "[:lower:]")" in
            dp|displayport|dp-1|0)
                conn="DP-1"
                label="HP 324pv (DP-1 / Monitor 0)"
                ;;
            hdmi|hdmi-a-1|1)
                conn="HDMI-A-1"
                label="MSI MAG 255F (HDMI-A-1 / Monitor 1)"
                ;;
            *)
                conn="$target"
                label="$target"
                ;;
        esac

        mkdir -p "$(dirname "$conf")"
        if grep -q "^output_name" "$conf" 2>/dev/null; then
            sed -i "s/^output_name = .*/output_name = $conn/" "$conf"
        else
            echo "output_name = $conn" >> "$conf"
        fi

        systemctl --user restart sunshine.service
        echo "Sunshine on Rig switched to: $label ($conn)"
    '

    if string match -q "*rig*" (hostname)
        bash -c "$script"
    else
        set rig_ip (_get_rig_ip)
        echo "$script" | ssh void@$rig_ip "bash -s"
    end
end
```

`pcsunshinescreen` is aliased directly to `rigsunshinescreen`.

#### How to Use It:

* **Switch Sunshine to capture DisplayPort (HP 324pv):**
  ```bash
  rigsunshinescreen dp         # Switches to DP-1 (Monitor 0)
  ```
* **Switch Sunshine to capture HDMI (MSI MAG 255F):**
  ```bash
  rigsunshinescreen hdmi       # Switches to HDMI-A-1 (Monitor 1)
  ```
* **Target a connector directly:**
  ```bash
  rigsunshinescreen DP-1
  rigsunshinescreen HDMI-A-1
  pcsunshinescreen dp          # Works identically via alias
  ```
* **Check status and active outputs:**
  ```bash
  rigsunshinescreen status
  ```

---

### Method B: Sunshine Web UI (Browser)

1. Open the Sunshine Web UI on your Rig:
   * **Locally from Rig:** `https://localhost:47990`
   * **Remotely from Laptop:** `https://100.106.197.11:47990`
2. Navigate to **Configuration** → **Audio/Video**.
3. Scroll to **Display Id / Output Name**:
   * Enter `DP-1` (or `0`) for the DisplayPort monitor (HP 324pv).
   * Enter `HDMI-A-1` (or `1`) for the HDMI monitor (MSI MAG 255F).
4. Click **Save** at the bottom, then restart Sunshine.

---

## 8. Selecting Which Screen Sunshine Captures on Laptop (External Monitor vs. Inbuilt Screen)

When running Sunshine on your laptop under Wayland (Niri), the capture subsystem (`wlgrab`) enumerates all attached monitors into numeric indices:

```text
[wlgrab] Monitor 0 is eDP-1: AU Optronics - 0xDF87 (Inbuilt Panel)
[wlgrab] Monitor 1 is HDMI-A-1: Microstep - MAG 255F (External Monitor)
```

Sunshine decides which screen to capture using the **`output_name`** setting in `~/.config/sunshine/sunshine.conf`:
* `output_name = 0` $\rightarrow$ Captures the **Inbuilt Laptop Display (`eDP-1`)**
* `output_name = 1` $\rightarrow$ Captures the **External MSI Gaming Monitor (`HDMI-A-1`)**

---

### Method A: Instant Switcher Alias / Fish Function (`laptopsunshinescreen`)

A dedicated smart function is installed on both your **Host PC** and **Laptop**. It updates `sunshine.conf` and reloads the user daemon seamlessly in under a second:

```fish
function laptopsunshinescreen -d "Switch which screen Sunshine captures on Laptop (external vs internal)"
    set target $argv[1]
    switch "$target"
        case internal inbuilt edp edp-1 0
            set val 0
            set label "Laptop Inbuilt Screen (eDP-1 / Monitor 0)"
        case external hdmi hdmi-a-1 1
            set val 1
            set label "External Monitor (HDMI-A-1 / Monitor 1)"
        case status current ""
            if test (hostname) = "void-pc"
                ssh void@100.70.236.70 "cat ~/.config/sunshine/sunshine.conf | grep output_name; echo '--- Detected Monitors in Sunshine ---'; grep -m 2 'Monitor [01]' ~/.config/sunshine/sunshine.log"
            else
                cat ~/.config/sunshine/sunshine.conf | grep output_name
                echo "--- Detected Monitors in Sunshine ---"
                grep -m 2 'Monitor [01]' ~/.config/sunshine/sunshine.log
            end
            return
        case "*"
            echo "Usage: laptopsunshinescreen [external | internal | status]"
            echo "  external -> captures MSI MAG 255F (HDMI-A-1 / output_name = 1)"
            echo "  internal -> captures Inbuilt Screen (eDP-1 / output_name = 0)"
            return 1
    end

    if test (hostname) = "void-pc"
        ssh void@100.70.236.70 "sed -i 's/^output_name = .*/output_name = $val/' ~/.config/sunshine/sunshine.conf && systemctl --user restart sunshine.service"
    else
        sed -i "s/^output_name = .*/output_name = $val/" ~/.config/sunshine/sunshine.conf
        systemctl --user restart sunshine.service
    end
    echo "Sunshine on Laptop switched to: $label"
end
```

#### How to Use It (from PC or Laptop terminal):

* **Switch Sunshine to share the External Monitor:**
  ```bash
  laptopsunshinescreen external
  ```
* **Switch Sunshine to share the Laptop Inbuilt Screen:**
  ```bash
  laptopsunshinescreen internal
  ```
* **Check which display Sunshine is currently targeting:**
  ```bash
  laptopsunshinescreen status
  ```

---

### Method B: Sunshine Web UI (Graphical Configuration)

If you prefer using the browser:
1. Open the Sunshine Web UI on your laptop:
   * **Locally from Laptop:** `https://localhost:47990`
   * **Remotely from Host PC:** `https://100.70.236.70:47990`
2. Navigate to **Configuration** → **Audio/Video**.
3. Scroll to **Display Id / Output Name**:
   * Type **`0`** to capture the **Inbuilt Display (`eDP-1`)**.
   * Type **`1`** to capture the **External MSI Monitor (`HDMI-A-1`)**.
4. Click **Save** at the bottom, then click **Apply** / restart the service.

---

## 9. HDMI & DisplayPort Dummy Plug Best Practices

1. **Inherent Hardware Privacy:** An HDMI or DisplayPort dummy plug is a passive resistor/EEPROM device. It has no screen, emits no light, and cannot be seen. You **never** need to run DDC/CI sleep scripts (`ddcutil`) or privacy commands on a dummy plug.
2. **Avoid Overlapping Virtual Displays:** Never create an experimental virtual output (`niri-virtual msg create-virtual-output`) at `(0, 0)` while a dummy plug is active. This causes Intel `i915` to leak dozens of gigabytes into `shmem`, triggering kernel Out-Of-Memory (OOM) crashes.
3. **Stream Standard Desktop:** Use the standard **Desktop** Sunshine profile directly targeting the dummy plug output (`HDMI-A-2` or `DP-1`).

---

## 10. In-Stream Diagnostics (The Verification Step)

While your stream is running in Moonlight, press:

```text
Ctrl + Alt + Shift + S
```

Verify your live stats:

* **Decoder:** Must display **Hardware** (e.g. `VA-API` or `NVDEC`). If it shows `Software (CPU)`, hardware acceleration is not active.
* **Decode time:** Should stay **under 2.0 ms**.
* **Network latency:** On your local LAN connection, this should read **0.2 – 0.5 ms**.
* **Frame drops / pacing:** Should read **0.0%** dropped frames.
