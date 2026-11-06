#!/usr/bin/env python3
"""Build Resources/AppIcon.icns and Resources/AppIcon.png from Resources/AppIconSource.png.

The source artwork is a red rounded tile with a white "H" on a white
background. This script:
  1. removes the white background around the tile (keeping anti-aliased edges),
  2. crops to the tile and scales it onto Apple's macOS icon grid
     (an 824 px tile centred on a 1024 px canvas),
  3. adds the standard soft drop shadow,
  4. writes a multi-resolution .icns plus a 1024 px PNG preview.

Requires Pillow and NumPy:  python3 -m pip install pillow numpy
Usage:                      python3 scripts/make_icon.py
"""
import io
import struct
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "Resources" / "AppIconSource.png"
OUT_ICNS = ROOT / "Resources" / "AppIcon.icns"
OUT_PNG = ROOT / "Resources" / "AppIcon.png"

SIZE = 1024
TILE = 824


def exterior_mask(rgb: np.ndarray, threshold: int = 40) -> np.ndarray:
    """Pixels connected to the image border that are close to white."""
    h, w, _ = rgb.shape
    near_white = (255 - rgb.min(axis=2)) <= threshold
    seen = np.zeros((h, w), dtype=bool)
    queue = deque()
    for x in range(w):
        for y in (0, h - 1):
            if near_white[y, x] and not seen[y, x]:
                seen[y, x] = True
                queue.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if near_white[y, x] and not seen[y, x]:
                seen[y, x] = True
                queue.append((y, x))
    while queue:
        y, x = queue.popleft()
        for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
            if 0 <= ny < h and 0 <= nx < w and near_white[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True
                queue.append((ny, nx))
    return seen


def cut_out_tile(img: Image.Image) -> Image.Image:
    rgb = np.asarray(img.convert("RGB")).astype(np.float32)
    outside = exterior_mask(rgb.astype(np.uint8))

    # Opacity: fully opaque inside the tile, fully clear outside. Pixels on the
    # boundary are a blend of the red tile and white, so estimate their
    # coverage from how far the green channel is from white.
    alpha = np.where(outside, 0.0, 1.0)
    edge = np.zeros_like(outside)
    grown = Image.fromarray((outside * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5))
    shrunk = Image.fromarray((outside * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(5))
    edge = (np.asarray(grown) > 0) & ~(np.asarray(shrunk) > 0)
    coverage = np.clip((254.0 - rgb[..., 1]) / 254.0, 0.0, 1.0)
    alpha = np.where(edge, coverage, alpha)

    # Un-blend white from the edge pixels so they don't leave a pale halo.
    a = np.maximum(alpha, 1e-3)[..., None]
    unblended = np.clip((rgb - (1.0 - a) * 255.0) / a, 0, 255)
    out_rgb = np.where(edge[..., None], unblended, rgb)

    rgba = np.dstack([out_rgb, alpha * 255.0]).astype(np.uint8)
    tile = Image.fromarray(rgba, "RGBA")
    return tile.crop(tile.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox())


def render() -> Image.Image:
    tile = cut_out_tile(Image.open(SOURCE))
    # Fit the tile's longer side to the 824 px grid square.
    scale = TILE / max(tile.size)
    tile = tile.resize((round(tile.width * scale), round(tile.height * scale)), Image.LANCZOS)
    x = (SIZE - tile.width) // 2
    y = (SIZE - tile.height) // 2

    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    shadow.paste((0, 0, 0, 110), (x, y + 14), tile.getchannel("A"))
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(18)))
    canvas.alpha_composite(tile, (x, y))
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
