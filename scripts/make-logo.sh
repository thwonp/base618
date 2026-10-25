#!/bin/sh
# SPDX-License-Identifier: MIT
# Any image -> boot-logo.ppm, the second boot logo (docs/boot-logo.md): a
# binary PPM of at most 224 colours, no larger than the 720x720 panel,
# transparency on black. Needs ImageMagick 7 (magick), on the PC.
#
#   make-logo.sh IN [OUT]    (default OUT: boot-logo.ppm)
#
# The kernel centres it on black, so leave the black margin out: a tight
# wordmark draws faster than the same wordmark on a full-screen canvas.
set -eu
IN=${1:?usage: make-logo.sh IN [OUT]}
OUT=${2:-boot-logo.ppm}
magick "$IN" -background black -alpha remove -alpha off -resize '720x720>' \
	-dither None -colors 224 -depth 8 "ppm:$OUT"
n=$(magick identify -format '%k' "$OUT")
[ "$n" -le 224 ] || { echo "make-logo: $n colours after reduction, the kernel takes 224" >&2; exit 1; }
echo "$OUT: $(magick identify -format '%wx%h' "$OUT"), $n colours"
