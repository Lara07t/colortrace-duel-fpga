#!/usr/bin/env python3
import sys
from pathlib import Path
from PIL import Image, ImageOps

NUM_COLORS = 256

def make_tile(input_fname, base_name, target_w=64, target_h=64):
    script_dir = Path(__file__).resolve().parent

    input_path = script_dir / input_fname
    if not input_path.is_file():
        raise FileNotFoundError(f"Input image not found: {input_path}")

    img = Image.open(input_path).convert("RGBA")

    img = ImageOps.contain(img, (target_w, target_h))

    bg_color = img.getpixel((0, 0))
    canvas = Image.new("RGBA", (target_w, target_h), bg_color)
    cx = (target_w - img.width) // 2
    cy = (target_h - img.height) // 2
    canvas.paste(img, (cx, cy), img)

    pal_img = canvas.convert("P", palette=Image.ADAPTIVE, colors=NUM_COLORS)

    preview_path = script_dir / f"preview_{base_name}.png"
    pal_img.save(preview_path)
    print(f"[{base_name}] preview saved to {preview_path}")

    palette = pal_img.getpalette()[:NUM_COLORS * 3]

    palette_path = script_dir / f"{base_name}_palette.mem"
    with palette_path.open("w") as f:
        for i in range(NUM_COLORS):
            r = palette[3 * i + 0]
            g = palette[3 * i + 1]
            b = palette[3 * i + 2]
            rgb24 = (r << 16) | (g << 8) | b  # 0xRRGGBB
            f.write(f"{rgb24:06x}\n")
    print(f"[{base_name}] palette written to {palette_path}")

    pixels = list(pal_img.getdata())
    image_path = script_dir / f"{base_name}_image.mem"
    with image_path.open("w") as f:
        for p in pixels:
            f.write(f"{p:02x}\n")
    print(f"[{base_name}] image indices written to {image_path}")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python3 make_tile_mem.py <input.png> <base_name> [w h]")
        sys.exit(1)

    input_fname = sys.argv[1]
    base_name = sys.argv[2]

    if len(sys.argv) >= 5:
        w = int(sys.argv[3])
        h = int(sys.argv[4])
    else:
        w = 64
        h = 64

    make_tile(input_fname, base_name, w, h)
