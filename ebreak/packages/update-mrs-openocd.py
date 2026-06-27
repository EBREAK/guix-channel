#!/usr/bin/env python3
"""Update the MounRiver Studio OpenOCD binary source URL and hash.

MounRiver's download links carry short-lived signatures.  This helper
reproduces the AUR logic:

  1. Query the API for the latest Linux toolchain resource ID.
  2. Ask the API for a signed download URL.
  3. Download the tarball next to this script.
  4. Compute its Guix base32 hash.
  5. Patch ebreak/packages/mrs-openocd.scm with the new URI and hash.

Usage:
    python3 update-mrs-openocd.py
"""

import json
import re
import subprocess
import sys
import urllib.request
from pathlib import Path

API_INFO = "http://api.mounriver.com/mountriver/api/version/fetchRecentOpenOcd?osType=LINUX&lang=zh"
API_URL = "https://api.mounriver.com/mountriver/api/version/getDownloadUrl?resourceId={res_id}"
SCM_FILE = "mrs-openocd.scm"
TARBALL = "MRS_Toolchain_Linux_X64_V240.tar.xz"


def fetch_json(url: str) -> dict:
    with urllib.request.urlopen(url, timeout=60) as resp:
        return json.loads(resp.read())


def guix_hash(path: Path) -> str:
    """Return the Guix base32 hash of a file."""
    out = subprocess.check_output(["guix", "hash", str(path)], text=True)
    return out.strip()


def main() -> int:
    script_dir = Path(__file__).resolve().parent
    scm_path = script_dir / SCM_FILE
    tarball_path = script_dir / TARBALL

    if not scm_path.exists():
        print(f"error: {scm_path} not found", file=sys.stderr)
        return 1

    print("Querying MounRiver API for latest Linux toolchain...")
    info = fetch_json(API_INFO)
    result = info.get("result", [])
    if not result:
        print("error: API returned no results", file=sys.stderr)
        return 1

    entry = result[0]
    res_id = entry.get("softResId") or entry.get("id")
    filename = entry.get("fileName", TARBALL)
    version = entry.get("version", "unknown")
    print(f"Found version {version}, resource ID {res_id}, filename {filename}")

    print("Fetching signed download URL...")
    dl_json = fetch_json(API_URL.format(res_id=res_id))
    dl_url = dl_json.get("result") or dl_json.get("data")
    if not dl_url or not dl_url.startswith("http"):
        print(f"error: invalid download URL: {dl_url}", file=sys.stderr)
        return 1
    print(f"Download URL: {dl_url}")

    print(f"Downloading {filename}...")
    urllib.request.urlretrieve(dl_url, tarball_path)
    print(f"Saved to {tarball_path}")

    print("Computing Guix hash...")
    tarball_hash = guix_hash(tarball_path)
    print(f"Hash: {tarball_hash}")

    print(f"Patching {scm_path}...")
    text = scm_path.read_text(encoding="utf-8")

    text = re.sub(
        r'\(uri "[^"]+"\)',
        f'(uri "{dl_url}")',
        text,
        count=1,
    )
    text = re.sub(
        r'\(base32\s+"[^"]+"\)',
        f'(base32\n         "{tarball_hash}")',
        text,
        count=1,
    )

    scm_path.write_text(text, encoding="utf-8")
    print("Done.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
