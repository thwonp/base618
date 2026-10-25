#!/bin/sh
# SPDX-License-Identifier: MIT
# The CM4's boot stub, from source: the 31 words of sp_loader[] in Unisoc's
# GPL U-Boot (board/spreadtrum/ums512_1h10_go/cp_boot.h), little-endian - what
# the stock U-Boot copies to the CM4's IRAM before it starts pm_sys. The
# kernel's pm_sys remoteproc loads it as sprd/pm_bootcode.bin. Unlike pm_sys
# itself (extract-firmware.sh), this one can ship: it is GPL source.
#
#   build-pm-bootcode.sh UBOOT_SRC [OUT]   (default OUT: pm_bootcode.bin)
set -eu
SRC=${1:?usage: build-pm-bootcode.sh UBOOT_SRC [OUT]}/board/spreadtrum/ums512_1h10_go/cp_boot.h
OUT=${2:-pm_bootcode.bin}
[ -r "$SRC" ] || { echo "missing $SRC" >&2; exit 1; }
mkdir -p "$(dirname "$OUT")"
python3 - "$SRC" "$OUT" <<'PY'
import re, struct, sys
src, out = sys.argv[1], sys.argv[2]
body = re.search(r'sp_loader\[\]\s*=\s*\{([^}]*)\}', open(src).read()).group(1)
words = [int(w, 16) for w in re.findall(r'0x[0-9a-fA-F]+', body)]
if len(words) != 31:
    sys.exit(f'sp_loader[]: {len(words)} words, expected 31')
open(out, 'wb').write(struct.pack('<31I', *words))
PY
md5sum "$OUT"
