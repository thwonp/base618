/* SPDX-License-Identifier: MIT */
/* base618-screen: the "no CFW installed" screen. Draws a greyscale PGM (P5,
 * coverage: 0 black, 255 white), centred and upright, on the panel and keeps it
 * upright when the swivel turns. A frontend replaces it: disable the unit.
 *
 *   base618-screen [IMAGE.pgm]    default /usr/share/base618/screen.pgm */
#include "fb.h"
#include <stdlib.h>

static uint8_t *pgm_load(const char *path, int *w, int *h)
{
	FILE *fp = fopen(path, "rb");
	int max;
	uint8_t *px;

	if (!fp || fscanf(fp, "P5 %d %d %d", w, h, &max) != 3 || max != 255 || fgetc(fp) == EOF) {
		fprintf(stderr, "base618-screen: %s is not an 8-bit P5 PGM\n", path);
		return NULL;
	}
	px = malloc((size_t)*w * *h);
	if (!px || fread(px, 1, (size_t)*w * *h, fp) != (size_t)*w * *h) {
		fprintf(stderr, "base618-screen: %s is short\n", path);
		return NULL;
	}
	fclose(fp);
	return px;
}

static void draw(fb *f, const uint8_t *px, int w, int h)
{
	int x0 = (fb_uw(f) - w) / 2, y0 = (fb_uh(f) - h) / 2;

	fb_clear(f);
	for (int y = 0; y < h; y++)
		for (int x = 0; x < w; x++)
			if (px[y * w + x])
				fb_put(f, x0 + x, y0 + y, px[y * w + x], px[y * w + x], px[y * w + x]);
}

int main(int argc, char **argv)
{
	const char *path = argc > 1 ? argv[1] : "/usr/share/base618/screen.pgm";
	struct input_event ev;
	int w, h, lid;
	uint8_t *px = pgm_load(path, &w, &h);
	fb f;

	if (!px || fb_open(&f))
		return 1;
	fb_console_off();
	lid = input_find(EV_SW, SW_LID);
	f.rot = lid_rot(lid);
	draw(&f, px, w, h);
	if (lid < 0)
		for (;;)
			pause();
	while (read(lid, &ev, sizeof ev) == sizeof ev)
		if (ev.type == EV_SW && ev.code == SW_LID && ev.value != f.rot) {
			f.rot = ev.value;
			draw(&f, px, w, h);
		}
	return 0;
}
