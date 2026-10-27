"""Fetches just Godot's web export templates (about 20 MB) out of the official 1.3 GB
template bundle, reading only the parts of the zip it needs, and puts them where Godot
looks: ~/.local/share/godot/export_templates/<version>.stable/.

    python3 tools/fetch_web_templates.py [4.7.2]
"""
import os
import ssl
import struct
import sys
import urllib.request
import zlib

VERSION = sys.argv[1] if len(sys.argv) > 1 else "4.7.2"
URL = f"https://github.com/godotengine/godot/releases/download/{VERSION}-stable/Godot_v{VERSION}-stable_export_templates.tpz"
WANT = ["version.txt", "web_nothreads_release.zip", "web_nothreads_debug.zip"]
DEST = os.path.expanduser(f"~/.local/share/godot/export_templates/{VERSION}.stable")

opener = urllib.request.build_opener(
    urllib.request.HTTPSHandler(context=ssl.create_default_context(cafile=os.environ.get("SSL_CERT_FILE"))))


def get(start, end):
    request = urllib.request.Request(URL, headers={"Range": f"bytes={start}-{end}"})
    with opener.open(request, timeout=300) as response:
        return response.read()


with opener.open(urllib.request.Request(URL, method="HEAD"), timeout=60) as response:
    size = int(response.headers["Content-Length"])
# The zip's directory is at the end (zip64, as the bundle is over 4 GB uncompressed... or not).
tail = get(size - 65536 - 22, size - 1)
end = tail.rfind(b"PK\x05\x06")
dir_size, dir_at = struct.unpack("<II", tail[end + 12:end + 20])
if dir_at == 0xFFFFFFFF:
    locator = tail.rfind(b"PK\x06\x07")
    record_at = struct.unpack("<Q", tail[locator + 8:locator + 16])[0]
    dir_size, dir_at = struct.unpack("<QQ", get(record_at, record_at + 55)[40:56])
directory = get(dir_at, dir_at + dir_size - 1)
entries = {}
p = 0
while directory[p:p + 4] == b"PK\x01\x02":
    method, = struct.unpack("<H", directory[p + 10:p + 12])
    packed, unpacked = struct.unpack("<II", directory[p + 20:p + 28])
    name_len, extra_len, note_len = struct.unpack("<HHH", directory[p + 28:p + 34])
    at, = struct.unpack("<I", directory[p + 42:p + 46])
    name = directory[p + 46:p + 46 + name_len].decode()
    extra = directory[p + 46 + name_len:p + 46 + name_len + extra_len]
    q = 0
    while q < len(extra):
        tag, length = struct.unpack("<HH", extra[q:q + 4])
        if tag == 1:
            values = list(struct.unpack(f"<{length // 8}Q", extra[q + 4:q + 4 + length]))
            if unpacked == 0xFFFFFFFF: unpacked = values.pop(0)
            if packed == 0xFFFFFFFF: packed = values.pop(0)
            if at == 0xFFFFFFFF: at = values.pop(0)
        q += 4 + length
    entries[os.path.basename(name)] = (method, packed, at)
    p += 46 + name_len + extra_len + note_len

os.makedirs(DEST, exist_ok=True)
for name in WANT:
    method, packed, at = entries[name]
    header = get(at, at + 29)
    name_len, extra_len = struct.unpack("<HH", header[26:30])
    start = at + 30 + name_len + extra_len
    data = get(start, start + packed - 1)
    if method == 8:
        data = zlib.decompress(data, -15)
    with open(os.path.join(DEST, name), "wb") as out:
        out.write(data)
    print(f"{name}: {len(data)} bytes")
print("Web templates in", DEST)
