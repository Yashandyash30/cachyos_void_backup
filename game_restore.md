# Game Restoration & Lutris Setup Guide

This guide details the complete configuration for running games installed on secondary drives (`/home/void/Folder_D/Games`) with Lutris on CachyOS, restoring their respective save files and configurations from backup (`Pre_Format_PC_Backup/01_Game_Saves`), and setting up Wine prefixes.

---

## 1. Overview of Configured Games

| Game | Executable Path | Wine Prefix | Save Target Type |
| :--- | :--- | :--- | :--- |
| **Crimson Desert** | `/home/void/Folder_D/Games/Crimson_Desert/Crimson Desert/bin64/CrimsonDesert.exe` | `/home/void/Games/crimson-desert` | `%LOCALAPPDATA%` + `%APPDATA%` |
| **The Last of Us Part I** | `/home/void/Folder_D/Games/The_last_of_us_1/The Last of Us Part I/tlou-i.exe` | `/home/void/Games/the-last-of-us-part-i` | `%USERPROFILE%\Saved Games` |

---

## 2. Lutris Runner Setup (CachyOS Wine)

CachyOS provides an optimized Wine build located in `/opt/wine-cachyos`. To make it accessible as a native runner in Lutris:

```bash
mkdir -p ~/.local/share/lutris/runners/wine
ln -sf /opt/wine-cachyos ~/.local/share/lutris/runners/wine/wine-cachyos
```

Available runners inside Lutris:
* `wine-cachyos` (Tuned system Wine with NTSYNC / Fsync)
* `proton-cachyos-slr` (Steam Linux Runtime build from `/usr/share/steam/compatibilitytools.d/`)
* `ge-proton`

---

## 3. Game 1: Crimson Desert (AnkerGames)

### Wine Prefix Initialization
```bash
mkdir -p /home/void/Games/crimson-desert
WINEPREFIX=/home/void/Games/crimson-desert WINEDLLOVERRIDES="mscoree,mshtml=" /opt/wine-cachyos/bin/wineboot -u
```

### Dependency Installation (VC++ 2015–2022)
```bash
WINEPREFIX=/home/void/Games/crimson-desert /opt/wine-cachyos/bin/wine \
  "/home/void/Folder_D/Games/Crimson_Desert/Crimson Desert/_CommonRedist/vcredist/2022/VC_redist.x64.exe" /install /quiet /norestart
```

### Save Files & Configuration Restoration
Restored from `Pre_Format_PC_Backup/01_Game_Saves/Crimson_Desert/`:

```bash
# 1. Config & Input settings -> %LOCALAPPDATA%\Pearl Abyss\CD\save\
mkdir -p "/home/void/Games/crimson-desert/drive_c/users/void/AppData/Local/Pearl Abyss/CD/save/19627"
cp -r /home/void/cachyos_void_backup/Pre_Format_PC_Backup/01_Game_Saves/Crimson_Desert/Config_And_Inputs/* \
  "/home/void/Games/crimson-desert/drive_c/users/void/AppData/Local/Pearl Abyss/CD/save/"

# 2. Save Slots -> %LOCALAPPDATA%\Pearl Abyss\CD\save\19627\
cp -r /home/void/cachyos_void_backup/Pre_Format_PC_Backup/01_Game_Saves/Crimson_Desert/Save_Slots/* \
  "/home/void/Games/crimson-desert/drive_c/users/void/AppData/Local/Pearl Abyss/CD/save/19627/"

# 3. GSE Achievements (Optional) -> %APPDATA%\GSE Saves\3321460\
mkdir -p "/home/void/Games/crimson-desert/drive_c/users/void/AppData/Roaming/GSE Saves/3321460"
cp -r /home/void/cachyos_void_backup/Pre_Format_PC_Backup/01_Game_Saves/Crimson_Desert/GSE_Achievements/* \
  "/home/void/Games/crimson-desert/drive_c/users/void/AppData/Roaming/GSE Saves/3321460/"
```

### Lutris Configuration (`~/.local/share/lutris/games/crimson-desert.yml`)
```yaml
game:
  exe: /home/void/Folder_D/Games/Crimson_Desert/Crimson Desert/bin64/CrimsonDesert.exe
  prefix: /home/void/Games/crimson-desert
  working_dir: /home/void/Folder_D/Games/Crimson_Desert/Crimson Desert/bin64
wine:
  version: wine-cachyos
```

---

## 4. Game 2: The Last of Us Part I

### Wine Prefix Initialization
```bash
mkdir -p /home/void/Games/the-last-of-us-part-i
WINEPREFIX=/home/void/Games/the-last-of-us-part-i WINEDLLOVERRIDES="mscoree,mshtml=" /opt/wine-cachyos/bin/wineboot -u
```

### Dependency Installation (VC++ 2015–2022)
```bash
WINEPREFIX=/home/void/Games/the-last-of-us-part-i /opt/wine-cachyos/bin/wine \
  "/home/void/Folder_D/Games/Crimson_Desert/Crimson Desert/_CommonRedist/vcredist/2022/VC_redist.x64.exe" /install /quiet /norestart
```

### Save Files & Configuration Restoration
Restored from `Pre_Format_PC_Backup/01_Game_Saves/The_Last_of_Us_Part_I/`:

```bash
# Save data & profile -> %USERPROFILE%\Saved Games\The Last of Us Part I\
mkdir -p "/home/void/Games/the-last-of-us-part-i/drive_c/users/void/Saved Games/The Last of Us Part I"
cp -r /home/void/cachyos_void_backup/Pre_Format_PC_Backup/01_Game_Saves/The_Last_of_Us_Part_I/* \
  "/home/void/Games/the-last-of-us-part-i/drive_c/users/void/Saved Games/The Last of Us Part I/"
```

* Restores `users/6144/savedata` (slots `SAVEFILE00`, `SAVEFILE0A`, `SAVEFILE0P`), `gamedata`, and `log.txt`.

### Lutris Configuration (`~/.local/share/lutris/games/the-last-of-us-part-i.yml`)
```yaml
game:
  exe: /home/void/Folder_D/Games/The_last_of_us_1/The Last of Us Part I/tlou-i.exe
  prefix: /home/void/Games/the-last-of-us-part-i
  working_dir: /home/void/Folder_D/Games/The_last_of_us_1/The Last of Us Part I
wine:
  version: wine-cachyos
```

---

## 5. Registering Games in Lutris Database (`pga.db`)

Lutris stores registered games in `~/.local/share/lutris/pga.db`. Games were programmatically added via Python:

```python
import gi
gi.require_version('Gtk', '3.0')
gi.require_version('Gdk', '3.0')
from lutris.database import games

# Crimson Desert
games.add_or_update(
    name='Crimson Desert',
    slug='crimson-desert',
    runner='wine',
    platform='Windows',
    directory='/home/void/Folder_D/Games/Crimson_Desert/Crimson Desert/bin64',
    installed=1,
    configpath='crimson-desert'
)

# The Last of Us Part I
games.add_or_update(
    name='The Last of Us Part I',
    slug='the-last-of-us-part-i',
    runner='wine',
    platform='Windows',
    directory='/home/void/Folder_D/Games/The_last_of_us_1/The Last of Us Part I',
    installed=1,
    configpath='the-last-of-us-part-i'
)
```

To verify games registered in Lutris:
```bash
lutris --list-games
```

---

## 6. How to Add Future Games Manually via Lutris GUI

For any new game downloaded in the future:

1. **Launch Lutris**:
   * Click the **`+`** (plus) icon in the top-left banner.
   * Select **"Add locally installed game"**.

2. **Game Info Tab**:
   * **Name**: Enter the game name (e.g. `God of War Ragnarök`).
   * **Runner**: Select **Wine (Runs Windows games)**.

3. **Game Options Tab**:
   * **Executable**: Browse to the game executable (e.g. `GOW.exe`).
   * **Working directory**: Set to the game folder containing the `.exe`.
   * **Wine prefix**: Specify a clean dedicated directory (e.g. `/home/void/Games/<game-slug>`).

4. **Runner Options Tab**:
   * **Wine version**: Choose `wine-cachyos` (or `proton-cachyos-slr`).
   * Verify **Enable DXVK**, **Enable VKD3D**, and **Enable Fsync** are turned on.

5. **Save and Launch Once**:
   * Save the configuration and click **Play** once.
   * This generates the Windows file system tree inside `<prefix>/drive_c/users/void/`.

6. **Restore Saves**:
   * Follow the path reference in `Pre_Format_PC_Backup/01_Game_Saves/RESTORE_GAME_SAVES.md`:
     * `%USERPROFILE%` &rarr; `<prefix>/drive_c/users/void/`
     * `%LOCALAPPDATA%` &rarr; `<prefix>/drive_c/users/void/AppData/Local/`
     * `%APPDATA%` &rarr; `<prefix>/drive_c/users/void/AppData/Roaming/`
     * `Documents` &rarr; `<prefix>/drive_c/users/void/Documents/` (or `~/Documents`)