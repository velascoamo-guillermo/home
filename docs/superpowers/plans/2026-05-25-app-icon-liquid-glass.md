# App Icon — iOS 26 Liquid Glass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate three 1024×1024 PNG app icon variants (light, dark, tinted) using a Python script and wire them into the Xcode asset catalogue.

**Architecture:** A standalone Python script (`scripts/generate_icon.py`) renders each variant via Pillow — gradient background, translucent glass house glyph, diagonal glass overlay, specular highlight. The script also rewrites `Contents.json`. No Swift code changes.

**Tech Stack:** Python 3, Pillow 12, NumPy (gradient math), git worktree

---

## File Map

| Action | Path |
|--------|------|
| Create | `scripts/generate_icon.py` |
| Overwrite | `Home/Assets.xcassets/AppIcon.appiconset/Contents.json` |
| Generate | `Home/Assets.xcassets/AppIcon.appiconset/AppIcon-light.png` |
| Generate | `Home/Assets.xcassets/AppIcon.appiconset/AppIcon-dark.png` |
| Generate | `Home/Assets.xcassets/AppIcon.appiconset/AppIcon-tinted.png` |

---

## Task 1: Create git worktree

**Files:** none (git housekeeping)

- [ ] **Step 1: Add worktree from main**

```bash
cd "/Users/guillermovelasco/Documents/Projects/Swifts Projects/Home"
git worktree add ../Home-icon-wt -b feature/app-icon-liquid-glass main
```

Expected output: `Preparing worktree (new branch 'feature/app-icon-liquid-glass')`

- [ ] **Step 2: Verify worktree exists**

```bash
git worktree list
```

Expected: three rows — main repo, `Home-symbol-fix`, and new `Home-icon-wt`.

- [ ] **Step 3: Copy Config.xcconfig into worktree (needed for Xcode builds)**

```bash
cp "/Users/guillermovelasco/Documents/Projects/Swifts Projects/Home/Config.xcconfig" \
   "/Users/guillermovelasco/Documents/Projects/Swifts Projects/Home-icon-wt/Config.xcconfig"
```

---

## Task 2: Write the icon generation script

**Files:**
- Create: `scripts/generate_icon.py` (relative to worktree root)

- [ ] **Step 1: Confirm Pillow + NumPy are available**

```bash
python3 -c "from PIL import Image; import numpy; print('ok')"
```

Expected: `ok`
If not: `pip3 install pillow numpy --break-system-packages`

- [ ] **Step 2: Create `scripts/` directory and write the script**

```bash
mkdir -p "/Users/guillermovelasco/Documents/Projects/Swifts Projects/Home-icon-wt/scripts"
```

Write the following to `scripts/generate_icon.py`:

```python
#!/usr/bin/env python3
"""Generate iOS 26 liquid-glass app icons for the Home app (3 variants)."""

import json
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
_here = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(_here, "..", "Home", "Assets.xcassets", "AppIcon.appiconset")


def hex_to_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i : i + 2], 16) for i in (0, 2, 4))


# ---------------------------------------------------------------------------
# Gradient
# ---------------------------------------------------------------------------

def make_gradient(stops, angle_deg):
    """Return SIZE×SIZE RGBA image filled with a multi-stop linear gradient."""
    rad = math.radians(angle_deg)
    dx, dy = math.sin(rad), -math.cos(rad)

    half = SIZE / 2
    xs = np.linspace(-half, half, SIZE, dtype=np.float32)
    ys = np.linspace(-half, half, SIZE, dtype=np.float32)
    xx, yy = np.meshgrid(xs, ys)

    max_proj = abs(dx) * half + abs(dy) * half
    t = np.clip((xx * dx + yy * dy) / max_proj * 0.5 + 0.5, 0.0, 1.0)

    sorted_stops = sorted(stops, key=lambda s: s[0])
    channels = []
    for ch in range(3):
        arr = np.zeros((SIZE, SIZE), dtype=np.float32)
        for i in range(len(sorted_stops) - 1):
            t0, c0 = sorted_stops[i]
            t1, c1 = sorted_stops[i + 1]
            span = max(t1 - t0, 1e-6)
            mask = (t >= t0) & (t < t1)
            local_t = np.where(mask, (t - t0) / span, 0.0)
            arr += mask * (c0[ch] + local_t * (c1[ch] - c0[ch]))
        last_t, last_c = sorted_stops[-1]
        arr = np.where(t >= last_t, float(last_c[ch]), arr)
        channels.append(np.clip(arr, 0, 255).astype(np.uint8))

    alpha = np.full((SIZE, SIZE), 255, dtype=np.uint8)
    return Image.fromarray(np.stack([*channels, alpha], axis=2), "RGBA")


# ---------------------------------------------------------------------------
# Glyph
# ---------------------------------------------------------------------------

def draw_glyph(draw: ImageDraw.ImageDraw):
    """Draw translucent glass house onto an RGBA draw context."""
    cx = SIZE // 2  # 512

    roof_apex  = (cx, 210)
    roof_left  = (270, 445)
    roof_right = (755, 445)
    body_bot   = 785

    chim_l, chim_r   = 640, 705
    chim_top, chim_bot = 215, 345

    door_w  = 130
    door_h  = 185
    door_bot = body_bot
    door_top = door_bot - door_h          # 600
    door_arch_r  = door_w // 2            # 65
    door_arch_cy = door_top + door_arch_r  # 665

    FILL_BODY = (255, 255, 255, 71)    # 0.28
    FILL_DOOR = (255, 255, 255, 107)   # 0.42
    FILL_CHIM = (255, 255, 255, 51)    # 0.20
    STK       = (255, 255, 255, 166)   # 0.65
    STK_D     = (255, 255, 255, 178)   # 0.70
    STK_C     = (255, 255, 255, 128)   # 0.50
    SW = 7  # stroke width px

    # chimney (behind roof)
    draw.rectangle([(chim_l, chim_top), (chim_r, chim_bot)],
                   fill=FILL_CHIM, outline=STK_C, width=SW)

    # house body + roof as one polygon
    draw.polygon(
        [roof_left, roof_apex, roof_right,
         (roof_right[0], body_bot), (roof_left[0], body_bot)],
        fill=FILL_BODY, outline=STK, width=SW,
    )

    # door: filled rectangle (lower) + filled semicircle (arch)
    dl = cx - door_w // 2
    dr = cx + door_w // 2
    draw.rectangle([(dl, door_arch_cy), (dr, door_bot)],
                   fill=FILL_DOOR, outline=None)
    draw.pieslice([(dl, door_top), (dr, door_top + door_w)],
                  start=180, end=0, fill=FILL_DOOR, outline=None)

    # door stroke (manual lines + arc — outline on pieslice clips poorly)
    draw.line([(dl, door_arch_cy), (dl, door_bot)], fill=STK_D, width=SW)
    draw.line([(dr, door_arch_cy), (dr, door_bot)], fill=STK_D, width=SW)
    draw.line([(dl, door_bot), (dr, door_bot)],     fill=STK_D, width=SW)
    draw.arc([(dl, door_top), (dr, door_top + door_w)],
             start=180, end=0, fill=STK_D, width=SW)


# ---------------------------------------------------------------------------
# Glass layers
# ---------------------------------------------------------------------------

def _gradient_layer(stops, angle_deg):
    """Generic RGBA gradient layer (same maths as make_gradient)."""
    rad = math.radians(angle_deg)
    dx, dy = math.sin(rad), -math.cos(rad)
    half = SIZE / 2
    xs = np.linspace(-half, half, SIZE, dtype=np.float32)
    ys = np.linspace(-half, half, SIZE, dtype=np.float32)
    xx, yy = np.meshgrid(xs, ys)
    max_proj = abs(dx) * half + abs(dy) * half
    t = np.clip((xx * dx + yy * dy) / max_proj * 0.5 + 0.5, 0.0, 1.0)

    sorted_stops = sorted(stops, key=lambda s: s[0])
    channels = []
    for ch in range(4):
        arr = np.zeros((SIZE, SIZE), dtype=np.float32)
        for i in range(len(sorted_stops) - 1):
            t0, c0 = sorted_stops[i]
            t1, c1 = sorted_stops[i + 1]
            span = max(t1 - t0, 1e-6)
            mask = (t >= t0) & (t < t1)
            local_t = np.where(mask, (t - t0) / span, 0.0)
            arr += mask * (c0[ch] + local_t * (c1[ch] - c0[ch]))
        last_t, last_c = sorted_stops[-1]
        arr = np.where(t >= last_t, float(last_c[ch]), arr)
        channels.append(np.clip(arr, 0, 255).astype(np.uint8))

    return Image.fromarray(np.stack(channels, axis=2), "RGBA")


def make_glass_overlay():
    """Diagonal white→transparent→dark overlay (155°)."""
    stops = [
        (0.00, (255, 255, 255, 133)),
        (0.30, (255, 255, 255, 26)),
        (0.55, (0,   0,   0,   0)),
        (1.00, (0,   0,   0,   18)),
    ]
    return _gradient_layer(stops, angle_deg=155)


def make_specular():
    """Blurred white specular pill near top centre."""
    layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    pw, ph = 180, 60
    px = SIZE // 2 - pw // 2
    py = 82
    draw.ellipse([(px, py), (px + pw, py + ph)],
                 fill=(255, 255, 255, int(0.78 * 255)))
    return layer.filter(ImageFilter.GaussianBlur(radius=20))


def make_top_rim():
    """Soft bright rim along the top edge (inner edge highlight)."""
    layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    draw.rectangle([(0, 0), (SIZE, 6)], fill=(255, 255, 255, 184))
    return layer.filter(ImageFilter.GaussianBlur(radius=4))


# ---------------------------------------------------------------------------
# Render
# ---------------------------------------------------------------------------

def render_variant(gradient_stops, filename):
    base = make_gradient(gradient_stops, angle_deg=145)

    glyph_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw_glyph(ImageDraw.Draw(glyph_layer))
    base = Image.alpha_composite(base, glyph_layer)

    base = Image.alpha_composite(base, make_glass_overlay())
    base = Image.alpha_composite(base, make_specular())
    base = Image.alpha_composite(base, make_top_rim())

    path = os.path.join(OUT_DIR, filename)
    base.save(path, "PNG")
    print(f"  saved → {path}")


# ---------------------------------------------------------------------------
# Contents.json
# ---------------------------------------------------------------------------

def update_contents_json():
    path = os.path.join(OUT_DIR, "Contents.json")
    contents = {
        "images": [
            {
                "filename": "AppIcon-light.png",
                "idiom": "universal",
                "platform": "ios",
                "size": "1024x1024",
            },
            {
                "appearances": [{"appearance": "luminosity", "value": "dark"}],
                "filename": "AppIcon-dark.png",
                "idiom": "universal",
                "platform": "ios",
                "size": "1024x1024",
            },
            {
                "appearances": [{"appearance": "luminosity", "value": "tinted"}],
                "filename": "AppIcon-tinted.png",
                "idiom": "universal",
                "platform": "ios",
                "size": "1024x1024",
            },
        ],
        "info": {"author": "xcode", "version": 1},
    }
    with open(path, "w") as f:
        json.dump(contents, f, indent=2)
    print(f"  updated → {path}")


# ---------------------------------------------------------------------------
# Colour palettes
# ---------------------------------------------------------------------------

LIGHT_STOPS = [
    (0.00, hex_to_rgb("#f7ca82")),
    (0.52, hex_to_rgb("#e8834a")),
    (1.00, hex_to_rgb("#c0411e")),
]
DARK_STOPS = [
    (0.00, hex_to_rgb("#e8a840")),
    (0.52, hex_to_rgb("#c0541a")),
    (1.00, hex_to_rgb("#7a1e08")),
]
TINTED_STOPS = [
    (0.00, hex_to_rgb("#aaaaaa")),
    (1.00, hex_to_rgb("#666666")),
]

if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)
    print("Generating icons…")
    render_variant(LIGHT_STOPS,  "AppIcon-light.png")
    render_variant(DARK_STOPS,   "AppIcon-dark.png")
    render_variant(TINTED_STOPS, "AppIcon-tinted.png")
    update_contents_json()
    print("Done.")
```

- [ ] **Step 3: Make script executable**

```bash
chmod +x "/Users/guillermovelasco/Documents/Projects/Swifts Projects/Home-icon-wt/scripts/generate_icon.py"
```

- [ ] **Step 4: Commit script**

```bash
cd "/Users/guillermovelasco/Documents/Projects/Swifts Projects/Home-icon-wt"
git add scripts/generate_icon.py
git commit -m "feat: add icon generation script (liquid glass, 3 variants)"
```

---

## Task 3: Run the script and verify output

**Files:** generates `AppIcon-light.png`, `AppIcon-dark.png`, `AppIcon-tinted.png`

- [ ] **Step 1: Run the script**

```bash
cd "/Users/guillermovelasco/Documents/Projects/Swifts Projects/Home-icon-wt"
python3 scripts/generate_icon.py
```

Expected output:
```
Generating icons…
  saved → …/AppIcon-light.png
  saved → …/AppIcon-dark.png
  saved → …/AppIcon-tinted.png
  updated → …/Contents.json
Done.
```

- [ ] **Step 2: Verify file sizes are reasonable (each should be 500 KB–3 MB)**

```bash
ls -lh "/Users/guillermovelasco/Documents/Projects/Swifts Projects/Home-icon-wt/Home/Assets.xcassets/AppIcon.appiconset/"
```

Expected: three `.png` files present alongside `Contents.json`.

- [ ] **Step 3: Quick pixel-level sanity check**

```bash
python3 - <<'EOF'
from PIL import Image
for name in ("AppIcon-light.png", "AppIcon-dark.png", "AppIcon-tinted.png"):
    p = f"/Users/guillermovelasco/Documents/Projects/Swifts Projects/Home-icon-wt/Home/Assets.xcassets/AppIcon.appiconset/{name}"
    img = Image.open(p)
    print(name, img.size, img.mode)
    px = img.getpixel((512, 512))
    print("  centre pixel:", px)
EOF
```

Expected: `(1024, 1024) RGBA` for all three. Centre pixel should be semi-opaque (A=255, non-zero RGB).

- [ ] **Step 4: Take a screenshot of the light icon to visually verify**

```bash
python3 - <<'EOF'
from PIL import Image
img = Image.open("/Users/guillermovelasco/Documents/Projects/Swifts Projects/Home-icon-wt/Home/Assets.xcassets/AppIcon.appiconset/AppIcon-light.png")
# Show a 256px thumbnail for quick review
thumb = img.resize((256, 256), Image.LANCZOS)
thumb.save("/tmp/icon-preview.png")
print("Preview saved to /tmp/icon-preview.png")
EOF
open /tmp/icon-preview.png
```

Visually confirm: amber-to-terracotta gradient, white house shape centred, bright specular pill at top.

If the house glyph looks off (too small, clipped, wrong position), adjust the coordinate constants in `draw_glyph()` and re-run.

---

## Task 4: Commit generated assets and updated Contents.json

**Files:**
- Modify: `Home/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Add: `Home/Assets.xcassets/AppIcon.appiconset/AppIcon-light.png`
- Add: `Home/Assets.xcassets/AppIcon.appiconset/AppIcon-dark.png`
- Add: `Home/Assets.xcassets/AppIcon.appiconset/AppIcon-tinted.png`

- [ ] **Step 1: Stage and commit**

```bash
cd "/Users/guillermovelasco/Documents/Projects/Swifts Projects/Home-icon-wt"
git add Home/Assets.xcassets/AppIcon.appiconset/
git commit -m "feat: add liquid glass app icon (light, dark, tinted variants)"
```

- [ ] **Step 2: Confirm commit contains all four files**

```bash
git show --stat HEAD
```

Expected: 4 files changed — `Contents.json` + 3 PNGs.

---

## Task 5: Push branch and open PR

- [ ] **Step 1: Push branch to origin**

```bash
cd "/Users/guillermovelasco/Documents/Projects/Swifts Projects/Home-icon-wt"
git push -u origin feature/app-icon-liquid-glass
```

- [ ] **Step 2: Open PR**

```bash
gh pr create \
  --title "feat: iOS 26 liquid glass app icon" \
  --body "$(cat <<'EOF'
## Summary
- Adds `scripts/generate_icon.py` — Pillow script that renders 3 × 1024×1024 PNGs
- Warm Hearth concept: amber → terracotta gradient, translucent glass house glyph, specular highlight
- Three Xcode variants wired: light (default), dark, tinted
- `Contents.json` updated to reference all three files

## Test plan
- [ ] Open project in Xcode → Assets.xcassets → AppIcon — confirm all 3 slots show the icon preview
- [ ] Build on simulator (iOS 26) — confirm icon appears on home screen in light mode
- [ ] Switch simulator to dark mode — confirm dark variant renders
- [ ] No Swift code changed — zero risk of functional regression

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)" \
  --base main
```

- [ ] **Step 3: Copy the PR URL from the output and share it.**
