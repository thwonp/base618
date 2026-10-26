#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# The two download-mode loaders (FDL1, FDL2) out of a ums512 Unisoc .pac - the unit's
# stock firmware or GammaOS's - so flash-spl.sh can talk to the BootROM without base618
# shipping Unisoc's binaries.
#   pac-fdl.py PAC OUTDIR       writes OUTDIR/fdl1.bin and OUTDIR/fdl2.bin
# PAC (BP_R1.0.0 / BP_R2.0.1): a 2124-byte header, then 2580-byte file entries, strings
# UTF-16LE. The FDLs come first in the file; entries past 4 GiB can have a wrong offset
# (packers drop the high word), so those are refused, not read.
import os, struct, sys
HDR = struct.Struct("<44s I I 512s 512s I I I I I I I 200s I I I 800s I H H")
ENT = struct.Struct("<I 512s 512s 504s I I I I I I I I 5I 996s")
s = lambda b: b.decode("utf-16-le", "replace").split("\0", 1)[0]
def die(msg):
    sys.exit(f"pac-fdl: {msg}")
if len(sys.argv) != 3:
    die("usage: pac-fdl.py PAC OUTDIR")
pac, out = sys.argv[1:]
size = os.path.getsize(pac)
with open(pac, "rb") as f:
    if size < HDR.size:
        die(f"{pac} is not a Unisoc .pac")
    h = HDR.unpack(f.read(HDR.size))
    if s(h[0]) not in ("BP_R1.0.0", "BP_R2.0.1"):
        die(f"{pac} is not a Unisoc .pac")
    if not s(h[3]).startswith("ums512"):
        die(f"{pac} is for {s(h[3])}, not a ums512 (T618) unit")
    f.seek(h[6])
    ents = {}
    for _ in range(h[5]):
        e = ENT.unpack(f.read(ENT.size))
        if e[0] != ENT.size:
            die("unknown file entry format")
        ents[s(e[1])] = (e[4] << 32 | e[6], e[5] << 32 | e[9])  # size, offset
    for pid, fn in (("FDL", "fdl1.bin"), ("FDL2", "fdl2.bin")):
        n, off = ents.get(pid, (0, 0))
        if not n or off + n > min(size, 1 << 32):
            die(f"no usable {pid} in {pac}")
        f.seek(off)
        with open(os.path.join(out, fn), "wb") as o:
            o.write(f.read(n))
