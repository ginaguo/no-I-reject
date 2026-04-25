"""Generate the NoIReject app icon: the word 'No' with a strikethrough."""
from PIL import Image, ImageDraw, ImageFont
import os

SIZE = 1024
OUT_DIR = os.path.dirname(os.path.abspath(__file__))
OUT_PATH = os.path.join(OUT_DIR, "AppIcon-1024.png")

BG    = (255, 255, 255)   # clean white
INK   = (40, 40, 50)      # near-black for "No"
SLASH = (230, 90, 90)     # warm red strikethrough


def find_font(size: int) -> ImageFont.FreeTypeFont:
    candidates = [
        "/System/Library/Fonts/Supplemental/Avenir Next.ttc",
        "/System/Library/Fonts/HelveticaNeue.ttc",
        "/System/Library/Fonts/Helvetica.ttc",
        "/Library/Fonts/Arial Bold.ttf",
        "/System/Library/Fonts/SFNSRounded.ttf",
        "/System/Library/Fonts/SFNS.ttf",
    ]
    for path in candidates:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except Exception:
                continue
    return ImageFont.load_default()


def main():
    img = Image.new("RGB", (SIZE, SIZE), BG)
    draw = ImageDraw.Draw(img)

    text = "No"
    font = find_font(int(SIZE * 0.62))
    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    tx = (SIZE - tw) // 2 - bbox[0]
    ty = (SIZE - th) // 2 - bbox[1]
    draw.text((tx, ty), text, fill=INK, font=font)

    # Diagonal strikethrough from bottom-left to top-right
    pad = int(SIZE * 0.14)
    line_w = int(SIZE * 0.07)
    draw.line(
        [(pad, SIZE - pad), (SIZE - pad, pad)],
        fill=SLASH,
        width=line_w,
    )

    img.save(OUT_PATH, "PNG", optimize=True)
    print(f"Wrote {OUT_PATH}")


if __name__ == "__main__":
    main()
