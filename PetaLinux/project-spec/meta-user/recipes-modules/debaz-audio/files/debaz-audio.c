// SPDX-License-Identifier: GPL-2.0
/*
 * debaz-audio - ALSA card "DEBAZ" for the DEBAZAROS gateware PCM FIFOs
 * (hdmi_audio_regs 0x43C6_0000, offsets 0x60-0x8C; ROADMAP.md section 13).
 *
 *   PCM 0 "HDMI 0"     playback -> FIFO 0 -> HDMI_0 audio
 *   PCM 1 "HDMI 1"     playback -> FIFO 1 -> HDMI_1 audio
 *   PCM 2 "HDMI 2 In"  capture  <- FIFO C <- HDMI_2 input audio
 *   PCM 3 "I2S"        playback -> FIFO 2 -> I2S DOUT
 *
 * One format: S16_LE, 2 channels, 48000 Hz (a 48 kHz pacer on FCLK0 pops
 * the FIFOs). Each FIFO holds 512 frames (10.7 ms). The CPU copies the data
 * (PIO): one 32-bit AXI-Lite access per stereo frame. The level interrupt
 * (GIC SPI 36, level high: playback level <= threshold, capture level >=
 * threshold, plus xrun latches) refills or drains a FIFO.
 *
 * Routing (I2S_CTRL [6] HDMI_0, [5] HDMI_1, [7] I2S = "plays Linux PCM"):
 * mixer controls "HDMI 0 Route", "HDMI 1 Route", "I2S Route" = Auto (the
 * output plays Linux audio while its PCM runs, else its other source),
 * Linux (always) or Other (never: debazd / the PL choose). The HDMI mode
 * of an output (/audio/tx*), the HDMI_2 loop and the I2S pins stay with
 * debazd.
 *
 * Safety: the PL can be reloaded (fpga_manager) while this module is
 * loaded. An AXI access to the PL during a load is a bus error in the
 * kernel. So the driver touches the PL only while a PCM is open or a
 * control is written, and requests the interrupt only while a PCM is open
 * (an unprogrammed PL can drive the IRQ line). plreload.sh refuses to load
 * while a DEBAZ PCM is open and unbinds the driver around the load.
 */
#include <linux/interrupt.h>
#include <linux/io.h>
#include <linux/module.h>
#include <linux/mod_devicetable.h>
#include <linux/platform_device.h>
#include <sound/control.h>
#include <sound/core.h>
#include <sound/initval.h>
#include <sound/pcm.h>

#define DRV_NAME	"debaz-audio"

#define REG_I2S_CTRL	0x4C
#define REG_PCM_CTRL	0x60	/* [3:0] run, [11:8] write 1 = flush */
#define REG_CAP_DATA	0x6C	/* read = oldest frame, removes it */
#define REG_LEVEL01	0x74	/* [25:16] PCM1, [9:0] PCM0 */
#define REG_LEVEL2C	0x78	/* [25:16] capture, [9:0] PCM2 */
#define REG_IRQ_STATUS	0x7C	/* [3:0] level conditions, [7:4] xrun W1C */
#define REG_IRQ_EN	0x80
#define REG_THRESH01	0x88	/* [24:16] PCM1, [8:0] PCM0 */
#define REG_THRESH2C	0x8C	/* [24:16] capture, [8:0] PCM2 */
#define REG_ID		0x3C
#define ID_HAUD		0x48415544

#define FIFO_DEPTH	512
#define FILL_TOP	480	/* playback: fill up to this level */
#define CHUNK_MAX	256	/* frames per interrupt at most */
#define CHUNK_MIN	32

/* hardware stream index: 0 = PCM0, 1 = PCM1, 2 = PCM2 (I2S), 3 = capture */
struct dz_hw_stream {
	u32 data;		/* data register */
	u32 lvl_reg, thr_reg;
	int shift;		/* level / threshold field position */
	int route_bit;		/* I2S_CTRL bit, -1 = none */
	const char *name;	/* PCM and control name */
	int capture;
};

static const struct dz_hw_stream dz_hw[4] = {
	{ 0x64, REG_LEVEL01, REG_THRESH01, 0,  6,  "HDMI 0",    0 },
	{ 0x68, REG_LEVEL01, REG_THRESH01, 16, 5,  "HDMI 1",    0 },
	{ 0x70, REG_LEVEL2C, REG_THRESH2C, 0,  7,  "I2S",       0 },
	{ REG_CAP_DATA, REG_LEVEL2C, REG_THRESH2C, 16, -1, "HDMI 2 In", 1 },
};

/* PCM device number -> hardware stream (PCM 2 = capture, PCM 3 = I2S) */
static const int dz_pcm_hw[4] = { 0, 1, 3, 2 };

enum { ROUTE_AUTO, ROUTE_LINUX, ROUTE_OTHER };

struct dz_stream {
	struct snd_pcm_substream *sub;
	int hw;			/* index into dz_hw */
	int running;
	snd_pcm_uframes_t pos;	/* ring position of the next frame to move */
	snd_pcm_uframes_t abs;	/* frames moved, modulo runtime->boundary */
	snd_pcm_uframes_t in_period;
	int elapsed;		/* a period boundary was crossed */
	unsigned int chunk;
	unsigned int thr;	/* threshold now in the register */
	unsigned long xruns;
};

struct dz_audio {
	struct device *dev;
	void __iomem *base;
	int irq;
	struct snd_card *card;
	spinlock_t lock;	/* all register read-modify-writes, stream state */
	struct mutex open_lock;	/* IRQ request / free */
	int users;		/* open PCMs */
	struct dz_stream st[4];	/* by hardware index */
	int route[3];		/* by hardware index 0..2 */
};

static inline u32 dz_rd(struct dz_audio *dz, u32 off)
{
	return readl(dz->base + off);
}

static inline void dz_wr(struct dz_audio *dz, u32 off, u32 v)
{
	writel(v, dz->base + off);
}

static void dz_rmw(struct dz_audio *dz, u32 off, u32 clr, u32 set)
{
	dz_wr(dz, off, (dz_rd(dz, off) & ~clr) | set);
}

static unsigned int dz_level(struct dz_audio *dz, int hw)
{
	return (dz_rd(dz, dz_hw[hw].lvl_reg) >> dz_hw[hw].shift) & 0x3FF;
}

/* lock held */
static void dz_route_apply(struct dz_audio *dz, int hw)
{
	int on;

	if (hw > 2)
		return;
	on = dz->route[hw] == ROUTE_LINUX ||
	     (dz->route[hw] == ROUTE_AUTO && dz->st[hw].running);
	dz_rmw(dz, REG_I2S_CTRL, BIT(dz_hw[hw].route_bit),
	       on ? BIT(dz_hw[hw].route_bit) : 0);
}

/* playback: frames the application has written and the FIFO has not got */
static snd_pcm_uframes_t dz_app_frames(struct snd_pcm_runtime *rt, struct dz_stream *s)
{
	snd_pcm_sframes_t d = READ_ONCE(rt->control->appl_ptr) - s->abs;

	if (d < 0)
		d += rt->boundary;
	return d;
}

/* lock held */
static void dz_set_thr(struct dz_audio *dz, struct dz_stream *s, unsigned int thr)
{
	const struct dz_hw_stream *h = &dz_hw[s->hw];

	if (s->thr == thr)
		return;
	s->thr = thr;
	dz_rmw(dz, h->thr_reg, 0x1FF << h->shift, thr << h->shift);
}

/*
 * Lock held: move frames between the ring buffer and the FIFO. Playback
 * moves only frames that the application has written (else the pointer
 * runs past appl_ptr and ALSA reports an underrun at once). When that
 * leaves the FIFO below the fill level ("starving"), the threshold drops
 * to 0: the interrupt then comes once, when the FIFO is empty, so ALSA
 * sees the end of a drain at once (else it waits for its 10 s timeout).
 * Empty + no data = dry: the level interrupt (a live condition) is masked
 * until the application writes again (dz_ack).
 */
static void dz_move(struct dz_audio *dz, struct dz_stream *s)
{
	struct snd_pcm_runtime *rt = s->sub->runtime;
	u32 *ring = (u32 *)rt->dma_area;	/* S16_LE stereo = {R, L} words */
	const struct dz_hw_stream *h = &dz_hw[s->hw];
	unsigned int lvl = dz_level(dz, s->hw), n;
	u32 bit = BIT(s->hw);

	if (h->capture) {
		n = lvl;
	} else {
		snd_pcm_uframes_t have = dz_app_frames(rt, s);

		n = lvl < FILL_TOP ? FILL_TOP - lvl : 0;
		if (have >= n) {
			dz_set_thr(dz, s, FILL_TOP - s->chunk);
			dz_rmw(dz, REG_IRQ_EN, 0, bit);
		} else if (lvl + have > 0) {
			n = have;			/* starving */
			dz_set_thr(dz, s, 0);
			dz_rmw(dz, REG_IRQ_EN, 0, bit);
		} else {
			n = 0;				/* dry: report, wait for dz_ack */
			dz_rmw(dz, REG_IRQ_EN, bit, 0);
			s->elapsed = 1;
		}
	}
	if (!h->capture && (dz_rd(dz, REG_IRQ_STATUS) & bit << 4)) {
		s->xruns++;		/* the FIFO ran empty (it played silence) */
		dz_wr(dz, REG_IRQ_STATUS, bit << 4);
	}
	while (n--) {
		if (h->capture)
			ring[s->pos] = readl_relaxed(dz->base + h->data);
		else
			writel_relaxed(ring[s->pos], dz->base + h->data);
		if (++s->pos >= rt->buffer_size)
			s->pos = 0;
		if (++s->abs >= rt->boundary)
			s->abs = 0;
		if (++s->in_period >= rt->period_size) {
			s->in_period = 0;
			s->elapsed = 1;
		}
	}
	wmb();
}

static irqreturn_t dz_irq(int irq, void *data)
{
	struct dz_audio *dz = data;
	struct snd_pcm_substream *done[4];
	int ndone = 0, i;
	u32 st;

	spin_lock(&dz->lock);
	st = dz_rd(dz, REG_IRQ_STATUS) & dz_rd(dz, REG_IRQ_EN);
	if (!st) {
		spin_unlock(&dz->lock);
		return IRQ_NONE;
	}
	if (st & 0xF0) {			/* underrun / overrun latches */
		for (i = 0; i < 4; i++)
			if (st & BIT(4 + i))
				dz->st[i].xruns++;
		dz_wr(dz, REG_IRQ_STATUS, st & 0xF0);
	}
	for (i = 0; i < 4; i++) {
		struct dz_stream *s = &dz->st[i];

		if (!s->running || !(st & BIT(i)))
			continue;
		dz_move(dz, s);
		if (s->elapsed) {
			s->elapsed = 0;
			done[ndone++] = s->sub;
		}
	}
	spin_unlock(&dz->lock);
	for (i = 0; i < ndone; i++)		/* takes the stream lock */
		snd_pcm_period_elapsed(done[i]);
	return IRQ_HANDLED;
}

/* ---- PCM ops ------------------------------------------------------------- */

static const struct snd_pcm_hardware dz_pcm_hw_info = {
	.info = SNDRV_PCM_INFO_INTERLEAVED | SNDRV_PCM_INFO_MMAP |
		SNDRV_PCM_INFO_MMAP_VALID | SNDRV_PCM_INFO_BLOCK_TRANSFER |
		SNDRV_PCM_INFO_BATCH,
	.formats = SNDRV_PCM_FMTBIT_S16_LE,
	.rates = SNDRV_PCM_RATE_48000,
	.rate_min = 48000,
	.rate_max = 48000,
	.channels_min = 2,
	.channels_max = 2,
	.buffer_bytes_max = 16384 * 4,	/* 341 ms: apps take the maximum */
	.period_bytes_min = CHUNK_MIN * 4,
	.period_bytes_max = 8192 * 4,
	.periods_min = 2,
	.periods_max = 1024,
};

static struct dz_stream *dz_sub_stream(struct snd_pcm_substream *sub)
{
	struct dz_audio *dz = snd_pcm_substream_chip(sub);

	return &dz->st[dz_pcm_hw[sub->pcm->device]];
}

static int dz_open(struct snd_pcm_substream *sub)
{
	struct dz_audio *dz = snd_pcm_substream_chip(sub);
	struct dz_stream *s = dz_sub_stream(sub);
	int ret = 0;

	mutex_lock(&dz->open_lock);
	if (dz->users == 0) {
		/* the PL is programmed and ours (ID) before the IRQ goes live */
		if (dz_rd(dz, REG_ID) != ID_HAUD) {
			ret = -ENODEV;
			goto out;
		}
		dz_wr(dz, REG_IRQ_EN, 0);
		ret = request_irq(dz->irq, dz_irq, 0, DRV_NAME, dz);
		if (ret)
			goto out;
	}
	dz->users++;
	s->sub = sub;
	sub->runtime->hw = dz_pcm_hw_info;
	snd_pcm_hw_constraint_minmax(sub->runtime, SNDRV_PCM_HW_PARAM_PERIOD_SIZE,
				     CHUNK_MIN, 8192);
	/* the pre-fill moves up to FILL_TOP frames at once: the ring must hold more */
	snd_pcm_hw_constraint_minmax(sub->runtime, SNDRV_PCM_HW_PARAM_BUFFER_SIZE,
				     2 * FIFO_DEPTH, 16384);
out:
	mutex_unlock(&dz->open_lock);
	return ret;
}

static int dz_close(struct snd_pcm_substream *sub)
{
	struct dz_audio *dz = snd_pcm_substream_chip(sub);
	struct dz_stream *s = dz_sub_stream(sub);

	mutex_lock(&dz->open_lock);
	if (s->xruns)
		dev_info(dz->dev, "%s: %lu FIFO xrun periods\n", dz_hw[s->hw].name, s->xruns);
	s->sub = NULL;
	if (--dz->users == 0) {
		dz_wr(dz, REG_IRQ_EN, 0);
		free_irq(dz->irq, dz);
	}
	mutex_unlock(&dz->open_lock);
	return 0;
}

static int dz_prepare(struct snd_pcm_substream *sub)
{
	struct dz_audio *dz = snd_pcm_substream_chip(sub);
	struct dz_stream *s = dz_sub_stream(sub);
	unsigned long flags;

	spin_lock_irqsave(&dz->lock, flags);
	s->pos = 0;
	s->abs = 0;		/* prepare: hw_ptr = appl_ptr = 0 */
	s->in_period = 0;
	s->elapsed = 0;
	s->xruns = 0;
	s->chunk = clamp_t(unsigned int, sub->runtime->period_size, CHUNK_MIN, CHUNK_MAX);
	spin_unlock_irqrestore(&dz->lock, flags);
	return 0;
}

static int dz_trigger(struct snd_pcm_substream *sub, int cmd)
{
	struct dz_audio *dz = snd_pcm_substream_chip(sub);
	struct dz_stream *s = dz_sub_stream(sub);
	const struct dz_hw_stream *h = &dz_hw[s->hw];
	u32 bit = BIT(s->hw), thr;
	unsigned long flags;

	spin_lock_irqsave(&dz->lock, flags);
	switch (cmd) {
	case SNDRV_PCM_TRIGGER_START:
	case SNDRV_PCM_TRIGGER_RESUME:
		dz_rmw(dz, REG_PCM_CTRL, 0xF00 | bit, bit << 8);	/* stop + flush */
		dz_wr(dz, REG_IRQ_STATUS, bit << 4);
		/* playback: interrupt when `chunk` frames have room below the
		 * fill level; capture: when `chunk` frames are waiting */
		thr = h->capture ? s->chunk : FILL_TOP - s->chunk;
		s->thr = ~0u;
		dz_set_thr(dz, s, thr);
		s->running = 1;
		if (!h->capture)	/* pre-fill; a period it completes is */
			dz_move(dz, s);	/* reported at the next interrupt */
		dz_rmw(dz, REG_PCM_CTRL, 0xF00, bit);		/* run */
		/* capture: level + overrun latch (set once per overrun). Playback:
		 * the level bit is dz_move's (starving); NOT the underrun latch:
		 * it sets again at every 48 kHz tick while the FIFO is empty
		 * (an interrupt storm) - dz_move counts it instead */
		if (h->capture)
			dz_rmw(dz, REG_IRQ_EN, 0, bit | bit << 4);
		dz_route_apply(dz, s->hw);
		break;
	case SNDRV_PCM_TRIGGER_STOP:
	case SNDRV_PCM_TRIGGER_SUSPEND:
		dz_rmw(dz, REG_IRQ_EN, bit | bit << 4, 0);
		dz_rmw(dz, REG_PCM_CTRL, 0xF00 | bit, bit << 8);	/* stop + flush */
		dz_wr(dz, REG_IRQ_STATUS, bit << 4);
		s->running = 0;
		dz_route_apply(dz, s->hw);
		break;
	default:
		spin_unlock_irqrestore(&dz->lock, flags);
		return -EINVAL;
	}
	spin_unlock_irqrestore(&dz->lock, flags);
	return 0;
}

/* playback: the application wrote frames (appl_ptr moved; the stream lock
 * is held): refill now, and unmask the level interrupt if it was starving */
static int dz_ack(struct snd_pcm_substream *sub)
{
	struct dz_audio *dz = snd_pcm_substream_chip(sub);
	struct dz_stream *s = dz_sub_stream(sub);
	unsigned long flags;

	spin_lock_irqsave(&dz->lock, flags);
	if (s->running && !dz_hw[s->hw].capture)
		dz_move(dz, s);
	spin_unlock_irqrestore(&dz->lock, flags);
	return 0;
}

/*
 * Playback: the PLAYED position = frames moved to the FIFO minus the FIFO
 * level. (Frames moved alone catch up with appl_ptr at once, and ALSA
 * takes the empty ring for an underrun.) The FIFO contents are then part
 * of the ring's data, so the delay needs no extra term.
 * Capture: frames read from the FIFO; the frames still in it are the delay.
 */
static snd_pcm_uframes_t dz_pointer(struct snd_pcm_substream *sub)
{
	struct dz_audio *dz = snd_pcm_substream_chip(sub);
	struct dz_stream *s = dz_sub_stream(sub);
	struct snd_pcm_runtime *rt = sub->runtime;
	unsigned long flags;
	snd_pcm_uframes_t p;
	unsigned int lvl;

	spin_lock_irqsave(&dz->lock, flags);
	lvl = dz_level(dz, s->hw);
	p = s->pos;
	spin_unlock_irqrestore(&dz->lock, flags);
	if (dz_hw[s->hw].capture) {
		rt->delay = lvl;
		return p;
	}
	rt->delay = 0;
	return (p + rt->buffer_size - lvl % rt->buffer_size) % rt->buffer_size;
}

static const struct snd_pcm_ops dz_pcm_ops = {
	.open = dz_open,
	.close = dz_close,
	.prepare = dz_prepare,
	.trigger = dz_trigger,
	.pointer = dz_pointer,
	.ack = dz_ack,
};

/* ---- mixer controls -------------------------------------------------------- */

static const char *const dz_route_names[] = { "Auto", "Linux", "Other" };

static int dz_route_info(struct snd_kcontrol *kc, struct snd_ctl_elem_info *ui)
{
	return snd_ctl_enum_info(ui, 1, ARRAY_SIZE(dz_route_names), dz_route_names);
}

static int dz_route_get(struct snd_kcontrol *kc, struct snd_ctl_elem_value *uv)
{
	struct dz_audio *dz = snd_kcontrol_chip(kc);

	uv->value.enumerated.item[0] = dz->route[kc->private_value];
	return 0;
}

static int dz_route_put(struct snd_kcontrol *kc, struct snd_ctl_elem_value *uv)
{
	struct dz_audio *dz = snd_kcontrol_chip(kc);
	unsigned int v = uv->value.enumerated.item[0];
	int hw = kc->private_value, changed;
	unsigned long flags;

	if (v >= ARRAY_SIZE(dz_route_names))
		return -EINVAL;
	spin_lock_irqsave(&dz->lock, flags);
	changed = dz->route[hw] != (int)v;
	dz->route[hw] = v;
	dz_route_apply(dz, hw);
	spin_unlock_irqrestore(&dz->lock, flags);
	return changed;
}

static int dz_add_controls(struct dz_audio *dz)
{
	static const char *const names[3] = { "HDMI 0 Route", "HDMI 1 Route", "I2S Route" };
	int i, ret;

	for (i = 0; i < 3; i++) {
		struct snd_kcontrol_new kn = {
			.iface = SNDRV_CTL_ELEM_IFACE_MIXER,
			.name = names[i],
			.info = dz_route_info,
			.get = dz_route_get,
			.put = dz_route_put,
			.private_value = i,
		};

		ret = snd_ctl_add(dz->card, snd_ctl_new1(&kn, dz));
		if (ret)
			return ret;
	}
	return 0;
}

/* ---- platform driver -------------------------------------------------------- */

static int dz_probe(struct platform_device *pdev)
{
	struct dz_audio *dz;
	struct snd_card *card;
	int ret, i;

	ret = snd_card_new(&pdev->dev, SNDRV_DEFAULT_IDX1, "DEBAZ", THIS_MODULE,
			   sizeof(*dz), &card);
	if (ret)
		return ret;
	dz = card->private_data;
	dz->dev = &pdev->dev;
	dz->card = card;
	spin_lock_init(&dz->lock);
	mutex_init(&dz->open_lock);
	for (i = 0; i < 4; i++)
		dz->st[i].hw = i;

	dz->base = devm_platform_ioremap_resource(pdev, 0);
	if (IS_ERR(dz->base)) {
		ret = PTR_ERR(dz->base);
		goto err;
	}
	dz->irq = platform_get_irq(pdev, 0);
	if (dz->irq < 0) {
		ret = dz->irq;
		goto err;
	}
	/* one read at probe: the boot bitstream must have the block */
	if (dz_rd(dz, REG_ID) != ID_HAUD) {
		dev_err(&pdev->dev, "no hdmi_audio_regs (ID 0x%08x)\n", dz_rd(dz, REG_ID));
		ret = -ENODEV;
		goto err;
	}

	strscpy(card->driver, "DEBAZ", sizeof(card->driver));
	strscpy(card->shortname, "DEBAZAROS", sizeof(card->shortname));
	snprintf(card->longname, sizeof(card->longname),
		 "DEBAZAROS HDMI/I2S PCM FIFOs at 0x%08llx irq %d",
		 (unsigned long long)platform_get_resource(pdev, IORESOURCE_MEM, 0)->start,
		 dz->irq);

	for (i = 0; i < 4; i++) {
		const struct dz_hw_stream *h = &dz_hw[dz_pcm_hw[i]];
		struct snd_pcm *pcm;

		ret = snd_pcm_new(card, h->name, i, h->capture ? 0 : 1, h->capture ? 1 : 0, &pcm);
		if (ret)
			goto err;
		pcm->private_data = dz;
		strscpy(pcm->name, h->name, sizeof(pcm->name));
		snd_pcm_set_ops(pcm, h->capture ? SNDRV_PCM_STREAM_CAPTURE :
				SNDRV_PCM_STREAM_PLAYBACK, &dz_pcm_ops);
		snd_pcm_set_managed_buffer_all(pcm, SNDRV_DMA_TYPE_VMALLOC, NULL, 0, 0);
	}
	ret = dz_add_controls(dz);
	if (ret)
		goto err;
	ret = snd_card_register(card);
	if (ret)
		goto err;
	platform_set_drvdata(pdev, card);
	dev_info(&pdev->dev, "card DEBAZ: HDMI 0, HDMI 1, HDMI 2 In, I2S\n");
	return 0;
err:
	snd_card_free(card);
	return ret;
}

static int dz_remove(struct platform_device *pdev)
{
	snd_card_free(platform_get_drvdata(pdev));
	return 0;
}

static const struct of_device_id dz_of_match[] = {
	{ .compatible = "debaz,hdmi-audio-1.0" },
	{ }
};
MODULE_DEVICE_TABLE(of, dz_of_match);

static struct platform_driver dz_driver = {
	.probe = dz_probe,
	.remove = dz_remove,
	.driver = {
		.name = DRV_NAME,
		.of_match_table = dz_of_match,
	},
};
module_platform_driver(dz_driver);

MODULE_DESCRIPTION("DEBAZAROS gateware PCM FIFOs as an ALSA card");
MODULE_LICENSE("GPL");
