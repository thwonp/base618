/* SPDX-License-Identifier: MIT */
/* The panel's framebuffer for base618's two small daemons, header-only so each
 * builds from one .c: map /dev/fb0, take the console off it (KD_GRAPHICS, so
 * fbcon draws no text or cursor over us), and plot in the picture's upright
 * frame - the swivel closed turns it 90 degrees, as fbcon=rotate:1 does. */
#ifndef BASE618_FB_H
#define BASE618_FB_H
#include <fcntl.h>
#include <linux/fb.h>
#include <linux/input.h>
#include <linux/kd.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <unistd.h>

typedef struct {
	uint8_t *mem;
	int w, h, stride, bpp, rot; /* rot: 0 upright, 1 = 90 degrees clockwise */
	struct fb_var_screeninfo v;
} fb;

static int fb_open(fb *f)
{
	struct fb_fix_screeninfo fx;
	int fd = open("/dev/fb0", O_RDWR | O_CLOEXEC);

	if (fd < 0 || ioctl(fd, FBIOGET_VSCREENINFO, &f->v) || ioctl(fd, FBIOGET_FSCREENINFO, &fx)) {
		perror("fb0");
		return -1;
	}
	f->w = f->v.xres;
	f->h = f->v.yres;
	f->bpp = f->v.bits_per_pixel;
	f->stride = fx.line_length;
	f->rot = 0;
	if (f->bpp != 32 && f->bpp != 16) {
		fprintf(stderr, "fb0: %d bpp not handled\n", f->bpp);
		return -1;
	}
	f->mem = mmap(NULL, fx.smem_len, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
	close(fd);
	return f->mem == MAP_FAILED ? -1 : 0;
}

/* Text mode off on the active console: no fbcon text or cursor until it is
 * set back. Stays set after we exit, which is what a static screen wants. */
static void fb_console_off(void)
{
	int fd = open("/dev/tty0", O_RDWR | O_CLOEXEC);
	if (fd >= 0) {
		ioctl(fd, KDSETMODE, KD_GRAPHICS);
		close(fd);
	}
}

/* Upright width and height: the panel is square, but keep it general. */
static int fb_uw(const fb *f) { return f->rot & 1 ? f->h : f->w; }
static int fb_uh(const fb *f) { return f->rot & 1 ? f->w : f->h; }

static void fb_put(fb *f, int x, int y, uint8_t r, uint8_t g, uint8_t b)
{
	int px = x, py = y;

	if (f->rot == 1) { px = f->w - 1 - y; py = x; }
	if (px < 0 || py < 0 || px >= f->w || py >= f->h)
		return;
	if (f->bpp == 32) {
		uint32_t c = (uint32_t)r << f->v.red.offset | (uint32_t)g << f->v.green.offset |
		             (uint32_t)b << f->v.blue.offset;
		if (f->v.transp.length)
			c |= ((1u << f->v.transp.length) - 1) << f->v.transp.offset;
		*(uint32_t *)(f->mem + py * f->stride + px * 4) = c;
	} else {
		*(uint16_t *)(f->mem + py * f->stride + px * 2) =
			(uint16_t)((r >> 3) << 11 | (g >> 2) << 5 | b >> 3);
	}
}

static void fb_clear(fb *f)
{
	for (int y = 0; y < f->h; y++)
		memset(f->mem + y * f->stride, 0, (size_t)f->w * f->bpp / 8);
	/* Opaque black where the format has alpha. */
	if (f->bpp == 32 && f->v.transp.length)
		for (int y = 0; y < fb_uh(f); y++)
			for (int x = 0; x < fb_uw(f); x++)
				fb_put(f, x, y, 0, 0, 0);
}

/* The input device that reports this key or switch; -1 if none. */
static int input_find(int type, int code)
{
	char p[32];
	unsigned long bits[(KEY_MAX + 1) / (8 * sizeof(long)) + 1];

	for (int i = 0; i < 32; i++) {
		snprintf(p, sizeof p, "/dev/input/event%d", i);
		int fd = open(p, O_RDONLY | O_CLOEXEC);
		if (fd < 0)
			continue;
		memset(bits, 0, sizeof bits);
		if (ioctl(fd, EVIOCGBIT(type, sizeof bits), bits) >= 0 &&
		    bits[code / (8 * sizeof(long))] >> (code % (8 * sizeof(long))) & 1)
			return fd;
		close(fd);
	}
	return -1;
}

/* The swivel: closed (SW_LID 1) turns the picture 90 degrees. */
static int lid_rot(int fd)
{
	unsigned long sw[(SW_MAX + 1) / (8 * sizeof(long)) + 1] = { 0 };

	if (fd < 0 || ioctl(fd, EVIOCGSW(sizeof sw), sw) < 0)
		return 0;
	return sw[0] >> SW_LID & 1;
}
#endif
