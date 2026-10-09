#!/usr/bin/env bash
# ==============================================================================
# Complete 1-Click ComfyUI Installer & ROCm 7.2 Optimizer for CachyOS
# Target GPU: AMD Radeon RX 9060 XT (Navi 44 / RDNA 4 / gfx1200, 16GB VRAM)
# Desktop Environment: Niri Wayland Compositor
# ==============================================================================
set -e

INSTALL_DIR="${HOME}/ComfyUI"

echo -e "\033[1;36m====================================================================\033[0m"
echo -e "\033[1;32m 🚀 Starting Automated ComfyUI Fresh Installation on CachyOS \033[0m"
echo -e "\033[1;36m====================================================================\033[0m"

# 1. System Dependencies & ROCm 7.2 Stack
echo -e "\n\033[1;33m[1/7] Installing System ROCm Packages & Build Tools...\033[0m"
sudo pacman -S --needed --noconfirm \
    rocm-hip-runtime \
    hip-runtime-amd \
    rocminfo \
    uv \
    git \
    base-devel \
    python \
    mesa \
    libdrm \
    pciutils

# Ensure user is in video and render groups
sudo usermod -a -G render,video "$USER"

# Ensure amdgpu.ids symlink exists
if [ ! -f /usr/share/libdrm/amdgpu.ids ] && [ -f /usr/share/hwdata/amdgpu.ids ]; then
    sudo mkdir -p /usr/share/libdrm
    sudo ln -sf /usr/share/hwdata/amdgpu.ids /usr/share/libdrm/amdgpu.ids
fi

# 2. Clone ComfyUI Repository
echo -e "\n\033[1;33m[2/7] Setting up ComfyUI Repository in ${INSTALL_DIR}...\033[0m"
if [ ! -d "$INSTALL_DIR" ]; then
    git clone https://github.com/comfyanonymous/ComfyUI.git "$INSTALL_DIR"
else
    echo "Directory $INSTALL_DIR already exists. Updating..."
    git -C "$INSTALL_DIR" pull || true
fi

cd "$INSTALL_DIR"

# 3. Create Python 3.12 Virtual Environment via uv
echo -e "\n\033[1;33m[3/7] Creating Python 3.12 Virtual Environment via uv...\033[0m"
uv venv --python 3.12 venv

# 4. Install PyTorch ROCm 7.2 Wheels & Core Requirements
echo -e "\n\033[1;33m[4/7] Installing PyTorch with ROCm 7.2 Acceleration...\033[0m"
VIRTUAL_ENV="$INSTALL_DIR/venv" uv pip install \
    torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/rocm7.2

echo "Installing ComfyUI base dependencies..."
VIRTUAL_ENV="$INSTALL_DIR/venv" uv pip install -r requirements.txt

# 5. Install Essential Custom Nodes
echo -e "\n\033[1;33m[5/7] Installing Essential Custom Nodes (Manager, GGUF, Impact-Pack, etc.)...\033[0m"
mkdir -p "$INSTALL_DIR/custom_nodes"

# ComfyUI-Manager
if [ ! -d "$INSTALL_DIR/custom_nodes/ComfyUI-Manager" ]; then
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git "$INSTALL_DIR/custom_nodes/ComfyUI-Manager"
fi

# ComfyUI-GGUF (Fast quantized models)
if [ ! -d "$INSTALL_DIR/custom_nodes/ComfyUI-GGUF" ]; then
    git clone https://github.com/city96/ComfyUI-GGUF.git "$INSTALL_DIR/custom_nodes/ComfyUI-GGUF"
    VIRTUAL_ENV="$INSTALL_DIR/venv" uv pip install gguf || true
fi

# ComfyUI-Impact-Pack
if [ ! -d "$INSTALL_DIR/custom_nodes/comfyui-impact-pack" ]; then
    git clone https://github.com/ltdrdata/ComfyUI-Impact-Pack.git "$INSTALL_DIR/custom_nodes/comfyui-impact-pack"
    if [ -f "$INSTALL_DIR/custom_nodes/comfyui-impact-pack/requirements.txt" ]; then
        VIRTUAL_ENV="$INSTALL_DIR/venv" uv pip install -r "$INSTALL_DIR/custom_nodes/comfyui-impact-pack/requirements.txt" || true
    fi
fi

# ComfyUI_LayerStyle (Matting & Layer blending)
if [ ! -d "$INSTALL_DIR/custom_nodes/comfyui_layerstyle" ]; then
    git clone https://github.com/chflame163/ComfyUI_LayerStyle.git "$INSTALL_DIR/custom_nodes/comfyui_layerstyle"
    if [ -f "$INSTALL_DIR/custom_nodes/comfyui_layerstyle/requirements.txt" ]; then
        VIRTUAL_ENV="$INSTALL_DIR/venv" uv pip install -r "$INSTALL_DIR/custom_nodes/comfyui_layerstyle/requirements.txt" || true
    fi
fi

# 6. Install Complete 7-Pillar Niri & ROCm Stability Guard
echo -e "\n\033[1;33m[6/7] Installing Niri & ROCm 7.2 Desktop Stability Guard...\033[0m"
cat << 'GUARD_EOF' > "$INSTALL_DIR/custom_nodes/00_niri_rocm_guard.py"
"""
Niri & AMD ROCm Desktop Stability Guard for ComfyUI
- Prevents Niri Wayland Compositor crashes (amdgpu: -12 / out of memory)
- Prevents Linux System RAM / ZRAM exhaustion & kernel OOM kills
- Fixes GGUF / Flux CPU dequantization freeze
- Fixes dormant model accumulation across workflow switches
- Clamps AMD VAE memory estimator from artificial 2.73x penalty to 1.0x
- Hard VRAM ceiling at 85% to reserve >= 2.5GB permanently for Niri and Mesa
"""
import sys
import gc
import logging
import ctypes
import torch

NODE_CLASS_MAPPINGS = {}
NODE_DISPLAY_NAME_MAPPINGS = {}

# 1. HARD VRAM CEILING FOR PYTORCH (Protects Niri & Mesa from -12 ENOMEM)
try:
    if torch.cuda.is_available():
        torch.cuda.set_per_process_memory_fraction(0.85, 0)
        logging.info("[Niri-Guard] Set PyTorch VRAM limit to 85% (~13.8GB). Niri/Mesa headroom is protected.")
except Exception as e:
    logging.warning(f"[Niri-Guard] Could not set per-process memory fraction: {e}")

# 2. ENFORCE FAST DISK MMAP TO PREVENT 16GB SYSTEM RAM EXHAUSTION
try:
    import comfy.cli_args
    comfy.cli_args.args.fast_disk = True
    logging.info("[Niri-Guard] Enabled fast disk mmap backing (prevents 16GB RAM swap thrashing).")
except Exception as e:
    logging.warning(f"[Niri-Guard] Could not set fast_disk: {e}")

# 3. FIX OVER-INFLATED AMD VAE MEMORY ESTIMATE
try:
    import comfy.sd
    import comfy.model_management

    _orig_vae_init = comfy.sd.VAE.__init__

    def _guarded_vae_init(self, *args, **kwargs):
        _orig_vae_init(self, *args, **kwargs)
        if comfy.model_management.is_amd() and hasattr(self, "memory_used_decode"):
            _old_encode = self.memory_used_encode
            _old_decode = self.memory_used_decode
            self.memory_used_encode = lambda shape, dtype: _old_encode(shape, dtype) / 2.73
            self.memory_used_decode = lambda shape, dtype: _old_decode(shape, dtype) / 2.73

    comfy.sd.VAE.__init__ = _guarded_vae_init
    logging.info("[Niri-Guard] Clamped AMD VAE memory estimator to 1.0x (prevents UNet dump to CPU RAM).")
except Exception as e:
    logging.warning(f"[Niri-Guard] Could not patch VAE memory estimator: {e}")

# 4. ENABLE HARDWARE ATTENTION & UNLOCK FULL VRAM RATIO ON AMD
try:
    import comfy.model_management
    comfy.model_management.ENABLE_PYTORCH_ATTENTION = True
    comfy.model_management.MIN_WEIGHT_MEMORY_RATIO = 0.0
    logging.info("[Niri-Guard] Enabled hardware PyTorch attention & unlocked 100% VRAM allocation ratio for AMD.")
except Exception as e:
    logging.warning(f"[Niri-Guard] Could not configure AMD attention/weight ratios: {e}")

# 5. FIX STRANDED TEXT ENCODER VRAM
try:
    import comfy.model_management

    _orig_model_unload = comfy.model_management.LoadedModel.model_unload

    def _guarded_model_unload(self, memory_to_free=None, unpatch_weights=True):
        is_clip = getattr(self.model, "is_clip", False)
        model_obj = getattr(self.model, "model", None)
        model_name = model_obj.__class__.__name__ if model_obj is not None else ""
        is_text_encoder = is_clip or any(k in model_name.lower() for k in ["clip", "temodel", "textencoder", "t5", "qwen"])

        if is_text_encoder and memory_to_free is not None:
            logging.info(f"[Niri-Guard] Fully unloading inactive text encoder '{model_name}' from VRAM (frees 100% VRAM for KSampler).")
            memory_to_free = None

        return _orig_model_unload(self, memory_to_free=memory_to_free, unpatch_weights=unpatch_weights)

    comfy.model_management.LoadedModel.model_unload = _guarded_model_unload
    logging.info("[Niri-Guard] Installed Text Encoder VRAM unload guard.")
except Exception as e:
    logging.warning(f"[Niri-Guard] Could not patch model_unload: {e}")

# 6. AUTO-EVICT DORMANT MODELS & FORCE FULL GPU LOAD FOR GGUF
try:
    import comfy.model_management

    def is_diffusion_model(patcher):
        m = getattr(patcher, "model", None)
        if m is None:
            return False
        name = m.__class__.__name__.lower()
        is_clip = getattr(patcher, "is_clip", False) or any(k in name for k in ["clip", "temodel", "textencoder", "t5", "qwen"])
        is_vae = any(k in name for k in ["vae", "autoencoder"])
        return not is_clip and not is_vae

    _orig_load_models_gpu = comfy.model_management.load_models_gpu

    def _guarded_load_models_gpu(models, memory_required=0, force_patch_weights=False, minimum_memory_required=None, force_full_load=False):
        incoming_diffusion = [m for m in models if is_diffusion_model(m)]
        if len(incoming_diffusion) > 0:
            incoming = incoming_diffusion[0]
            for i in range(len(comfy.model_management.current_loaded_models) - 1, -1, -1):
                loaded_lm = comfy.model_management.current_loaded_models[i]
                if is_diffusion_model(loaded_lm.model) and loaded_lm.model is not incoming:
                    try:
                        if not incoming.is_clone(loaded_lm.model):
                            model_name = getattr(loaded_lm.model.model, "__class__", type(None)).__name__
                            logging.info(f"[Niri-Guard] Evicting dormant diffusion model '{model_name}' from RAM.")
                            evicted = comfy.model_management.current_loaded_models.pop(i)
                            evicted.model.detach(unpatch_all=True)
                    except Exception:
                        pass

            gc.collect()
            if torch.cuda.is_available():
                torch.cuda.empty_cache()
            try:
                ctypes.CDLL("libc.so.6").malloc_trim(0)
            except Exception:
                pass

        for m in models:
            if "gguf" in m.__class__.__name__.lower() or hasattr(m, "mmap_released"):
                device = getattr(m, "load_device", comfy.model_management.get_torch_device())
                free_vram = comfy.model_management.get_free_memory(device)
                model_sz = m.model_size()
                if model_sz + 1500 * 1024 * 1024 <= free_vram:
                    force_full_load = True
                    logging.info(f"[Niri-Guard] GGUF model fits in VRAM ({model_sz / (1024*1024):.1f}MB <= {free_vram / (1024*1024):.1f}MB). Enforcing 100% full GPU load.")
                break

        return _orig_load_models_gpu(models, memory_required=memory_required, force_patch_weights=force_patch_weights,
                                     minimum_memory_required=minimum_memory_required, force_full_load=force_full_load)

    comfy.model_management.load_models_gpu = _guarded_load_models_gpu
    logging.info("[Niri-Guard] Installed Workflow Model Switch & Swap Thrashing Guard.")
except Exception as e:
    logging.warning(f"[Niri-Guard] Could not patch load_models_gpu: {e}")

# 7. ENHANCE 'UNLOAD MODELS' TO PURGE BOTH GPU AND CPU RAM
try:
    _orig_unload_all_models = comfy.model_management.unload_all_models

    def _guarded_unload_all_models(*args, **kwargs):
        logging.info("[Niri-Guard] 'Unload Models' triggered: Purging all models from VRAM and CPU RAM...")
        try:
            comfy.model_management.free_memory(1e30, None)
        except Exception:
            pass
        while len(comfy.model_management.current_loaded_models) > 0:
            lm = comfy.model_management.current_loaded_models.pop()
            try:
                lm.model.detach(unpatch_all=True)
            except Exception:
                pass
        gc.collect()
        if torch.cuda.is_available():
            torch.cuda.empty_cache()
            torch.cuda.ipc_collect()
        try:
            ctypes.CDLL("libc.so.6").malloc_trim(0)
        except Exception:
            pass
        free_vram = comfy.model_management.get_free_memory(comfy.model_management.get_torch_device()) / (1024 * 1024)
        logging.info(f"[Niri-Guard] Complete purge finished! Free VRAM: {free_vram:.2f} MB")

    comfy.model_management.unload_all_models = _guarded_unload_all_models
    logging.info("[Niri-Guard] Enhanced 'Unload Models' with complete VRAM & CPU RAM purge.")
except Exception as e:
    logging.warning(f"[Niri-Guard] Could not patch unload_all_models: {e}")
GUARD_EOF

# 7. Create start.sh & Desktop Shortcuts
echo -e "\n\033[1;33m[7/7] Generating start.sh, desktop shortcuts, and terminal wrappers...\033[0m"
cat << 'START_EOF' > "$INSTALL_DIR/start.sh"
#!/usr/bin/env bash
if [ ! -t 0 ] || [ ! -t 1 ]; then
    if command -v ghostty >/dev/null 2>&1; then
        exec ghostty --title="ComfyUI Server" -e bash "$0" "$@"
    elif command -v alacritty >/dev/null 2>&1; then
        exec alacritty --title "ComfyUI Server" -e bash "$0" "$@"
    elif command -v konsole >/dev/null 2>&1; then
        exec konsole --title "ComfyUI Server" -e bash "$0" "$@"
    fi
fi

cd "$(dirname "$0")"
source venv/bin/activate

# --- AMD RDNA 4 & ROCm 7.2 Optimizations ---
export HSA_ENABLE_SDMA=0
export TORCH_BLAS_PREFER_HIPBLASLT=1
export TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL=1
export MIOPEN_FIND_MODE=FAST
export PYTORCH_ALLOC_CONF=garbage_collection_threshold:0.8,max_split_size_mb:512
export PYTORCH_CUDA_ALLOC_CONF=garbage_collection_threshold:0.8,max_split_size_mb:512

TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || true)
LOCAL_IP=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{print $7}')

echo -e "\033[1;36m====================================================================\033[0m"
echo -e "\033[1;32m 🚀 ComfyUI Starting with ROCm Acceleration (Live Monitor) \033[0m"
echo -e "\033[1;37m 💻 Local Web UI:      \033[1;34mhttp://127.0.0.1:8188\033[0m"
if [ -n "$TAILSCALE_IP" ]; then
    echo -e "\033[1;33m 📱 Tablet Access:      \033[1;32mhttp://${TAILSCALE_IP}:8188\033[0m (via Tailscale)"
else
    echo -e "\033[1;31m ⚠️  Tailscale not detected. Remote access: http://${LOCAL_IP:-localhost}:8188\033[0m"
fi
echo -e "\033[1;36m====================================================================\033[0m"
echo

python main.py --listen 0.0.0.0 --port 8188 \
    --fast-disk \
    --disable-pinned-memory \
    --reserve-vram 2.0 \
    --use-pytorch-cross-attention \
    --enable-manager \
    --auto-launch "$@"

EXIT_STATUS=$?
echo
echo -e "\033[1;33mComfyUI process ended (exit code: $EXIT_STATUS).\033[0m"
echo "Press Enter to close this terminal window..."
read -r
START_EOF
chmod +x "$INSTALL_DIR/start.sh"

cat << 'LAUNCH_EOF' > "$INSTALL_DIR/launch_desktop.sh"
#!/usr/bin/env bash
if command -v ghostty >/dev/null 2>&1; then
    exec ghostty --title="ComfyUI Server" -e "${HOME}/ComfyUI/start.sh" "$@"
elif command -v alacritty >/dev/null 2>&1; then
    exec alacritty --title "ComfyUI Server" -e "${HOME}/ComfyUI/start.sh" "$@"
else
    exec "${HOME}/ComfyUI/start.sh" "$@"
fi
LAUNCH_EOF
chmod +x "$INSTALL_DIR/launch_desktop.sh"

# Create Desktop .desktop launcher
mkdir -p "${HOME}/.local/share/applications" "${HOME}/Desktop"
cat << DESKTOP_EOF > "${HOME}/.local/share/applications/comfyui.desktop"
[Desktop Entry]
Name=ComfyUI
Comment=ComfyUI with AMD ROCm 7.2 Acceleration
Exec=${HOME}/ComfyUI/launch_desktop.sh
Icon=comfyui
Terminal=false
Type=Application
Categories=Graphics;Development;
StartupNotify=true
DESKTOP_EOF

cp "${HOME}/.local/share/applications/comfyui.desktop" "${HOME}/Desktop/comfyui.desktop" 2>/dev/null || true
chmod +x "${HOME}/Desktop/comfyui.desktop" 2>/dev/null || true

echo -e "\n\033[1;32m====================================================================\033[0m"
echo -e "\033[1;32m 🎉 ComfyUI Installation & ROCm Optimization Completed! \033[0m"
echo -e "\033[1;37m Launch ComfyUI anytime with:  \033[1;34m~/ComfyUI/start.sh\033[0m"
echo -e "\033[1;32m====================================================================\033[0m"
