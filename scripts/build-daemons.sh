#!/bin/sh
# SPDX-License-Identifier: MIT
# base618-screen and base618-power for the unit (aarch64, static): out/.
#   CC=aarch64-linux-gnu-gcc scripts/build-daemons.sh
set -eu
cd "$(dirname "$0")/.."
CC=${CC:-aarch64-linux-gnu-gcc}
mkdir -p out
for d in base618-screen base618-power; do
	$CC -std=c11 -D_DEFAULT_SOURCE -O2 -Wall -Wextra -static -s -o "out/$d" "src/$d.c" -lm
done
file out/base618-screen out/base618-power 2> /dev/null || ls -l out
