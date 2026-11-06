#!/usr/bin/env python3
"""Generate Resources/AppIcon.icns and Resources/AppIcon.png.

The icon is an original design: a warm red gradient tile with the Bengali
letter "হ" (ho) and a small play mark. It deliberately does not reproduce
hoichoi's logo or wordmark.

Requires Pillow (python3 -m pip install pillow) and a font with Bengali
glyphs. GNU FreeSans is used by default (Debian/Ubuntu: fonts-freefont-ttf);
pass another font path as the first argument to override.

Usage:  python3 scripts/make_icon.py [path/to/font.ttf]
"""
import io
import struct
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT_ICNS = ROOT / "Resources" / "AppIcon.icns"
OUT_PNG = ROOT / "Resources" / "AppIcon.png"
SIZE = 1024
TILE = 824  # macOS Big Sur icon grid: 824px tile centred on a 1024px canvas
RADIUS = 185
GLYPH = "হ"  # Bengali letter HA (হ)

FONT_CANDIDATES = [
    "/usr/share/fonts/truetype/freefont/FreeSans.ttf",
    "/Library/Fonts/FreeSans.ttf",
    "/System/Library/Fonts/Supplemental/Bangla Sangam MN.ttc",
    "/System/Library/Fonts/KohinoorBangla.ttc",
]

# Diagonal gradient stops (top-left -> bottom-right): amber, coral red, crimson, plum.
STOPS = [
    (0.00, (255, 159, 67)),
    (0.35, (247, 68, 60)),
    (0.70, (206, 22, 72)),
    (1.00, (112, 16, 82)),
]


def lerp(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def gradient(size: int) -> Image.Image:
    # Build a 1-D ramp, then stretch it along the diagonal (fast, no per-pixel loop).
    n = 512
    ramp = Image.new("RGB", (n, 1))
    for i in range(n):
        t = i / (n - 1)
        for (t0, c0), (t1, c1) in zip(STOPS, STOPS[1:]):
            if t <= t1:
                ramp.putpixel((i, 0), lerp(c0, c1, (t - t0) / (t1 - t0)))
                break
    diag = int(size * 1.4143) + 2
    band = ramp.resize((diag, diag), Image.BICUBIC).rotate(-45, resample=Image.BICUBIC)
    off = (diag - size) // 2
    return band.crop((off, off, off + size, off + size)).convert("RGBA")


def load_font(px: int) -> ImageFont.FreeTypeFont:
    paths = [sys.argv[1]] if len(sys.argv) > 1 else FONT_CANDIDATES
    for path in paths:
        try:
            font = ImageFont.truetype(path, px)
        except OSError:
            continue
        # Reject fonts that render the glyph as a missing-glyph box.
        if font.getmask(GLYPH).getbbox() != font.getmask("￿").getbbox():
            return font
    sys.exit("No font with Bengali glyphs found; pass one as the first argument.")


def render() -> Image.Image:
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    off = (SIZE - TILE) // 2

    mask = Image.new("L", (TILE, TILE), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, TILE - 1, TILE - 1), RADIUS, fill=255)

    # Soft drop shadow under the tile.
    shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (off, off + 16, off + TILE, off + TILE + 16), RADIUS, fill=(40, 0, 20, 120)
    )
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(22)))

    tile = gradient(TILE)

    # Gentle radial glow in the upper-left for depth.
    glow = Image.new("L", (TILE, TILE), 0)
    ImageDraw.Draw(glow).ellipse((-TILE * 0.35, -TILE * 0.35, TILE * 0.75, TILE * 0.75), fill=70)
    glow = glow.filter(ImageFilter.GaussianBlur(120))
    tile = Image.composite(Image.new("RGBA", tile.size, (255, 236, 200, 255)), tile, glow)

    # --- Foreground: the letter হ, made bold with a stroke, plus a play mark.
    fg = Image.new("L", (TILE, TILE), 0)
    font = load_font(560)
    d = ImageDraw.Draw(fg)
    bbox = d.textbbox((0, 0), GLYPH, font=font, stroke_width=26)
    gw, gh = bbox[2] - bbox[0], bbox[3] - bbox[1]
    gx = (TILE - gw) / 2 - bbox[0] - 40
    gy = (TILE - gh) / 2 - bbox[1] - 10
    d.text((gx, gy), GLYPH, font=font, fill=255, stroke_width=26, stroke_fill=255)

    # Play triangle tucked into the lower-right of the letter.
    cx, cy, h = TILE * 0.73, TILE * 0.70, TILE * 0.20
    w = h * 0.9
    tri = Image.new("L", (TILE, TILE), 0)
    ImageDraw.Draw(tri).polygon(
        [(cx - w / 2, cy - h / 2), (cx - w / 2, cy + h / 2), (cx + w / 2, cy)], fill=255
    )
    tri = tri.filter(ImageFilter.GaussianBlur(7)).point(lambda a: 255 if a > 140 else 0)
    # Cut a gap around the triangle out of the letter so the two read separately.
    gap = tri.filter(ImageFilter.MaxFilter(41))
    fg = ImageChops.subtract(fg, gap)
    fg = ImageChops.lighter(fg, tri)

    # Smooth the edges a touch.
    fg = fg.filter(ImageFilter.GaussianBlur(1.2))

    # Subtle shadow beneath the white artwork.
    fg_shadow = fg.filter(ImageFilter.GaussianBlur(14)).point(lambda a: a * 0.35)
    shadow_layer = Image.new("RGBA", tile.size, (90, 0, 30, 255))
    shadow_layer.putalpha(fg_shadow)
    tile.alpha_composite(shadow_layer, (0, 10))

    white = Image.new("RGBA", tile.size, (255, 255, 255, 255))
    white.putalpha(fg)
    tile.alpha_composite(white)

    canvas.paste(tile, (off, off), mask)
    return canvas


def png_bytes(img: Image.Image, size: int) -> bytes:
    buf = io.BytesIO()
    img.resize((size, size), Image.LANCZOS).save(buf, format="PNG")
    return buf.getvalue()


def main() -> None:
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
