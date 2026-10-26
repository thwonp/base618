#!/bin/sh
# SPDX-License-Identifier: MIT
# The art for base618's two screens, on the PC (ImageMagick 7):
#   res/boot-logo.ppm   the kernel's boot logo: "base618", white, Lato Bold (the
#                       screen's text font, larger)
#   res/screen.pgm      base618-screen's "no CFW installed" screen (coverage)
# Either can be any image: see docs/boot-logo.md and src/base618-screen.c.
set -eu
R=$(cd "$(dirname "$0")/.." && pwd)/res
T=$(mktemp -d "${TMPDIR:-/var/tmp}/make-screen.XXXXXX")
trap 'rm -rf "$T"' EXIT
magick -background black -fill white -font "$R/lato-bold.ttf" -pointsize 110 label:base618 \
	-trim +repage "$T/logo.png"
"$(dirname "$0")/make-logo.sh" "$T/logo.png" "$R/boot-logo.ppm"
magick -background black -fill white -font "$R/lato.ttf" -pointsize 40 \
	label:'No CFW installed' -trim +repage "$T/l1.png"
magick -background black -fill white -font "$R/lato.ttf" -pointsize 32 \
	label:'Connect to PC over USB Serial' -trim +repage "$T/l2.png"
magick "$T/logo.png" \( -size 1x70 xc:black \) "$T/l1.png" \( -size 1x28 xc:black \) "$T/l2.png" \
	-background black -gravity center -append -colorspace gray -depth 8 "$R/screen.pgm"
echo "res/screen.pgm: $(magick identify -format '%wx%h' "$R/screen.pgm")"
