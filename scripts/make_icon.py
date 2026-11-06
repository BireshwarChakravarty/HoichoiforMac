#!/usr/bin/env python3
"""Generate Resources/AppIcon.icns and Resources/AppIcon.png.

The icon is an original, purely geometric design made for this project:
an evening "sun" disc with a play-shaped cut-out, ringed by a dotted
pattern inspired by traditional alpona floor art, on a deep dusk-blue tile.
It uses no fonts, letters, wordmarks or third-party artwork, and is not
modelled on any company's logo.

Requires Pillow:  python3 -m pip install pillow
Usage:            python3 scripts/make_icon.py
"""
import io
import math
import struct
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT_ICNS = ROOT / "Resources" / "AppIcon.icns"
OUT_PNG = ROOT / "Resources" / "AppIcon.png"

SIZE = 1024
SS = 2                      # supersampling factor for smooth edges
S = SIZE * SS
TILE = 824 * SS             # macOS icon grid: 824px tile centred on 1024px
OFF = (S - TILE) // 2
RADIUS = 185 * SS

# Palette
DUSK_TOP = (38, 28, 92)       # indigo
DUSK_BOTTOM = (10, 62, 78)    # deep teal
SUN_TOP = (255, 214, 102)     # marigold
SUN_BOTTOM = (255, 128, 58)   # saffron
CREAM = (255, 240, 214)


def vertical_gradient(w, h, top, bottom):
    col = Image.new("RGB", (1, 256))
    for y in range(256):
        t = y / 255
        col.putpixel((0, y), tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)))
    return col.resize((w, h), Image.BICUBIC).convert("RGBA")


def rounded_mask(w, h, r):
    m = Image.new("L", (w, h), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, w - 1, h - 1), r, fill=255)
    return m


def render():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))

    # Drop shadow under the tile.
    shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (OFF, OFF + 16 * SS, OFF + TILE, OFF + TILE + 16 * SS), RADIUS, fill=(0, 0, 0, 120)
    )
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(20 * SS)))

    # Tile background.
    tile = vertical_gradient(TILE, TILE, DUSK_TOP, DUSK_BOTTOM)
    tile_mask = rounded_mask(TILE, TILE, RADIUS)
    img.paste(tile, (OFF, OFF), tile_mask)

    cx, cy = S // 2, S // 2 - 6 * SS

    # Soft glow behind the sun.
    glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    gr = 300 * SS
    ImageDraw.Draw(glow).ellipse((cx - gr, cy - gr, cx + gr, cy + gr), fill=SUN_TOP + (55,))
    glow = glow.filter(ImageFilter.GaussianBlur(60 * SS))
    clipped = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    clipped.paste(glow, (0, 0), _tile_mask_full(tile_mask))
    img.alpha_composite(clipped)

    # Alpona-style dotted ring: alternating large and small dots.
    ring = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    rd = ImageDraw.Draw(ring)
    count = 24
    ring_r = 292 * SS
    for i in range(count):
        a = 2 * math.pi * i / count - math.pi / 2
        x, y = cx + ring_r * math.cos(a), cy + ring_r * math.sin(a)
        dot = (17 if i % 2 == 0 else 9) * SS
        rd.ellipse((x - dot, y - dot, x + dot, y + dot), fill=CREAM + (235,))
    # Thin inner ring.
    inner = 252 * SS
    w = 6 * SS
    rd.ellipse((cx - inner, cy - inner, cx + inner, cy + inner), outline=CREAM + (150,), width=w)
    img.alpha_composite(ring)

    # Sun disc with a play-shaped cut-out (the tile shows through).
    sun_r = 214 * SS
    sun = vertical_gradient(2 * sun_r, 2 * sun_r, SUN_TOP, SUN_BOTTOM)
    sun_mask = Image.new("L", (2 * sun_r, 2 * sun_r), 0)
    sd = ImageDraw.Draw(sun_mask)
    sd.ellipse((0, 0, 2 * sun_r - 1, 2 * sun_r - 1), fill=255)

    # Rounded play triangle, optically centred (nudged right).
    h = 196 * SS
    tw = h * 0.88
    tx = sun_r + 14 * SS
    ty = sun_r
    tri = [(tx - tw / 2, ty - h / 2), (tx - tw / 2, ty + h / 2), (tx + tw / 2, ty)]
    tri_mask = Image.new("L", (2 * sun_r, 2 * sun_r), 0)
    ImageDraw.Draw(tri_mask).polygon(tri, fill=255)
    # Round the triangle's corners: blur then threshold.
    tri_mask = tri_mask.filter(ImageFilter.GaussianBlur(14 * SS)).point(lambda v: 255 if v > 150 else 0)
    sun_mask.paste(0, (0, 0), tri_mask)

    img.paste(sun, (cx - sun_r, cy - sun_r), sun_mask)

    # Subtle top sheen on the tile.
    sheen = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    ImageDraw.Draw(sheen).ellipse(
        (-TILE * 0.4, -TILE * 0.95, TILE * 1.4, TILE * 0.35), fill=(255, 255, 255, 18)
    )
    sheen_clipped = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    sheen_clipped.paste(sheen, (0, 0), tile_mask)
    img.alpha_composite(sheen_clipped, (OFF, OFF))

    return img.resize((SIZE, SIZE), Image.LANCZOS)


def _tile_mask_full(tile_mask):
    full = Image.new("L", (S, S), 0)
    full.paste(tile_mask, (OFF, OFF))
    return full


def png_bytes(img, size):
    buf = io.BytesIO()
    img.resize((size, size), Image.LANCZOS).save(buf, format="PNG")
    return buf.getvalue()


def main():
    base = render()
    entries = [
        (b"icp4", 16), (b"icp5", 32), (b"icp6", 64),
        (b"ic07", 128), (b"ic08", 256), (b"ic09", 512), (b"ic10", 1024),
        (b"ic11", 32), (b"ic12", 64), (b"ic13", 256), (b"ic14", 512),
    ]
    chunks = b""
    for kind, size in entries:
        data = png_bytes(base, size)
        chunks += kind + struct.pack(">I", len(data) + 8) + data
    OUT_ICNS.write_bytes(b"icns" + struct.pack(">I", len(chunks) + 8) + chunks)
    base.save(OUT_PNG)
    print(f"wrote {OUT_ICNS} and {OUT_PNG}")


if __name__ == "__main__":
    main()
