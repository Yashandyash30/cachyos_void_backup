# ComfyUI Tablet & Tailscale Optimizations

Summary of tweaks applied to optimize ComfyUI and Pixaroma nodes for tablet access (Samsung Galaxy Tab S9, IceRaven/Chrome, over Tailscale).

---

## 1. Workflow Restructuring (Zero-Pan Dashboard)

**File created:**  
`/home/void/ComfyUI/user/default/workflows/SDXL_Inpaint_stich_LCM_tablet.json`

### Problem
- Original canvas spanned >4,300px horizontally across 6 groups.
- Required constant zooming in/out and two-finger panning on touchscreens between input images, prompts, and previews.
- 8 redundant preview nodes were pushing high-resolution image payloads across Wi-Fi on every queue.

### Changes Made
- **Dashboard Layout (1600×900 Viewport):**
  - **Column 1 (`1. INPUT & MASK CROP`):** `LoadImage` (#7) and `PixaromaInpaintCrop` (#8) placed side-by-side.
  - **Column 2 (`2. PROMPTS & CONTROLS`):** Positive prompt (#6), Negative prompt (#5), `PixaromaSeed` (#16), and `KSampler` (#11) stacked vertically.
  - **Column 3 (`3. COMPARE & PREVIEW`):** Interactive `PixaromaCompare` (#59) slider and final `PreviewImage` (#58).
  - Default zoom preset (`scale: 0.72`) fits the whole interactive dashboard on tablet screen without panning.
- **Collapsed Pipeline:**
  - 15 background processing nodes (`CheckpointLoaderSimple`, `DifferentialDiffusion`, `VAEEncode`, `VAEDecode`, `EveryPersonSegDetail`, `MasksToMaskList`, `ColorMatchV2`, `ImageCompositeMasked`, etc.) collapsed into 40px headers in group `⚙️ BACKGROUND PIPELINE (Auto Process)`.
- **Bandwidth Reduction:**
  - Removed 6 redundant nodes (duplicate mask previews #12, #60, #62; duplicate image previews #18, #19; duplicate compare #17).

---

## 2. Browser Fullscreen & PWA Setup

**File edited:**  
`/home/void/ComfyUI/venv/lib/python3.12/site-packages/comfyui_frontend_package/static/index.html`

### Problem
- Tapping "Add to Home Screen" opened ComfyUI inside the standard browser with the URL bar, navigation bar, and tab strip taking up vertical screen real estate.
- Safari on iPad requires Apple PWA meta tags which were missing.
- Android browsers (Chrome, IceRaven) require HTTPS or localhost for PWA WebAPK installation.

### Changes Made
- **Apple PWA Meta Tags:**
  Injected into `<head>`:
  ```html
  <meta name="apple-mobile-web-app-capable" content="yes"/>
  <meta name="apple-mobile-web-app-title" content="ComfyUI"/>
  <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent"/>
  ```
- **Android / Tailscale Workaround:**
  - **For Chrome / Brave:** Enable `chrome://flags/#unsafely-treat-insecure-origin-as-secure`, add `http://100.106.197.11:8188`, toggle **Enabled**, relaunch. Tap 3-dots $\rightarrow$ **Install app**.
  - **For Tailscale HTTPS (IceRaven / Firefox):** Run `tailscale serve --bg 8188` (after enabling Serve in Tailscale Admin) to get trusted `https://void-rig-cachyos.tail511a34.ts.net`.

---

## 3. Touch Gesture & Page Zoom Fix

**Files modified / created:**
1. `/home/void/ComfyUI/venv/lib/python3.12/site-packages/comfyui_frontend_package/static/index.html`
2. `/home/void/ComfyUI/user/default/user.css`

### Problem
- Two-finger pinch gestures were intercepted by the browser as whole-page viewport zoom, blowing up sidebars, menus, and text instead of zooming the LiteGraph canvas.

### Changes Made
- **Injected iOS Safari Gesture Trap (`index.html`):**
  ```html
  <script>
    document.addEventListener("gesturestart", function(e){ e.preventDefault(); }, { passive: false });
    document.addEventListener("gesturechange", function(e){ e.preventDefault(); }, { passive: false });
    document.addEventListener("gestureend", function(e){ e.preventDefault(); }, { passive: false });
  </script>
  ```
- **Touch CSS (`user.css`):**
  Auto-loaded by ComfyUI on startup:
  ```css
  html, body {
    touch-action: none;
    overscroll-behavior: none;
    -webkit-user-select: none;
    user-select: none;
  }

  .side-tool-bar,
  .comfy-menu,
  .p-sidebar,
  .p-dialog,
  .p-drawer,
  .comfy-modal,
  .comfy-vue-side-bar,
  [role="dialog"] {
    touch-action: pan-y !important;
    overscroll-behavior: contain !important;
  }

  input, textarea {
    user-select: text !important;
    -webkit-user-select: text !important;
  }

  #graph-canvas, canvas {
    touch-action: none !important;
  }
  ```

---

## 4. Pixaroma Mask Editor Multi-Touch Pinch-Zoom & Pan Fix

**Files modified:**
1. `/home/void/ComfyUI/custom_nodes/ComfyUI-Pixaroma/js/inpaint_crop/paint.mjs` (Inpaint Crop Mask Editor)
2. `/home/void/ComfyUI/custom_nodes/ComfyUI-Pixaroma/js/paint/events.mjs` (Paint Studio)

*(Original files backed up to `paint.mjs.bak` and `events.mjs.bak`)*

### Problem
- The Pixaroma mask editor only listened to mouse `wheel` for zoom and `Space+click` / `middle-click` for pan.
- Pointer events treated every touch (`button: 0`) as a brush stroke, so attempting to pinch-zoom or two-finger pan immediately drew accidental mask lines.

### Changes Made
- **Multi-Touch Pointer Tracking:**
  Implemented active touch map (`activeTouches = new Map()`).
- **Stroke Auto-Revert on Pinch:**
  When a 2nd touch pointer is detected while painting, `_abandonStroke()` and `_mctx.putImageData(undo)` are triggered instantly to erase the accidental dab from the first finger.
- **Pinch-To-Zoom & Pan:**
  - Calculates dynamic finger distance $\rightarrow$ calls Pixaroma's native `_applyZoom(factor, anchorX, anchorY)`.
  - Calculates midpoint movement delta $\rightarrow$ shifts `_panX` and `_panY` with finger drag.
- **Release Grace Period (400ms):**
  Prevents the trailing finger from drawing a stray line when fingers are lifted from the screen.
- **S-Pen / Stylus Support:**
  Preserved single-pointer/pen tip drawing with zero latency.

---

## 5. Virtual Keyboard Auto-Popup Fix in Pixaroma

**File modified:**
`/home/void/ComfyUI/custom_nodes/ComfyUI-Pixaroma/js/shared/utils.mjs`

*(Original backed up to `utils.mjs.bak`)*

### Problem
- On tablets (Android/iPad), the on-screen keyboard popped up continuously whenever touching the canvas, dragging sliders, or tapping buttons inside any Pixaroma editor (`InpaintCrop`, `Paint`, `Composer`).

### Root Cause
- Pixaroma had an `installFocusTrap(overlay)` function designed for desktop hotkeys.
- It created an invisible `<textarea>` (`trap`), focused it on mount (`trap.focus()`), and registered a `mouseup` listener on the overlay that called `requestAnimationFrame(() => trap.focus())` on **every single tap or stroke completion**.
- On mobile/tablet OSes, focusing an editable `<textarea>` immediately instructs the Android/iOS software keyboard to open.

### Changes Made
- Added touch-device detection (`navigator.maxTouchPoints > 0 || pointer: coarse`).
- Added `inputmode="none"`, `readOnly = true`, and `tabIndex = -1` to the trap element to permanently prevent mobile OS keyboard invocation.
- On touch devices, suppressed both the initial `trap.focus()` call and the `overlay.addEventListener("mouseup", refocus)` loop. Desktop keyboard hotkey capture remains untouched.

---

## 6. Global ComfyUI Tablet Keyboard & Touch Optimization

**Files modified:**
1. `/home/void/ComfyUI/venv/lib/python3.12/site-packages/comfyui_frontend_package/static/index.html` (Global tablet helper runtime)
2. `/home/void/ComfyUI/user/default/user.css` (Universal touch styling & input zoom prevention)

### Problem
- Tapping or dragging nodes on the main canvas while an input was previously active left the virtual keyboard open on screen.
- Dialogs, search popups, and modal windows with `autofocus` immediately summoned the mobile keyboard even when the user just wanted to browse or select items.
- Touching small inputs (< 16px font size) triggered mobile browsers (Safari / Chrome / IceRaven) to forcefully zoom in on the input field, disorienting canvas navigation.
- Long-pressing or dragging nodes accidentally caused blue highlight rectangles and text selection bubbles on node titles.

### Changes Made
- **Canvas Auto-Blur:**
  Injected global pointer listener in `index.html`:
  When tapping or touching the canvas or background elements with touch input, if an input field is active, it calls `document.activeElement.blur()`, immediately dismissing the virtual keyboard.
- **Autofocus Neutralizer for Touch Screens:**
  Intercepts programmatic `.focus()` calls on `autofocus` inputs on touch devices, temporarily setting `inputmode="none"` and `readOnly=true` so opening dialogs/menus does not cover the screen with the keyboard. As soon as the user deliberately taps the input with their finger, standard keyboard input is enabled.
- **Input Auto-Zoom Prevention (CSS):**
  Added `font-size: 16px !important;` for all `input`, `textarea`, `select`, and `.litegraph-dialog` inputs in `user.css`. Prevents iOS Safari and Android Chrome from zooming the viewport on input focus.
- **Touch Selection Isolation:**
  Added `-webkit-tap-highlight-color: transparent`, `-webkit-touch-callout: none`, and `user-select: none` to canvas and `.lgraph-node` to stop text selection handles when dragging nodes.
