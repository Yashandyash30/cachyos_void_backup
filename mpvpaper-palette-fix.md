# MpvPaper Plugin — Wallpaper Palette Fix

## What was the issue?

When using the mpvpaper DMS plugin for live (video) wallpapers, the system theme colors (Material You palette) don't update to match the video. DMS keeps using the old static wallpaper's colors because the plugin never tells DMS about the wallpaper change.

## How DMS generates theme colors

```
SessionData.wallpaperPath → Theme.rawWallpaperPath → matugen → system colors
                                                                 (GTK, Qt, niri, terminals, etc.)
```

The mpvpaper plugin was only managing its own `pluginData.monitorVideos` — it never called `SessionData.setWallpaper()`, so `matugen` kept extracting colors from the old static image.

## The fix

Modified `MpvPaperDaemon.qml` to:

1. **Extract a still frame** from the video at the 2-second mark using `ffmpeg`
2. **Save it** to `~/.cache/DankMaterialShell/mpvpaper_stills/`
3. **Call `SessionData.setWallpaper(stillPath)`** which triggers the full matugen pipeline

### Changes made (3 locations in MpvPaperDaemon.qml)

#### 1. New properties (after line ~62)
```qml
// --- Wallpaper palette update ---
readonly property string stillFrameCacheDir: StandardPaths.writableLocation(StandardPaths.GenericCacheLocation).toString().replace("file://", "") + "/DankMaterialShell/mpvpaper_stills"
property string lastPaletteVideoPath: ""
```

#### 2. Trigger palette update when video starts (in launchDelayComponent.onTriggered)
```qml
// Extract a still frame and update the DMS wallpaper palette
root.updateWallpaperPalette(monitor, videoPath)
```

#### 3. New function + Component (before Component.onCompleted)
```qml
function updateWallpaperPalette(monitor, videoPath) {
    // Only updates for the matugen target monitor
    // Skips if same video is already active
    // Extracts frame with ffmpeg, calls SessionData.setWallpaper()
}

Component {
    id: stillFrameExtractorComponent
    // ffmpeg process to extract still frame
    // On success: SessionData.setWallpaper(outputPath)
}
```

## Bonus: "Same on all monitors" Toggle

Added a new feature across the plugin files (`MpvPaperWidget.qml`, `MpvPaperSettings.qml`, `MpvPaperDaemon.qml`) that adds a toggle button. When enabled:
- The monitor selector dropdown is hidden/disabled
- Any video selected or added to the playlist applies to **all connected monitors** simultaneously
- The daemon sync function `syncVideosWithData` duplicates the primary monitor's configuration across all other monitors automatically

## Current status

- **Fork:** https://github.com/Yashandyash30/mpvpaper-plugin
- **PR:** Submitted to https://github.com/tokisak1kurum1/mpvpaper-plugin
- **Plugin remote** currently points to my fork (safe from upstream updates)

## When PR gets merged

Either:
```bash
# Option A: Switch remote back
cd ~/.config/DankMaterialShell/plugins/mpvpaper
git remote set-url origin https://github.com/tokisak1kurum1/mpvpaper-plugin.git

# Option B: Simply reinstall from store
dms plugins uninstall mpvpaper
dms plugins install mpvpaper
```

## Note

These code changes were generated with the help of an AI coding assistant (Antigravity / Claude). I identified the issue and verified the fix.
