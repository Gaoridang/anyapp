#!/usr/bin/env python3
"""Generate minimal placeholder AppIcon PNGs for CI/TestFlight uploads."""

from __future__ import annotations

import json
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ICON_SET = ROOT / "anyapp" / "Assets.xcassets" / "AppIcon.appiconset"

SIZES = {
    "AppIcon-40.png": 40,
    "AppIcon-60.png": 60,
    "AppIcon-58.png": 58,
    "AppIcon-87.png": 87,
    "AppIcon-80.png": 80,
    "AppIcon-120.png": 120,
    "AppIcon-180.png": 180,
    "AppIcon-152.png": 152,
    "AppIcon-167.png": 167,
    "AppIcon-1024.png": 1024,
}


def write_png(path: Path, width: int, height: int, rgb: tuple[int, int, int]) -> None:
    row = bytes([rgb[0], rgb[1], rgb[2], 255]) * width
    raw = b"".join(b"\x00" + row for _ in range(height))
    compressed = zlib.compress(raw, 9)

    def chunk(tag: bytes, data: bytes) -> bytes:
        crc = zlib.crc32(tag + data) & 0xFFFFFFFF
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", crc)

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", ihdr)
    png += chunk(b"IDAT", compressed)
    png += chunk(b"IEND", b"")
    path.write_bytes(png)


def main() -> None:
    ICON_SET.mkdir(parents=True, exist_ok=True)
    for filename, size in SIZES.items():
        write_png(ICON_SET / filename, size, size, (52, 120, 246))

    contents = {
        "images": [
            {"filename": "AppIcon-40.png", "idiom": "iphone", "scale": "2x", "size": "20x20"},
            {"filename": "AppIcon-60.png", "idiom": "iphone", "scale": "3x", "size": "20x20"},
            {"filename": "AppIcon-58.png", "idiom": "iphone", "scale": "2x", "size": "29x29"},
            {"filename": "AppIcon-87.png", "idiom": "iphone", "scale": "3x", "size": "29x29"},
            {"filename": "AppIcon-80.png", "idiom": "iphone", "scale": "2x", "size": "40x40"},
            {"filename": "AppIcon-120.png", "idiom": "iphone", "scale": "3x", "size": "40x40"},
            {"filename": "AppIcon-120.png", "idiom": "iphone", "scale": "2x", "size": "60x60"},
            {"filename": "AppIcon-180.png", "idiom": "iphone", "scale": "3x", "size": "60x60"},
            {"filename": "AppIcon-152.png", "idiom": "ipad", "scale": "2x", "size": "76x76"},
            {"filename": "AppIcon-167.png", "idiom": "ipad", "scale": "2x", "size": "83.5x83.5"},
            {"filename": "AppIcon-1024.png", "idiom": "ios-marketing", "scale": "1x", "size": "1024x1024"},
        ],
        "info": {"author": "xcode", "version": 1},
    }
    (ICON_SET / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n", encoding="utf-8")
    print(f"Generated {len(SIZES)} icons in {ICON_SET}")


if __name__ == "__main__":
    main()