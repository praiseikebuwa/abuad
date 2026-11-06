#!/usr/bin/env python3
"""
scripts/upload_sticker_folder.py
================================
CLI Command to upload stickers from C:\\Users\\pikeb\\Desktop\\abuad\\sticker
directly to Cloudflare R2 and Neon DB without embedding seeds into Flutter code.
"""

import subprocess
import sys
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

BACKEND_DIR = Path(__file__).resolve().parent.parent / "backend"

def main():
    print("=" * 60)
    print("🚀 Running sticker batch upload command from folder:")
    print("   C:\\Users\\pikeb\\Desktop\\abuad\\sticker")
    print("=" * 60)

    res = subprocess.run(
        ["node", "scripts/upload_all_stickers.js"],
        cwd=str(BACKEND_DIR),
        text=True,
    )
    if res.returncode == 0:
        print("\n✅ Sticker upload and database synchronization completed successfully!")
    else:
        print(f"\n❌ Script exited with code {res.returncode}")
        sys.exit(res.returncode)

if __name__ == "__main__":
    main()
