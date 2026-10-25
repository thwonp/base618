#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Check a DHTB image (SPL, U-Boot) before writing it: the BootROM and the SPL
# read the payload length at 0x30 and compare its SHA-256 with the one at 0x08.
#   check-dhtb.py IMAGE...      exit 0 only if every image matches
import hashlib, struct, sys
bad = 0
for p in sys.argv[1:]:
    d = open(p, "rb").read()
    if d[0:4] != b"DHTB":
        print(f"{p}: not a DHTB image"); bad = 1; continue
    size = struct.unpack("<I", d[0x30:0x34])[0]
    ok = hashlib.sha256(d[0x200:0x200 + size]).digest() == d[8:0x28]
    print(f"{p}: {len(d)} bytes, payload {size}, {'MATCH' if ok else 'MISMATCH - do not flash'}")
    bad |= not ok
sys.exit(bad)
