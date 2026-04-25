"""Generate the NoIReject app icon (1024x1024 PNG)."""
from PIL import Image, ImageDraw, ImageFilter
import math
import os

SIZE = 1024
OUT_DIR = os.path.dirname(os.path.abspath(__file__))
OUT_PATH = os.path.join(OUT_DIR, "AppIcon-1024.png")

# Calming sunrise gradient: warm peach → soft lavender
TOP    = (255, 191, 162)   # peach
MIDDLE = (245, 165, 200)   # rose
BOTTOM = (160, 145, 230)   # lavender


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def gradient_color(t: float) -> tuple:
    """t in [0, 1] from top to bottom."""
    if t < 0.5:
        return lerp(TOP, MIDDLE, t / 0.5)
    return lerp(MIDDLE, BOTTOM, (t - 0.5) / 0.5)


def main():
    img = Image.new("RGB", (SIZE, SIZE), (255, 255, 255))
    px = img.load()
    for y in range(SIZE):
        color = gradient_color(y / (SIZE - 1))
        for x in range(SIZE):
            px[x, y] = color

    # Overlay layer for shapes (RGBA so we can blend)
    overlay = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)

    cx, cy = SIZE // 2, int(SIZE * 0.58)

    # Soft glow behind the central mark
    glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow)
    glow_r = int(SIZE * 0.32)
    gdraw.ellipse(
        [cx - glow_r, cy - glow_r, cx + glow_r, cy + glow_r],
        fill=(255, 255, 255, 90),
    )
    glow = glow.filter(ImageFilter.GaussianBlur(radius=80))
    overlay = Image.alpha_composite(overlay, glow)
    draw = ImageDraw.Draw(overlay)

    # Sun / moon disk
    disk_r = int(SIZE * 0.16)
    disk_y = int(SIZE * 0.40)
    draw.ellipse(
        [cx - disk_r, disk_y - disk_r, cx + disk_r, disk_y + disk_r],
        fill=(255, 252, 240, 230),
    )

    # Three "horizon" arcs / breath waves underneath
    wave_color = (255, 255, 255, 200)
    wave_y_start = int(SIZE * 0.65)
    for i, (width_frac, thickness) in enumerate(
        [(0.74, 28), (0.58, 24), (0.42, 20)]
    ):
        w = int(SIZE * width_frac)
        y = wave_y_start + i * int(SIZE * 0.07)
        # Draw a gentle arc (ellipse stroke)
        draw.arc(
            [cx - w // 2, y - thickness * 2, cx + w // 2, y + thickness * 2],
            start=180, end=360,
            fill=wave_color, width=thickness,
        )

    # A single small sparkle (top-left) to add a touch of "moments"
    def sparkle(x, y, size, alpha=200):
        s = size
        col = (255, 255, 255, alpha)
        draw.polygon(
            [(x, y - s), (x + s * 0.3, y - s * 0.3),
             (x + s, y), (x + s * 0.3, y + s * 0.3),
             (x, y + s), (x - s * 0.3, y + s * 0.3),
             (x - s, y), (x - s * 0.3, y - s * 0.3)],
            fill=col,
        )

    sparkle(int(SIZE * 0.22), int(SIZE * 0.22), 26, alpha=210)
    sparkle(int(SIZE * 0.80), int(SIZE * 0.18), 18, alpha=170)
    sparkle(int(SIZE * 0.84), int(SIZE * 0.30), 12, alpha=140)

    # Composite the overlay onto the gradient
    base = img.convert("RGBA")
    final = Image.alpha_composite(base, overlay).convert("RGB")
    final.save(OUT_PATH, "PNG", optimize=True)
    print(f"Wrote {OUT_PATH}")


if __name__ == "__main__":
    main()
