# ComfyUI Model Combos, Workflows & LoRA Guide
**Target System:** AMD Radeon RX 9060 XT (16GB VRAM, RDNA 4 / ROCm 7.2) + 32GB Dual-Channel RAM

---

## 📑 Table of Contents
1. [Core Architecture Workflows](#1-core-architecture-workflows)
   - [SDXL (e.g., RealVisXL, SDXL Base)](#1-sdxl-eg-realvisxl-sdxl-base)
   - [Krea 2 (Turbo & Raw)](#2-krea-2-turbo--raw)
   - [FLUX.2 Klein (4B & 9B Distilled / Base)](#3-flux2-klein-4b--9b-distilled--base)
   - [Z-Image / Z-Image Turbo](#4-z-image--z-image-turbo)
   - [FLUX.1 Dev](#5-flux1-dev)
   - [FLUX.1 Fill (Inpainting / Outpainting)](#6-flux1-fill-inpainting--outpainting)
   - [FLUX.1 Schnell (4-Step Turbo)](#7-flux1-schnell-4-step-turbo)
2. [Master Reference Matrix](#2-master-reference-matrix)
3. [Complete Guide to LoRA (Low-Rank Adaptation)](#3-complete-guide-to-lora-low-rank-adaptation)
   - [Can I use multiple LoRAs at once?](#can-i-use-multiple-loras-at-once)
   - [How to chain multiple LoRAs (Node Wiring)](#how-to-chain-multiple-loras-node-wiring)
   - [LoRA usage per architecture](#lora-usage-per-architecture)
   - [Golden rules & troubleshooting for LoRAs](#golden-rules--troubleshooting-for-loras)

---

## 1. Core Architecture Workflows

### 1. SDXL (e.g., RealVisXL, SDXL Base)
Standard 4-channel latent space, dual CLIP (L + G), high CFG.

```
[CheckpointLoaderSimple] ──MODEL──> [KSampler] ──LATENT──> [VAEDecode] ──IMAGE──> [SaveImage]
   (or UNETLoader)       ──CLIP───> [CLIPTextEncode] ──CONDITIONING──┘
                         ──VAE────> [VAEDecode]
```

* **Model Loader:**
  * **Option A (All-in-one):** `CheckpointLoaderSimple` $\rightarrow$ `RealVisXL_V5.0_fp16.safetensors` (in `models/checkpoints/`).
  * **Option B (Modular):** `UNETLoader` $\rightarrow$ `sdxl_base.safetensors` (in `models/unet/`).
* **Text Encoder Loader:**
  * If using Checkpoint: Built-in.
  * If Modular: `DualCLIPLoader` $\rightarrow$ `clip_l.safetensors` + `clip_g.safetensors` (Type: `sdxl`).
* **VAE Loader:**
  * Built-in checkpoint VAE, or `VAELoader` $\rightarrow$ `sdxl_vae.safetensors` (in `models/vae/`).
* **Latent Node:** `EmptyLatentImage` (Standard 4-channel, $1024 \times 1024$).
* **KSampler Settings:**
  * **Steps:** `25 – 35` (or `4 – 8` if using LCM / Lightning LoRA).
  * **CFG:** `6.0 – 7.5` (or `1.0 – 1.8` for Turbo/Lightning).
  * **Sampler:** `dpmpp_2m` or `euler_ancestral`.
  * **Scheduler:** `karras`.
  * **Denoise:** `1.0`.

---

### 2. Krea 2 (Turbo & Raw)
Distilled transformer text-to-image with Qwen3-VL 4B text encoding.

```
[UNETLoader] ───────MODEL───> [KSampler] ───────LATENT──> [VAEDecode] ──> [SaveImage]
[CLIPLoader (krea2)] ─CLIP───> [CLIPTextEncode] ──POS─────┘      ▲
                            └─> [ConditioningZeroOut] ──NEG──┘      │
[VAELoader] ─────────VAE──────────────────────────────────────────┘
[EmptyLatentImage] ─LATENT────────────────────────────────────────┘
```

* **Model Loader:** `UNETLoader` $\rightarrow$ `krea2_turbo_fp8_scaled.safetensors` (in `models/diffusion_models/`).
* **Text Encoder Loader:** `CLIPLoader` $\rightarrow$ `qwen3vl_4b_fp8_scaled.safetensors` (in `models/text_encoders/`).
  * **Crucial Setting:** Set dropdown `type:` to **`krea2`**.
* **VAE Loader:** `VAELoader` $\rightarrow$ `qwen_image_vae.safetensors` (in `models/vae/`).
* **Latent Node:** `EmptyLatentImage` ($1024 \times 1024$, batch 1).
* **Conditioning:**
  * Positive: `CLIPTextEncode` with prompt.
  * Negative: Route positive conditioning into `ConditioningZeroOut` $\rightarrow$ connect to KSampler `negative`.
* **KSampler Settings:**
  * **Steps:** `6 – 8` (Turbo is distilled).
  * **CFG:** **`1.0`** (Do NOT use CFG > 1.0 on Krea 2 Turbo).
  * **Sampler:** `euler`.
  * **Scheduler:** `simple` (or `sgm_uniform`).

---

### 2B. Qwen-Image 2.1 Turbo
Alibaba Qwen-Image 2.1 DiT architecture with rotary convolutions (`convrot`), Qwen 3.5 9B prompt-enhanced text encoder, and native Wan 2.1 16-channel VAE. Extreme 4-step generation speed.

```
[UNETLoader (qwen_image_2.1_turbo)] ──MODEL──> [KSampler (4 steps, CFG 1.0)] ──> [VAEDecode]
[CLIPLoader (type: qwen_image)] ──────CLIP───> [CLIPTextEncode] ──POS────────────┘   ▲
                                             └─> [ConditioningZeroOut] ──NEG─────┘   │
[VAELoader (qwen_image_2.1_vae_bf16)] ─VAE───────────────────────────────────────────┘
[EmptyLatentImage (1024x1024)] ────────LATENT────────────────────────────────────────┘
```

* **Model Loader:** `UNETLoader` $\rightarrow$ `qwen_image_2.1_turbo_int8_convrot.safetensors` (in `models/diffusion_models/`).
* **Text Encoder Loader:** `CLIPLoader` $\rightarrow$ `qwen3.5_9b_qwen_image_2.1_pe_t2i.int8_convrot.safetensors` (in `models/text_encoders/`).
  * **Crucial Setting:** Set dropdown `type:` to **`qwen_image`**.
* **VAE Loader:** `VAELoader` $\rightarrow$ `qwen_image_2.1_vae_bf16.safetensors` (or `qwen_image_vae.safetensors` in `models/vae/`).
* **Latent Node:** `EmptyLatentImage` ($1024 \times 1024$, batch 1).
* **Conditioning:**
  * Positive: `CLIPTextEncode` with prompt.
  * Negative: `ConditioningZeroOut` (or empty string CLIP encode).
* **KSampler Settings:**
  * **Steps:** `4` (Turbo distillation).
  * **CFG:** **`1.0`**.
  * **Sampler:** `euler`.
  * **Scheduler:** `simple`.

---

### 3. FLUX.2 Klein (4B & 9B Distilled / Base)
16-channel Flux2 latent format, Qwen 3.5 text encoder, high speed.

```
[UNETLoader] ────────MODEL──────> [SamplerCustomAdvanced / KSampler] ──> [VAEDecode]
[CLIPLoader (flux2)] ─CLIP───────> [CLIPTextEncode] ──CONDITIONING───────┘       ▲
[VAELoader] ─────────VAE────────────────────────────────────────────────────────┘
[EmptyFlux2LatentImage] ─LATENT─────────────────────────────────────────────────┘
```

* **Model Loader:** `UNETLoader` $\rightarrow$ `flux-2-klein-9b-fp8.safetensors` (or `flux-2-klein-4b-fp8.safetensors` in `models/diffusion_models/`).
* **Text Encoder Loader:** `CLIPLoader` $\rightarrow$ `qwen_3_8b_fp8mixed.safetensors` (or `qwen_3_4b_fp8_mixed.safetensors` in `models/text_encoders/`).
  * **Crucial Setting:** Set dropdown `type:` to **`flux2`**.
* **VAE Loader:** `VAELoader` $\rightarrow$ `flux2-vae.safetensors` or `full_encoder_small_decoder.safetensors`.
* **Latent Node:** **`EmptyFlux2LatentImage`** (Do not use standard EmptyLatentImage).
* **Sampler Options:**
  * **Standard KSampler:**
    * **Steps:** `8` (Distilled) or `20` (Base).
    * **CFG:** `1.0` (Distilled) or `3.5 – 4.0` (Base).
    * **Sampler:** `euler`.
    * **Scheduler:** `simple` or `beta`.
  * **Advanced Node Setup (Official):**
    * `SamplerCustomAdvanced` $\rightarrow$ `KSamplerSelect` (`euler`) + `Flux2Scheduler` (steps: `8`, width: `1024`, height: `1024`) + `CFGGuider` (cfg: `1.0`).

---

### 4. Z-Image / Z-Image Turbo
Lumina 2 based flow-matching architecture with Qwen 3.5 text encoder and AuraFlow sampling.

```
[UNETLoader] ──────MODEL─> [ModelSamplingAuraFlow (shift: 3)] ──> [KSampler] ──> [VAEDecode]
[CLIPLoader (lumina2)] ─> [CLIPTextEncode] ──POS─────────────────────┘   ▲
                       └─> [ConditioningZeroOut] ──NEG───────────────┘   │
[VAELoader] ───────VAE───────────────────────────────────────────────────┘
[EmptySD3LatentImage] ───LATENT──────────────────────────────────────────┘
```

* **Model Loader:** `UNETLoader` $\rightarrow$ `z_image_turbo_bf16.safetensors` (in `models/diffusion_models/`).
* **Text Encoder Loader:** `CLIPLoader` $\rightarrow$ `qwen_3_4b_fp8_mixed.safetensors` (in `models/text_encoders/`).
  * **Crucial Setting:** Set dropdown `type:` to **`lumina2`**.
* **VAE Loader:** `VAELoader` $\rightarrow$ `ae.safetensors` (Standard Flux/SD3 VAE).
* **Latent Node:** **`EmptySD3LatentImage`** ($1024 \times 1024$).
* **Preconditioning:** Connect `UNETLoader.MODEL` $\rightarrow$ **`ModelSamplingAuraFlow`** (set `shift: 3.0` or `3.159`) $\rightarrow$ output to `KSampler.model`.
* **Conditioning:**
  * Positive: `CLIPTextEncode`.
  * Negative: Route positive into `ConditioningZeroOut` $\rightarrow$ connect to KSampler `negative`.
* **KSampler Settings:**
  * **Steps:** `8` (Turbo) or `20 – 25` (Base).
  * **CFG:** `1.0`.
  * **Sampler:** `res_multistep` (or `euler`).
  * **Scheduler:** `simple`.

---

### 5. FLUX.1 Dev
Full distilled flow-matching model. Uses Dual CLIP (CLIP-L + T5-XXL) and separate guidance scale.

```
[UNETLoader] ──────MODEL───────────────────────────────> [KSampler] ──LATENT──> [VAEDecode]
[DualCLIPLoader] ──CLIP──> [CLIPTextEncode] ──COND──> [FluxGuidance] ──POS─┘           ▲
[VAELoader] ───────VAE─────────────────────────────────────────────────────────────────┘
[EmptySD3LatentImage] ───LATENT────────────────────────────────────────────────────────┘
```

* **Model Loader:** `UNETLoader` $\rightarrow$ `flux1-dev-fp8.safetensors` (in `models/diffusion_models/`).
* **Text Encoder Loader:** `DualCLIPLoader` (in `models/clip/`):
  * `clip_name1`: `clip_l.safetensors`
  * `clip_name2`: `t5xxl_fp8_e4m3fn.safetensors`
  * `type:` **`flux`**
* **VAE Loader:** `VAELoader` $\rightarrow$ `ae.safetensors`.
* **Latent Node:** `EmptySD3LatentImage` ($1024 \times 1024$).
* **Guidance Node:** Connect `CLIPTextEncode` $\rightarrow$ **`FluxGuidance`** (`guidance: 3.5`).
* **KSampler Settings:**
  * **Steps:** `20 – 25`.
  * **CFG:** **`1.0`** (Flux ignores CFG; guidance is handled by `FluxGuidance`!).
  * **Sampler:** `euler`.
  * **Scheduler:** `simple` or `beta`.
  * **Denoise:** `1.0`.

---

### 6. FLUX.1 Fill (Inpainting / Outpainting)
Requires conditioning mask and latent injection into the transformer.

```
[LoadImage] ──────────IMAGE─> [InpaintModelConditioning] ──POS──> [KSampler] ──LATENT──> [VAEDecode]
                             ▲    ▲ (connect VAE & Mask)    └──NEG──┘      ▲
[UNETLoader] ──MODEL──> [DifferentialDiffusion] ──MODEL───────────────────┘      │
[DualCLIPLoader] ──CLIP──> [CLIPTextEncode] ──COND──> [FluxGuidance: 30] ─────────┘      │
[VAELoader] ────────────VAE──────────────────────────────────────────────────────────────┘
```

* **Model Loader:** `UNETLoader` $\rightarrow$ `flux1-fill-dev-fp8.safetensors` (in `models/diffusion_models/`).
* **Text Encoder Loader:** `DualCLIPLoader` $\rightarrow$ `clip_l.safetensors` + `t5xxl_fp8_e4m3fn.safetensors` (Type: `flux`).
* **VAE Loader:** `VAELoader` $\rightarrow$ `ae.safetensors`.
* **Conditioning & Diffusion Nodes:**
  * Connect `CLIPTextEncode` $\rightarrow$ `FluxGuidance` (Guidance: **`15.0 – 30.0`**).
  * Connect empty text conditioning $\rightarrow$ `InpaintModelConditioning` (`negative`).
  * Connect `LoadImage.IMAGE` + `LoadImage.MASK` + `VAELoader.VAE` $\rightarrow$ `InpaintModelConditioning`.
  * Connect `UNETLoader.MODEL` $\rightarrow$ **`DifferentialDiffusion`** $\rightarrow$ `KSampler.model` (smooths inpainting seams).
* **KSampler Settings:**
  * Connect `InpaintModelConditioning.positive` $\rightarrow$ `KSampler.positive`.
  * Connect `InpaintModelConditioning.negative` $\rightarrow$ `KSampler.negative`.
  * Connect `InpaintModelConditioning.latent` $\rightarrow$ `KSampler.latent_image`.
  * **Steps:** `20 – 28`.
  * **CFG:** `1.0`.
  * **Sampler:** `euler`.
  * **Scheduler:** `normal` or `beta`.
  * **Denoise:** `1.0`.

---

### 7. FLUX.1 Schnell (4-Step Turbo)
Ultra-fast distilled 4-step generation.

```
[UNETLoader] ──────MODEL───> [KSampler] ──LATENT──> [VAEDecode] ──> [SaveImage]
[DualCLIPLoader] ──CLIP────> [CLIPTextEncode] ──POS─────┘      ▲
[VAELoader] ───────VAE─────────────────────────────────────────┘
[EmptySD3LatentImage] ───LATENT────────────────────────────────┘
```

* **Model Loader:** `UNETLoader` $\rightarrow$ `flux1-schnell-fp8.safetensors` (in `models/diffusion_models/`).
* **Text Encoder Loader:** `DualCLIPLoader` $\rightarrow$ `clip_l.safetensors` + `t5xxl_fp8_e4m3fn.safetensors` (Type: `flux`).
* **VAE Loader:** `VAELoader` $\rightarrow$ `ae.safetensors`.
* **Latent Node:** `EmptySD3LatentImage` ($1024 \times 1024$).
* **Guidance:** None required (leave out `FluxGuidance` or set to `1.0`).
* **KSampler Settings:**
  * **Steps:** `4`.
  * **CFG:** `1.0`.
  * **Sampler:** `euler`.
  * **Scheduler:** `simple`.
  * **Denoise:** `1.0`.

---

## 2. Master Reference Matrix

| Architecture | Model Loader File | CLIP Loader Type | Text Encoder Files | VAE File | Latent Node | Steps / CFG | Sampler / Scheduler |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **SDXL** | `RealVisXL_V5.0_fp16.safetensors` | `sdxl` | Embedded or Clip L+G | `sdxl_vae.safetensors` | `EmptyLatentImage` | 30 / 7.0 | `dpmpp_2m` / `karras` |
| **Krea 2** | `krea2_turbo_fp8_scaled.safetensors` | **`krea2`** | `qwen3vl_4b_fp8_scaled.safetensors` | `qwen_image_vae.safetensors` | `EmptyLatentImage` | 8 / 1.0 | `euler` / `simple` |
| **FLUX.2 Klein** | `flux-2-klein-9b-fp8.safetensors` | **`flux2`** | `qwen_3_8b_fp8mixed.safetensors` | `flux2-vae.safetensors` | **`EmptyFlux2LatentImage`** | 8 / 1.0 | `euler` / `simple` |
| **Z-Image Turbo** | `z_image_turbo_bf16.safetensors` | **`lumina2`** | `qwen_3_4b_fp8_mixed.safetensors` | `ae.safetensors` | **`EmptySD3LatentImage`** | 8 / 1.0 | `res_multistep` / `simple` |
| **FLUX.1 Dev** | `flux1-dev-fp8.safetensors` | **`flux`** | `clip_l` + `t5xxl_fp8` | `ae.safetensors` | **`EmptySD3LatentImage`** | 20 / 1.0 (Guide: 3.5) | `euler` / `simple` |
| **FLUX.1 Fill** | `flux1-fill-dev-fp8.safetensors` | **`flux`** | `clip_l` + `t5xxl_fp8` | `ae.safetensors` | From `InpaintModelConditioning` | 24 / 1.0 (Guide: 30) | `euler` / `normal` |
| **FLUX.1 Schnell**| `flux1-schnell-fp8.safetensors` | **`flux`** | `clip_l` + `t5xxl_fp8` | `ae.safetensors` | **`EmptySD3LatentImage`** | 4 / 1.0 | `euler` / `simple` |

---

## 3. Complete Guide to LoRA (Low-Rank Adaptation)

### What LoRA Does in ComfyUI
LoRA applies low-rank mathematical weight adjustments on the fly to:
1. **Model (UNet / DiT Transformer):** Modifies how visuals, compositions, lighting, and anatomy are calculated.
2. **CLIP / Text Encoder:** Modifies how text tokens correspond to visual features.

### Can I use multiple LoRAs at once?
**YES, absolutely.** You can use 2, 3, 5, or more LoRAs in a single workflow (e.g., Character LoRA + Clothing LoRA + Lighting/Style LoRA + Acceleration LoRA).

---

### How to Chain Multiple LoRAs (Node Wiring)

#### Method 1: Serial Chaining (Standard Native ComfyUI)
Place `LoraLoader` nodes in sequence between your model/clip loaders and KSampler:

```
[UNETLoader]   ──MODEL──> [LoraLoader 1] ──MODEL──> [LoraLoader 2] ──MODEL──> [KSampler]
[CLIPLoader]   ──CLIP───> [LoraLoader 1] ──CLIP───> [LoraLoader 2] ──CLIP───> [CLIPTextEncode]
```

* In `LoraLoader 1`: Select e.g. Style LoRA (`strength_model: 0.7`, `strength_clip: 0.7`).
* In `LoraLoader 2`: Select e.g. Character LoRA (`strength_model: 0.8`, `strength_clip: 0.8`).
* Output of last LoRA goes directly into `KSampler.model` and `CLIPTextEncode.clip`.

#### Method 2: Stack Nodes (`CR LoRA Stack` / `Apply LoRA Stack`)
If you have `comfyui-impact-pack` or `comfyui-kjnodes` installed:
* Use **`CR LoRA Stack`** to list up to 10 LoRAs with individual switches and strengths on a single clean block.
* Connect the stack to **`Apply LoRA Stack`** between your base model and KSampler.

---

### LoRA Usage Per Architecture

#### 1. SDXL LoRAs
* **Types:** Style, Photorealism, Face/Character, Detailers, LCM / Turbo / Lightning adapters.
* **Node:** `LoraLoader` (affects both MODEL and CLIP).
* **Strengths:** Usually `0.6 – 0.9`. Full `1.0` can often cause high-contrast overcooking.
* **Acceleration Example:** `lcm-lora-sdxl.safetensors` (in `models/loras/`):
  * Set `strength_model: 1.0`, KSampler steps `4 – 6`, CFG `1.5 – 2.0`, scheduler `sgm_uniform`.

#### 2. Krea 2 LoRAs
* **Types:** Official style adapters (`krea2_darkbrush`, `krea2_retroanime`, `krea2_dotmatrix`, etc.).
* **Node:** `LoraLoaderModelOnly` or standard `LoraLoader`.
* **Strengths:** `0.8 – 1.0`.
* **Trigger Words Required:** Krea 2 style LoRAs **require** specific text prompt triggers:
  * `krea2_darkbrush.safetensors` $\rightarrow$ `"monochrome ink wash style"`
  * `krea2_retroanime.safetensors` $\rightarrow$ `"purple retro anime style"`
  * `krea2_dotmatrix.safetensors` $\rightarrow$ `"monochrome stippling style"`
  * `krea2_kidsdrawing.safetensors` $\rightarrow$ `"naive expressive sketch style"`
  * `krea2_rainywindow.safetensors` $\rightarrow$ `"rainy window style"`
  * `krea2_softwatercolor.safetensors` $\rightarrow$ `"art deco watercolor style"`
  * `krea2_vintagetarot.safetensors` $\rightarrow$ `"vintage tarot style"`

#### 3. FLUX.2 Klein LoRAs
* **Types:** Finetuned style/character adapters (e.g. `KLEIN-Unchained-V2.safetensors` in `models/loras/`).
* **Node:** `LoraLoader` or `LoraLoaderModelOnly`.
* **Strengths:** `0.7 – 1.0`.

#### 4. FLUX.1 Dev LoRAs
* **Types:** Hyper-FLUX 8-step/16-step acceleration LoRAs, Realism LoRAs, Character LoRAs.
* **Node:** `LoraLoader` (connect `MODEL` and `CLIP`).
* **Hyper-FLUX Acceleration LoRA:**
  * Connect `Hyper-FLUX.1-dev-8steps-lora.safetensors`.
  * Set `strength_model: 0.125` (or `1.0` depending on author specs).
  * Reduce KSampler steps from 20 down to `8`. Keep CFG `1.0`.

#### 5. FLUX.1 Schnell LoRAs
* **Important Note:** Schnell is already heavily distilled into 4 steps. Adding multiple heavy style LoRAs can degrade quality unless strengths are kept low (`0.4 – 0.6`).

---

### Golden Rules & Troubleshooting for LoRAs

1. **Architecture Matching is Mandatory:**
   * ❌ **Never mix cross-architecture LoRAs:** An SDXL LoRA will crash or produce pure black/noise if loaded into FLUX or Krea.
   * ✅ **Rule:** Model loader and LoRA must share the exact same foundation (SDXL with SDXL, Flux with Flux, Krea with Krea).
2. **Avoid "Overbaking" When Stacking Multiple LoRAs:**
   * If you load 3 LoRAs all at `1.0` strength, weights clip and images burn out (deep oversaturated shadows, neon skin, geometric artifacts).
   * **The Diminishing Rule:** Reduce strengths so their sum does not violently exceed 1.2–1.5 (e.g. LoRA 1 at `0.6`, LoRA 2 at `0.5`, LoRA 3 at `0.3`).
3. **Trigger Words:**
   * Always check the LoRA card for trigger keywords. If a character or style LoRA trained on a token (e.g. `cxx woman` or `retro anime`), omit it and the LoRA effect will be faint or invisible.
4. **VRAM Impact:**
   * Applying LoRAs in ComfyUI modifies model weights in memory or patches them during calculation. It uses virtually zero additional VRAM (typically < 50MB per LoRA), making LoRA stacking very lightweight on your 16GB RX 9060 XT.
