#!/usr/bin/env python3
"""
Generate Sakrylle launcher icons from the cherry-blossom source PNG.

Source: ~/Documents/Design/Material/cherry-blossom_15273565.png
        (512x512 transparent PNG, pink-gradient sakura line art)

Outputs:
  - icons/ios/AppIcon.appiconset/icon-*.png        (16 sizes per Contents.json)
  - icons/android/playstore-icon.png               (1024x1024 with page-bg)
  - icons/android/mipmap-{ldpi,mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/
        ic_launcher.png             (square with bg)
        ic_launcher_round.png       (same as square; circular crop done at runtime)
        ic_launcher_foreground.png  (transparent, ~60% scale)
        ic_launcher_background.png  (solid bg)
        ic_launcher_monochrome.png  (white silhouette, transparent)
  - assets/icon.png                                (1024x1024 master)
  - assets/android-icon-foreground.png             (1024 transparent, ~60% scale)
  - assets/android-icon-background.png             (1024 solid bg)
  - assets/android-icon-monochrome.png             (1024 white-only, transparent)
  - assets/splash-icon.png                         (1242x2436, transparent, ~50%)
  - assets/favicon.png                             (64x64)

iOS Contents.json filenames are not changed; only the PNG bytes behind them are
refreshed.

Bundle bg: #f5f1fa (Sakrylle Monet purple page tone, matches app.json splash bg).
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageOps

REPO_ROOT = Path(__file__).resolve().parent.parent
SOURCE = Path.home() / "Documents/Design/Material/cherry-blossom_15273565.png"
BG_HEX = "#f5f1fa"


def hex_to_rgb(hex_color: str) -> tuple[int, int, int]:
    hex_color = hex_color.lstrip("#")
    return (
        int(hex_color[0:2], 16),
        int(hex_color[2:4], 16),
        int(hex_color[4:6], 16),
    )


BG_RGB = hex_to_rgb(BG_HEX)


def load_source() -> Image.Image:
    if not SOURCE.exists():
        raise SystemExit(f"Source logo not found: {SOURCE}")

    return Image.open(SOURCE).convert("RGBA")


def composite_on_bg(source: Image.Image, size: int, scale: float = 0.75) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), BG_RGB + (255,))
    target = max(int(size * scale), 1)
    fitted = ImageOps.contain(source, (target, target), Image.LANCZOS)
    offset = ((size - fitted.width) // 2, (size - fitted.height) // 2)
    canvas.alpha_composite(fitted, dest=offset)
    return canvas.convert("RGB")


def transparent_centered(source: Image.Image, size: int, scale: float) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    target = max(int(size * scale), 1)
    fitted = ImageOps.contain(source, (target, target), Image.LANCZOS)
    offset = ((size - fitted.width) // 2, (size - fitted.height) // 2)
    canvas.alpha_composite(fitted, dest=offset)
    return canvas


def to_monochrome(source: Image.Image, size: int, scale: float) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    target = max(int(size * scale), 1)
    fitted = ImageOps.contain(source, (target, target), Image.LANCZOS)
    alpha = fitted.split()[-1]
    white = Image.new("RGBA", fitted.size, (255, 255, 255, 0))
    white.putalpha(alpha)
    offset = ((size - white.width) // 2, (size - white.height) // 2)
    canvas.alpha_composite(white, dest=offset)
    return canvas


def solid_bg(size: int) -> Image.Image:
    return Image.new("RGB", (size, size), BG_RGB)


def save(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if img.mode == "RGBA":
        img.save(path, "PNG", optimize=True)
    else:
        img.convert("RGB").save(path, "PNG", optimize=True)
    print(f"  -> {path.relative_to(REPO_ROOT)}")


IOS_ICONS: list[tuple[str, int]] = [
    ("icon-20@2x.png", 40),
    ("icon-20@3x.png", 60),
    ("icon-29@2x.png", 58),
    ("icon-29@3x.png", 87),
    ("icon-38@2x.png", 76),
    ("icon-38@3x.png", 114),
    ("icon-40@2x.png", 80),
    ("icon-40@3x.png", 120),
    ("icon-60@2x.png", 120),
    ("icon-60@3x.png", 180),
    ("icon-64@2x.png", 128),
    ("icon-64@3x.png", 192),
    ("icon-68@2x.png", 136),
    ("icon-76@2x.png", 152),
    ("icon-83.5@2x.png", 167),
    ("icon-1024.png", 1024),
]

ANDROID_DENSITIES: list[tuple[str, int]] = [
    ("ldpi", 36),
    ("mdpi", 48),
    ("hdpi", 72),
    ("xhdpi", 96),
    ("xxhdpi", 144),
    ("xxxhdpi", 192),
]


def main() -> None:
    print(f"Loading source: {SOURCE}")
    source = load_source()
    print(f"Source size: {source.size}")
    print(f"Background:  {BG_HEX}")

    print("\n[iOS] AppIcon.appiconset")
    ios_dir = REPO_ROOT / "icons/ios/AppIcon.appiconset"
    for filename, size in IOS_ICONS:
        save(composite_on_bg(source, size, scale=0.75), ios_dir / filename)

    print("\n[Android] mipmap density buckets")
    android_root = REPO_ROOT / "icons/android"
    for density, size in ANDROID_DENSITIES:
        d = android_root / f"mipmap-{density}"
        save(composite_on_bg(source, size, 0.75), d / "ic_launcher.png")
        save(composite_on_bg(source, size, 0.75), d / "ic_launcher_round.png")
        save(transparent_centered(source, size, 0.6), d / "ic_launcher_foreground.png")
        save(solid_bg(size), d / "ic_launcher_background.png")
        save(to_monochrome(source, size, 0.6), d / "ic_launcher_monochrome.png")

    print("\n[Android] playstore-icon")
    save(composite_on_bg(source, 1024, 0.75), android_root / "playstore-icon.png")

    print("\n[Expo assets]")
    assets = REPO_ROOT / "assets"
    save(composite_on_bg(source, 1024, 0.75), assets / "icon.png")
    save(transparent_centered(source, 1024, 0.6), assets / "android-icon-foreground.png")
    save(solid_bg(1024), assets / "android-icon-background.png")
    save(to_monochrome(source, 1024, 0.6), assets / "android-icon-monochrome.png")
    save(transparent_centered(source, 1024, 0.5), assets / "splash-icon.png")
    save(composite_on_bg(source, 64, 0.75), assets / "favicon.png")

    print("\nDone.")


if __name__ == "__main__":
    main()
