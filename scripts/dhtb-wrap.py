#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Wrap u-boot-dtb.bin in the Unisoc DHTB container the RG Rotate SPL loads from
# SD p1 (the same format as Armbian's sprd-ums512 uboot_custom_postprocess).
#   dhtb-wrap.py out/u-boot-dtb.bin uboot_dhtb.img
# Flash: dd if=uboot_dhtb.img of=/dev/mmcblk0p1 bs=512 conv=fsync; sync;
#        echo 3 > /proc/sys/vm/drop_caches; read back count=size/512 and compare sha256.
import hashlib, struct, sys
payload = open(sys.argv[1], "rb").read()
payload += b"\0" * ((-len(payload)) % 512)
hdr = bytearray(512)
hdr[0:4] = b"DHTB"
hdr[4:8] = struct.pack("<I", 1)
hdr[8:0x28] = hashlib.sha256(payload).digest()
hdr[0x30:0x34] = struct.pack("<I", len(payload))
open(sys.argv[2], "wb").write(bytes(hdr) + payload)
print("DHTB", len(payload), hashlib.sha256(bytes(hdr) + payload).hexdigest()[:16])
