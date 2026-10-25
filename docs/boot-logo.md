# Boot logos

Two images show before a frontend is up. Both are drawn upright for the way the unit is held (swivel
open = the panel's own orientation, closed = turned 90 degrees, read from the hall sensor).

| When | Drawn by | Source | Change it by |
|---|---|---|---|
| U-Boot start to kernel handoff | U-Boot, into the panel's framebuffer, then held on black through the handoff | `board/spreadtrum/ums512_1h10/plorpos_logo.{c,h}` in thwonp/u-boot-ums512 | regenerating `plorpos_logo.h` with `mklogo.py` and rebuilding U-Boot |
| kernel handoff to frontend | fbcon, centred on a quiet console | `boot-logo.ppm` in the firmware initrd if there is one, else the built-in `logo_plorpos_clut224.ppm` | one file and an initrd rebuild on the device, no kernel build - below |

## U-Boot's logo

An 8-bit coverage map, run-length coded (a nonzero byte is one pixel, `00 n` is n empty ones), two colours
split at a column. `mklogo.py`'s header has the recipe (ImageMagick from a font, `gray:` raw out):

```sh
mklogo.py word.raw WIDTH HEIGHT SPLIT > plorpos_logo.h
```

Then rebuild and wrap U-Boot ([install.md](install.md), section 2). The drawing code
(`plorpos_logo.c`) compiles on a host too, to check it against the artwork before flashing.

## The kernel's logo - the one to change

fbcon draws it once (`fbcon=logo-pos:center,logo-count:1` on the command line), turned with
`fbcon=rotate:N`, centred on black. Keep `quiet loglevel=1 vt.global_cursor_default=0` so nothing is
written over it.

**Changing it** (kernel from `rotate-fixes` `cfca41d53` on):

1. On a PC: `scripts/make-logo.sh my-logo.png boot-logo.ppm` - binary PPM, at most 224 colours, at most
   720x720, transparency on black. Crop it tight: the kernel centres it, and fewer pixels load faster.
2. On the unit, as root: copy it to `/lib/firmware/boot-logo.ppm` and rebuild the initrd,
   `scripts/make-initrd-fw.sh / /boot/initrd-fw.cpio.gz`.
3. Boot. `dmesg | grep 'logo:'` shows its size, colours and the time it took.

To go back to the built-in logo, delete `/lib/firmware/boot-logo.ppm` and rebuild the initrd.

The kernel reads the file once at late init, from the initramfs, before the display binds, and keeps it.
A file that is not a binary PPM with maxval 255 and at most 224 colours is refused with a `logo:` warning
and the built-in logo is drawn. With no file, the cost is one failed lookup.

The built-in one is `CONFIG_LOGO_LINUX_CLUT224_FILE` (`drivers/video/logo/logo_plorpos_clut224.ppm`);
replacing that still means a kernel build.
