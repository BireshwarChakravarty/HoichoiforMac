#!/usr/bin/env python3
"""Generate Resources/AppIcon.icns (an original icon, not hoichoi's logo).

Requires Pillow:  python3 -m pip install pillow
Usage:            python3 scripts/make_icon.py
"""
import io
import struct
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "Resources" / "AppIcon.icns"
SIZE = 1024


def lerp(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def render() -> Image.Image:
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))

    # macOS-style squircle-ish tile with margins (Big Sur grid: 824px tile).
    tile = 824
    off = (SIZE - tile) // 2
    radius = 185

    # Diagonal gradient: warm red -> deep magenta -> indigo.
    stops = [(0.0, (255, 84, 62)), (0.55, (214, 30, 96)), (1.0, (74, 22, 120))]
    grad = Image.new("RGBA", (tile, tile))
    px = grad.load()
    for y in range(tile):
        for x in range(tile):
            t = (x + y) / (2 * (tile - 1))
            for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
                if t <= t1:
                    px[x, y] = lerp(c0, c1, (t - t0) / (t1 - t0)) + (255,)
                    break

    mask = Image.new("L", (tile, tile), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, tile - 1, tile - 1), radius, fill=255)

    # Soft drop shadow.
    shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (off, off + 18, off + tile, off + tile + 18), radius, fill=(0, 0, 0, 110)
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(22))
    img.alpha_composite(shadow)

    img.paste(grad, (off, off), mask)

    # Subtle top highlight.
    hl = Image.new("RGBA", (tile, tile), (0, 0, 0, 0))
    ImageDraw.Draw(hl).ellipse((-tile * 0.3, -tile * 0.75, tile * 1.3, tile * 0.45), fill=(255, 255, 255, 34))
    hl_masked = Image.new("RGBA", (tile, tile), (0, 0, 0, 0))
    hl_masked.paste(hl, (0, 0), mask)
    img.alpha_composite(hl_masked, (off, off))

    # Rounded play triangle.
    d = ImageDraw.Draw(img)
    cx, cy = SIZE / 2 + 28, SIZE / 2
    h = 330
    w = h * 0.9
    tri = [(cx - w / 2, cy - h / 2), (cx - w / 2, cy + h / 2), (cx + w / 2, cy)]
    tri_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ImageDraw.Draw(tri_layer).polygon(tri, fill=(255, 255, 255, 255))
    tri_layer = tri_layer.filter(ImageFilter.GaussianBlur(10))
    alpha = tri_layer.getchannel("A").point(lambda a: 255 if a > 140 else 0)
    white = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 255))
    img.paste(white, (0, 0), alpha)
    del d
    return img


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
    OUT.write_bytes(b"icns" + struct.pack(">I", len(chunks) + 8) + chunks)
    base.save(ROOT / "Resources" / "AppIcon.png")
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
