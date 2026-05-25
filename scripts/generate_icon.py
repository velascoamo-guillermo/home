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
    """Diagonal white->transparent->dark overlay (155 degrees)."""
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
    print(f"  saved -> {path}")


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
    print(f"  updated -> {path}")


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
    print("Generating icons...")
    render_variant(LIGHT_STOPS,  "AppIcon-light.png")
    render_variant(DARK_STOPS,   "AppIcon-dark.png")
    render_variant(TINTED_STOPS, "AppIcon-tinted.png")
    update_contents_json()
    print("Done.")
