#!/usr/bin/env bash
# Build a per-machine (all users) NSIS installer from the official Element Desktop setup.
# The official Element Setup.exe is a per-user Squirrel installer. Element's MSI
# (perMachine) is distributed only to Element Server Suite customers.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
VERSION="${VERSION:-1.12.30}"
EXPECTED_SHA256="${EXPECTED_SHA256:-b9ac9617acfa667eb5470e67e5db744d3b595b35c285100a53ad17719f7cc6d3}"
URL="${URL:-https://packages.element.io/desktop/install/win32/x64/Element%20Setup%20${VERSION}.exe}"

WORK="${ROOT}/work"
DIST="${ROOT}/dist"
SETUP="${WORK}/ElementSetup-${VERSION}.exe"
NUPKG="${WORK}/element-desktop-${VERSION}-full.nupkg"
PAYLOAD="${WORK}/payload"
ICON="${WORK}/element.ico"
OUT="${DIST}/Element-${VERSION}-AllUsers-x64.exe"

mkdir -p "$WORK" "$DIST"

if [[ ! -f "$SETUP" ]]; then
  echo "Downloading official Element Setup ${VERSION}"
  curl -fL --retry 3 --retry-delay 2 -o "$SETUP.partial" "$URL"
  mv "$SETUP.partial" "$SETUP"
fi

actual="$(sha256sum "$SETUP" | awk '{print $1}')"
if [[ "$actual" != "$EXPECTED_SHA256" ]]; then
  echo "SHA256 mismatch for ${SETUP}" >&2
  echo "  expected ${EXPECTED_SHA256}" >&2
  echo "  actual   ${actual}" >&2
  exit 1
fi
echo "Official setup SHA256 OK: ${actual}"

python3 - "$SETUP" "$NUPKG" "$PAYLOAD" "$ICON" <<'PY'
import io
import os
import struct
import sys
import zipfile
import zlib

setup_path, nupkg_path, payload_dir, icon_path = sys.argv[1:]
entry_name = os.path.basename(nupkg_path).encode()

with open(setup_path, "rb") as handle:
    blob = handle.read()

start = 0
extracted = None
while True:
    index = blob.find(entry_name, start)
    if index < 0:
        break
    header = index - 30
    if header >= 0 and blob[header:header + 4] == b"PK\x03\x04":
        method = struct.unpack_from("<H", blob, header + 8)[0]
        compressed_size, uncompressed_size = struct.unpack_from("<II", blob, header + 18)
        name_len, extra_len = struct.unpack_from("<HH", blob, header + 26)
        name = blob[header + 30:header + 30 + name_len]
        if name == entry_name and compressed_size != 0xFFFFFFFF:
            data_start = header + 30 + name_len + extra_len
            compressed = blob[data_start:data_start + compressed_size]
            if method == 0:
                extracted = compressed
            elif method == 8:
                extracted = zlib.decompress(compressed, -15)
            else:
                raise SystemExit(f"unsupported zip method {method}")
            if uncompressed_size and len(extracted) != uncompressed_size:
                raise SystemExit(
                    f"nupkg size mismatch: got {len(extracted)} expected {uncompressed_size}"
                )
            break
    start = index + 1

if extracted is None:
    raise SystemExit(f"did not find {entry_name.decode()} inside the official setup")

with open(nupkg_path, "wb") as handle:
    handle.write(extracted)
print(f"extracted nupkg {len(extracted)} bytes")

os.makedirs(payload_dir, exist_ok=True)
prefix = "lib/net45/"
count = 0
with zipfile.ZipFile(io.BytesIO(extracted)) as archive:
    for info in archive.infolist():
        if not info.filename.startswith(prefix) or info.is_dir():
            continue
        relative = info.filename[len(prefix):]
        if not relative or relative.endswith("/"):
            continue
        destination = os.path.join(payload_dir, *relative.split("/"))
        os.makedirs(os.path.dirname(destination), exist_ok=True)
        with archive.open(info, "r") as source, open(destination, "wb") as target:
            while True:
                chunk = source.read(1024 * 1024)
                if not chunk:
                    break
                target.write(chunk)
        count += 1

exe_path = os.path.join(payload_dir, "Element.exe")
if not os.path.isfile(exe_path):
    raise SystemExit("payload is missing Element.exe")
with open(exe_path, "rb") as handle:
    magic = handle.read(2)
    handle.seek(0x3C)
    pe_offset = struct.unpack("<I", handle.read(4))[0]
    handle.seek(pe_offset)
    pe = handle.read(6)
if magic != b"MZ" or pe[:4] != b"PE\x00\x00":
    raise SystemExit("Element.exe is not a PE executable")
machine = struct.unpack("<H", pe[4:6])[0]
if machine != 0x8664:
    raise SystemExit(f"Element.exe is not x64 (machine 0x{machine:04x})")
print(f"payload files: {count}")

icon_png = os.path.join(payload_dir, "resources", "build", "icon.png")
if not os.path.isfile(icon_png):
    raise SystemExit(f"missing icon {icon_png}")
from PIL import Image
image = Image.open(icon_png).convert("RGBA")
sizes = []
for size in (16, 24, 32, 48, 64, 128, 256):
    sizes.append(image.resize((size, size), Image.Resampling.LANCZOS))
sizes[-1].save(icon_path, format="ICO", append_images=sizes[:-1])
print(f"wrote {icon_path}")
PY

echo "Compiling NSIS installer"
makensis -NOCD \
  -DAPP_VERSION="$VERSION" \
  -DPAYLOAD_DIR="$PAYLOAD" \
  -DOUTFILE="$OUT" \
  -DICON_FILE="$ICON" \
  "$ROOT/installer.nsi"

sha256sum "$OUT" | tee "${OUT}.sha256"
file "$OUT"
ls -lh "$OUT"
echo "Built $OUT"
