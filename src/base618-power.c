/* SPDX-License-Identifier: MIT */
/* base618-power: the power key. A tap suspends (deep sleep); a 3 s hold plays
 * plorpOS's send-off - three purple orbs passing right to left, the middle one
 * larger - and powers off. Stands alone: keep it with any frontend that does not
 * handle the key itself, and logind is told to leave the key alone
 * (logind.conf.d/base618-power.conf). */
#include "fb.h"
#include <math.h>
#include <poll.h>
#include <time.h>

#define HOLD_MS 3000
#define ORB_R 138
#define ORB_G 92
#define ORB_B 214

static unsigned now_ms(void)
{
	struct timespec t;
	clock_gettime(CLOCK_MONOTONIC, &t);
	return (unsigned)(t.tv_sec * 1000 + t.tv_nsec / 1000000);
}

static void orb(fb *f, float cx, float cy, float rad)
{
	for (int y = (int)(cy - rad); y <= (int)(cy + rad) + 1; y++)
		for (int x = (int)(cx - rad); x <= (int)(cx + rad) + 1; x++) {
			/* One pixel of edge coverage, over black. */
			float a = rad + 0.5f - hypotf(x - cx, y - cy);
			if (a <= 0)
				continue;
			if (a > 1)
				a = 1;
			fb_put(f, x, y, (uint8_t)(ORB_R * a), (uint8_t)(ORB_G * a), (uint8_t)(ORB_B * a));
		}
}

/* plorpOS's anim_poweroff (plorpos-3yv.91), drawn straight into the panel:
 * 700 ms, each orb 45 ms behind the one before, slowest crossing the center. */
static void send_off(int lid)
{
	const unsigned MS = 700, LAG = 45;
	const float rad = 22.0f, gap = 72.0f;
	unsigned t0, t;
	fb f;

	if (fb_open(&f))
		return;
	fb_console_off();
	f.rot = lid_rot(lid);
	const float W = fb_uw(&f), cx = W / 2, cy = fb_uh(&f) / 2.0f;
	float last[3] = { 0 };
	int drawn = 0;

	fb_clear(&f);
	t0 = now_ms();
	while ((t = now_ms() - t0) < MS) {
		for (int i = 0; i < 3; i++) {
			unsigned d = (unsigned)i * LAG;
			float k = t < d ? 0.0f : (float)(t - d) / (float)(MS - 2 * LAG), s;
			float r = i == 1 ? rad * 1.4f : rad;
			if (k > 1.0f)
				k = 1.0f;
			s = 2.0f * k - 1.0f;
			s = s * s * s;
			/* Clear only last frame's orb: a full clear each frame flickers. */
			if (drawn)
				for (int y = (int)(cy - r) - 1; y <= (int)(cy + r) + 2; y++)
					for (int x = (int)(last[i] - r) - 1; x <= (int)(last[i] + r) + 2; x++)
						fb_put(&f, x, y, 0, 0, 0);
			last[i] = cx + (i - 1) * gap - s * (W * 0.5f + 2.0f * gap);
		}
		for (int i = 0; i < 3; i++)
			orb(&f, last[i], cy, i == 1 ? rad * 1.4f : rad);
		drawn = 1;
		usleep(6000);
	}
	fb_clear(&f);
}

static void suspend(void)
{
	int fd = open("/sys/power/state", O_WRONLY | O_CLOEXEC);
	if (fd < 0 || write(fd, "mem", 3) != 3)
		perror("base618-power: suspend");
	if (fd >= 0)
		close(fd);
}

int main(void)
{
	int key = input_find(EV_KEY, KEY_POWER), lid = input_find(EV_SW, SW_LID);
	struct input_event ev;
	unsigned down = 0;
	int held = 0;

	if (key < 0) {
		fprintf(stderr, "base618-power: no input device has KEY_POWER\n");
		return 1;
	}
	/* No EVIOCGRAB: the key shares gpio-keys-system with the swivel's SW_LID,
	 * which base618-screen reads. logind leaves the key alone (logind.conf.d). */
	for (;;) {
		struct pollfd p = { key, POLLIN, 0 };
		int ms = held ? (int)(down + HOLD_MS - now_ms()) : -1;

		if (held && ms <= 0) {
			fprintf(stderr, "base618-power: held %d ms, powering off\n", HOLD_MS);
			send_off(lid);
			execlp("systemctl", "systemctl", "poweroff", (char *)NULL);
			return 1;
		}
		if (poll(&p, 1, ms) <= 0)
			continue;
		if (read(key, &ev, sizeof ev) != sizeof ev)
			return 1;
		if (ev.type != EV_KEY || ev.code != KEY_POWER)
			continue;
		if (ev.value == 1) {
			held = 1;
			down = now_ms();
		} else if (ev.value == 0 && held) {
			held = 0;
			suspend(); /* returns after the wake */
			/* The press that woke the unit is not a new tap. */
			usleep(300000);
			while (poll(&p, 1, 0) > 0 && read(key, &ev, sizeof ev) == sizeof ev)
				;
		}
	}
}
