# Boot logos

Two images show before a frontend is up. Both are drawn upright for the way the unit is held (swivel
open = the panel's own orientation, closed = turned 90 degrees, read from the hall sensor).

| When | Drawn by | Source | Change it by |
|---|---|---|---|
| U-Boot start to kernel handoff | U-Boot, into the panel's framebuffer, then held on black through the handoff | `board/spreadtrum/ums512_1h10/plorpos_logo.{c,h}` in thwonp/u-boot-ums512 | regenerating `plorpos_logo.h` with `mklogo.py` and rebuilding U-Boot |
| kernel handoff to frontend | fbcon, the kernel's own logo, centred on a quiet console | `CONFIG_LOGO_LINUX_CLUT224_FILE` = `drivers/video/logo/logo_plorpos_clut224.ppm` in `rotate-fixes` | another 224-colour PPM and a kernel rebuild |

## U-Boot's logo

An 8-bit coverage map, run-length coded (a nonzero byte is one pixel, `00 n` is n empty ones), two colours
split at a column. `mklogo.py`'s header has the recipe (ImageMagick from a font, `gray:` raw out):

```sh
mklogo.py word.raw WIDTH HEIGHT SPLIT > plorpos_logo.h
```

Then rebuild and wrap U-Boot ([install.md](install.md), section 2). The drawing code
(`plorpos_logo.c`) compiles on a host too, to check it against the artwork before flashing.

## The kernel's logo

fbcon draws it once (`fbcon=logo-pos:center,logo-count:1` on the command line), turned with
`fbcon=rotate:N`. A PPM of at most 224 colours (`pnmtologo` refuses more):

```sh
magick logo.png -colors 224 -compress none logo_clut224.ppm   # plain PPM (P3)
```

Point `CONFIG_LOGO_LINUX_CLUT224_FILE` at it and rebuild the kernel. Keep `quiet loglevel=1
vt.global_cursor_default=0` so nothing is written over it.
