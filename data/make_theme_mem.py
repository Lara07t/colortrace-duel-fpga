#!/usr/bin/env python3
import sys
from pathlib import Path
from PIL import Image, ImageOps

# Smaller tile to save BRAM
TARGET_W = 128
TARGET_H = 128
NUM_COLORS = 256

SCRIPT_DIR = Path(__file__).resolve().parent  # usually the data/ folder


def rgb_to_rgb565(r, g, b):
    """Convert 8-bit/channel RGB to 16-bit RGB565."""
    r5 = r >> 3
    g6 = g >> 2
    b5 = b >> 3
    return (r5 << 11) | (g6 << 5) | b5


def make_mem(input_fname, base_name):
    input_path = Path(input_fname)
    if not input_path.is_file():
        raise FileNotFoundError(f"Input image not found: {input_path}")

    # --- Load image and fit into 64×64 canvas ---
    img = Image.open(input_path).convert("RGBA")

    # scale down while keeping aspect ratio, max 64×64
    img = ImageOps.contain(img, (TARGET_W, TARGET_H))

    # center on background (use top-left pixel color as bg)
    bg_color = img.getpixel((0, 0))
    canvas = Image.new("RGBA", (TARGET_W, TARGET_H), bg_color)
    cx = (TARGET_W - img.width) // 2
    cy = (TARGET_H - img.height) // 2
    canvas.paste(img, (cx, cy))

    # --- Convert to palettized image with 256 colors ---
    pal_img = canvas.convert("P", palette=Image.ADAPTIVE, colors=NUM_COLORS)

    # Preview
    preview_path = SCRIPT_DIR / f"preview_{base_name}.png"
    pal_img.save(preview_path)
    print(f"[{base_name}] preview saved to {preview_path}")

    # --- Write palette.mem (256 lines, 16-bit RGB565 hex) ---
    palette = pal_img.getpalette()[:NUM_COLORS * 3]  # first 256 colors

    palette_path = SCRIPT_DIR / f"{base_name}_palette.mem"
    with palette_path.open("w") as f:
        for i in range(NUM_COLORS):
            r = palette[3 * i + 0]
            g = palette[3 * i + 1]
            b = palette[3 * i + 2]
            rgb565 = rgb_to_rgb565(r, g, b)
            f.write(f"{rgb565:04x}\n")
    print(f"[{base_name}] palette written to {palette_path}")

    # --- Write image.mem (one 8-bit index per pixel, row-major) ---
    pixels = list(pal_img.getdata())

    image_path = SCRIPT_DIR / f"{base_name}_image.mem"
    with image_path.open("w") as f:
        for p in pixels:
            f.write(f"{p:02x}\n")
    print(f"[{base_name}] image indices written to {image_path}")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python3 make_theme_mem.py <input.png> <base_name>")
        sys.exit(1)

    input_fname = sys.argv[1]
    base_name = sys.argv[2]
    make_mem(input_fname, base_name)
