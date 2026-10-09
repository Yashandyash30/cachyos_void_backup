Here is the complete reference guide covering how to enable autologin with your Niri setup, and exactly how to reverse the entire process back to a standard password prompt.

### Part 1: Setting Up Autologin

To bypass the SDDM login screen and boot straight into your desktop, you need to create an override file.

1. Open your terminal and create the directory and file:
```bash
sudo mkdir -p /etc/sddm.conf.d/
sudo nano /etc/sddm.conf.d/autologin.conf

```


2. Paste the following configuration to target your account:
```ini
[Autologin]
User=void
Session=niri

```


3. Save and exit (in Nano: `Ctrl+O`, `Enter`, `Ctrl+X`).

---

### Part 2: Niri Configuration (With Auto-Lock)

When autologin is enabled, your system is vulnerable upon boot. You must use this configuration in your `~/.config/niri/config.kdl` to sync your display variables and instantly lock the screen with `dms`.

Replace your `spawn-at-startup` section with this:

```kdl
// 1. CRITICAL: Sync environment variables to D-Bus (Fixes the 90-second gray screen)
spawn-at-startup "dbus-update-activation-environment" "--systemd" "WAYLAND_DISPLAY" "XDG_CURRENT_DESKTOP=niri"

// 2. Start authentication agent
spawn-at-startup "/usr/lib/polkit-kde-authentication-agent-1"

// 3. SECURE BOOT: Lock the screen after autologin
spawn-at-startup "sh" "-c" "sleep 2 && dms"

// 4. Rebuild the app cache
spawn-at-startup "kbuildsycoca6" "--noincremental"

// 5. Start the search engine
spawn-at-startup "elephant"

// 6. Start the UI listener natively on Vulkan
spawn-at-startup "walker" "--gapplication-service"

// 7. KDE Connect
spawn-at-startup "/usr/lib/kdeconnectd"
spawn-at-startup "kdeconnect-indicator"

```

---

### Part 3: Switching Back to Password Login (Reverting)

If you want to disable autologin and go back to typing your password at the SDDM greeter screen, you simply need to delete the override file.

1. Run this command in your terminal:
```bash
sudo rm /etc/sddm.conf.d/autologin.conf

```



The next time you boot, SDDM will stop and ask for your password normally.

---

### Part 4: Disabling the "Double Lock" After Reverting

Once you are using a password at the SDDM screen again, you do not want `dms` locking your screen a second time immediately after you log in.

**1. Comment out the lock line in your Niri config:**
Open `~/.config/niri/config.kdl` and add `//` to the beginning of the `dms` startup line to disable it:

```kdl
// SECURE BOOT: Disabled because SDDM now handles the password login
// spawn-at-startup "sh" "-c" "sleep 2 && dms"

```

**2. Turn off Auto-Lock in DMS Settings:**
If DankMaterialShell is still locking your screen automatically after a period of inactivity, you need to turn off its internal idle timer.

1. Open the **DankMaterialShell Settings** menu from your desktop or launcher.
2. Navigate to the **Lock Screen** or **Power/Idle** section.
3. Toggle **Off** the setting that says "Automatically lock screen after [X] minutes" (or similar wording depending on your DMS version).
4. Save or apply the settings.
