"""Generate rounded desktop icons for Windows and Linux.

The corner radius ratio matches Tencent QQ (QQ.exe), measured from its 256px
Windows icon: 53px radius / 256px side (~20.7%).

Run with:
  python3 tool/generate_desktop_icon.py
  dart run flutter_launcher_icons   # regenerates windows/runner/resources/app_icon.ico
"""

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "assets" / "icon.png"
ROUNDED = ROOT / "assets" / "icon-desktop.png"
LINUX_512 = ROOT / "packaging" / "linux" / "bugaoshan-512.png"
FLATPAK_512 = ROOT / "packaging" / "flatpak" / "bugaoshan-512.png"

RADIUS_RATIO = 53 / 256
SUPERSAMPLE = 4


def main():
    icon = Image.open(SOURCE).convert("RGBA")
    if icon.width != icon.height:
        raise SystemExit(f"{SOURCE} must be square, got {icon.size}")

    size = icon.width
    radius = round(size * RADIUS_RATIO)

    # Draw the mask at a higher resolution so the rounded corners stay smooth
    # after downscaling.
    mask_size = size * SUPERSAMPLE
    mask = Image.new("L", (mask_size, mask_size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, mask_size - 1, mask_size - 1),
        radius=radius * SUPERSAMPLE,
        fill=255,
    )
    mask = mask.resize((size, size), Image.LANCZOS)

    icon.putalpha(ImageChops.multiply(icon.getchannel("A"), mask))
    icon.save(ROUNDED, optimize=True)

    for target in (LINUX_512, FLATPAK_512):
        icon.resize((512, 512), Image.LANCZOS).save(target, optimize=True)

    print(f"Created {ROUNDED} ({size}x{size}, radius={radius})")
    print(f"Created {LINUX_512} (512x512)")
    print(f"Created {FLATPAK_512} (512x512)")


if __name__ == "__main__":
    main()
