// SPDX-License-Identifier: GPL-2.0
/*
 * dzmem.c - the reserved video-slot region of DEBAZAROS mapped CACHED into
 * user space, with cache maintenance by range (ROADMAP.md section 19 step 5:
 * the cached-slots experiment, 2026-11-20). EXPERIMENTAL: not loaded at boot,
 * not in the image; built as a package and loaded by hand:
 *   insmod dzmem.ko [base=0x08000000 size=0x06000000]
 * The user interface (ioctls, memory types): sw/include/dzmem.h.
 *
 * Why: the slots are DDR the VDMAs read (and the capture VDMA writes), mapped
 * uncached everywhere today (/dev/mem: ~105 MB/s reads), so debazd keeps a
 * cached copy of each painted slot (8 MB) and copies changed rectangles.
 * With a cached mapping every writer could draw straight into the slot and
 * clean the changed range before the VDMA scans it.
 *
 * How:
 * - no struct pages: the region is a no-map reserved-memory node (not in the
 *   kernel's linear map), so mmap = remap_pfn_range with the chosen memory
 *   type, and the module never maps the region itself (no kernel alias).
 * - L1 maintenance by virtual address ON THE CALLER'S MAPPING (the ioctl
 *   runs in its mm; the PTEs are all present after remap_pfn_range): the
 *   A9 L1 D-cache is PIPT and by-MVA operations are broadcast to the other
 *   core (SMP maintenance broadcast). __cpuc_flush_dcache_area = clean +
 *   invalidate to the point of coherency (v7_dma_*_range are not exported).
 * - L2 (PL310) by physical range through outer_cache (exported), or all ways.
 * - Refused unless the whole region is outside System RAM (region_intersects):
 *   a wrong base must never map Linux memory into user space.
 *
 * v2 (2026-11-21, sw/SLOTMEM.md section 4.4): ONE MEMORY TYPE PER SLOT.
 * Measured on .236 (dzmemtest coh): two mappings of the same bytes with
 * different types lose writes (WB + WT: 5 % of the WT writes; WB + WC and
 * WT + WC too; the A9 L1 treats WT as non-cacheable, TRM 7.4.3). So:
 * - guard: the live mappings of each slot (pitch = module parameter) are
 *   counted per class: WB, WT, NC (WC and UC: both bypass the caches).
 *   Parameter guard (runtime, /sys/module/dzmem/parameters/guard):
 *   0 (default, user 2026-11-21: judge the corruption on a monitor before
 *   forbidding it) = a mix is ALLOWED, logged and counted ("mixed");
 *   1 = an mmap whose class differs from a live mapping of a slot it
 *   covers fails with -EBUSY, WT fails unless allow_wt=1, slots in the
 *   nocache mask (default: slot 4, the capture) refuse WB and WT.
 *   Mappings cannot be split (may_split) and are not inherited (DONTCOPY),
 *   so a VMA covers the same slots from mmap to close.
 * - transitions in the module: the first cached (WB / WT) mapping of a slot
 *   invalidates the slot in L2; when the last one closes (munmap, exit, a
 *   crash) the module cleans + invalidates L1 on every CPU (set/way, the
 *   user address is gone by then) and L2 by physical range. A crashed
 *   writer can never leave dirty lines that a later writer of another type
 *   would race.
 * - counters: /sys/class/misc/dzmem/stats, /sys/class/misc/dzmem/slots.
 */
#include <linux/fs.h>
#include <linux/io.h>
#include <linux/ktime.h>
#include <linux/miscdevice.h>
#include <linux/mm.h>
#include <linux/mutex.h>
#include <linux/smp.h>
#include <linux/module.h>
#include <linux/slab.h>
#include <linux/uaccess.h>
#include <asm/cacheflush.h>
#include <asm/outercache.h>
#include <asm/pgtable.h>

#include "dzmem.h"

static unsigned long base = 0x08000000;
static unsigned long size = 0x06000000;
static unsigned long pitch = 0x7E9000;		/* one slot: 1920 x 1080 x 4 */
static unsigned long nocache = 1UL << 4;	/* slots that refuse WB / WT */
static bool allow_wt;
static int guard;				/* 0 = log mixes, 1 = refuse them */
module_param(base, ulong, 0444);
MODULE_PARM_DESC(base, "physical start of the reserved slot region (page aligned)");
module_param(size, ulong, 0444);
MODULE_PARM_DESC(size, "bytes of the region (page aligned)");
module_param(pitch, ulong, 0444);
MODULE_PARM_DESC(pitch, "bytes per slot (page aligned): the unit of the type guard");
module_param(nocache, ulong, 0444);
MODULE_PARM_DESC(nocache, "bit mask of slots that refuse cached (WB / WT) mappings (DMA targets)");
module_param(allow_wt, bool, 0444);
MODULE_PARM_DESC(allow_wt, "with guard=1: allow WT mappings (WT is non-cacheable in the A9 L1)");
module_param(guard, int, 0644);
MODULE_PARM_DESC(guard, "0 = allow memory-type mixes on a slot (log + count), 1 = refuse them (EBUSY)");

/* ---- the per-slot type guard ---- */
enum { CL_WB, CL_WT, CL_NC, N_CL };
static const char *const cl_name[N_CL] = { "WB", "WT", "NC" };
#define MAX_SLOTS	32
static unsigned int n_slots;
static unsigned int live[MAX_SLOTS][N_CL];	/* live VMAs per slot and class */
static DEFINE_MUTEX(guard_mu);
static struct {
	u64 syncs, sync_bytes, sync_ns;
	u64 refused, mixed, inv_on_open, flush_on_close, flush_ns;
} st;

static int class_of(u32 mode)
{
	return mode == DZMEM_WB ? CL_WB : mode == DZMEM_WT ? CL_WT : CL_NC;
}

static void vma_slots(struct vm_area_struct *vma, unsigned int *s0, unsigned int *s1)
{
	unsigned long off = vma->vm_pgoff << PAGE_SHIFT;

	*s0 = off / pitch;
	*s1 = (off + (vma->vm_end - vma->vm_start) - 1) / pitch;
}

static phys_addr_t slot_pa(unsigned int s)
{
	return base + (phys_addr_t)s * pitch;
}

static size_t slot_len(unsigned int s)
{
	return min_t(unsigned long, pitch, size - (unsigned long)s * pitch);
}

static void l1_flush_this_cpu(void *unused)
{
	flush_cache_all();	/* clean + invalidate this CPU's L1 by set/way */
}

struct dzfile {
	u32 mode;		/* memory type of the next mmap */
};

static const struct file_operations dzmem_fops;

static pgprot_t prot_of(pgprot_t p, u32 mode)
{
	switch (mode) {
	case DZMEM_WT:
		return __pgprot_modify(p, L_PTE_MT_MASK, L_PTE_MT_WRITETHROUGH);
	case DZMEM_WC:
		return pgprot_writecombine(p);
	case DZMEM_UC:
		return pgprot_noncached(p);
	default:
		return __pgprot_modify(p, L_PTE_MT_MASK, L_PTE_MT_WRITEALLOC);
	}
}

static int dzmem_open(struct inode *ino, struct file *f)
{
	struct dzfile *d = kzalloc(sizeof(*d), GFP_KERNEL);

	if (!d)
		return -ENOMEM;
	d->mode = DZMEM_WB;
	f->private_data = d;
	return 0;
}

static int dzmem_release(struct inode *ino, struct file *f)
{
	kfree(f->private_data);
	return 0;
}

static void dzmem_vm_open(struct vm_area_struct *vma)
{
	unsigned int s0, s1, s;
	int c = class_of((u32)(uintptr_t)vma->vm_private_data);

	vma_slots(vma, &s0, &s1);
	mutex_lock(&guard_mu);
	for (s = s0; s <= s1; s++)
		live[s][c]++;
	mutex_unlock(&guard_mu);
}

static void dzmem_vm_close(struct vm_area_struct *vma)
{
	unsigned int s0, s1, s;
	int c = class_of((u32)(uintptr_t)vma->vm_private_data);

	vma_slots(vma, &s0, &s1);
	mutex_lock(&guard_mu);
	for (s = s0; s <= s1; s++) {
		if (live[s][c])
			live[s][c]--;
		if (c != CL_NC && !live[s][c]) {
			/* the last cached mapping of slot s: no dirty or stale line may
			 * stay for the next user (possibly of another type) */
			u64 t0 = ktime_get_ns();

			on_each_cpu(l1_flush_this_cpu, NULL, 1);
			outer_flush_range(slot_pa(s), slot_pa(s) + slot_len(s));
			st.flush_on_close++;
			st.flush_ns += ktime_get_ns() - t0;
		}
	}
	mutex_unlock(&guard_mu);
}

static int dzmem_vm_may_split(struct vm_area_struct *vma, unsigned long addr)
{
	return -EINVAL;		/* the guard counts whole VMAs */
}

static const struct vm_operations_struct dzmem_vm_ops = {
	.open      = dzmem_vm_open,
	.close     = dzmem_vm_close,
	.may_split = dzmem_vm_may_split,
};

static int dzmem_mmap(struct file *f, struct vm_area_struct *vma)
{
	struct dzfile *d = f->private_data;
	unsigned long off = vma->vm_pgoff << PAGE_SHIFT;
	unsigned long len = vma->vm_end - vma->vm_start;
	unsigned int s0, s1, s;
	int c = class_of(d->mode), o, rc;

	if (off >= size || len > size - off)
		return -EINVAL;
	if (d->mode == DZMEM_WT && !allow_wt && guard) {
		pr_warn_ratelimited("dzmem: %s[%d]: WT refused (guard=1, allow_wt=0)\n", current->comm,
				    task_pid_nr(current));
		return -EPERM;
	}
	vma->vm_page_prot = prot_of(vma->vm_page_prot, d->mode);
	vma->vm_flags |= VM_IO | VM_PFNMAP | VM_DONTEXPAND | VM_DONTDUMP | VM_DONTCOPY;
	/* the type of this mapping, for SYNC (no maintenance for WC / UC) */
	vma->vm_private_data = (void *)(uintptr_t)d->mode;
	vma->vm_ops = &dzmem_vm_ops;
	vma_slots(vma, &s0, &s1);
	mutex_lock(&guard_mu);
	for (s = s0; s <= s1; s++) {
		if (c != CL_NC && (nocache & (1UL << s))) {
			if (guard) {
				st.refused++;
				mutex_unlock(&guard_mu);
				pr_warn_ratelimited("dzmem: %s[%d]: %s map of slot %u refused (nocache)\n",
						    current->comm, task_pid_nr(current), cl_name[c], s);
				return -EBUSY;
			}
			st.mixed++;
			pr_warn_ratelimited("dzmem: %s[%d]: %s map of nocache slot %u ALLOWED (guard=0)\n",
					    current->comm, task_pid_nr(current), cl_name[c], s);
		}
		for (o = 0; o < N_CL; o++)
			if (o != c && live[s][o]) {
				if (guard) {
					st.refused++;
					mutex_unlock(&guard_mu);
					pr_warn_ratelimited("dzmem: %s[%d]: %s map of slot %u refused: %u live %s mapping(s)\n",
							    current->comm, task_pid_nr(current), cl_name[c], s,
							    live[s][o], cl_name[o]);
					return -EBUSY;
				}
				st.mixed++;
				pr_warn_ratelimited("dzmem: %s[%d]: %s map of slot %u MIXED with %u live %s mapping(s) (guard=0)\n",
						    current->comm, task_pid_nr(current), cl_name[c], s,
						    live[s][o], cl_name[o]);
				break;
			}
	}
	rc = remap_pfn_range(vma, vma->vm_start, (base + off) >> PAGE_SHIFT, len,
			     vma->vm_page_prot);
	if (rc) {
		mutex_unlock(&guard_mu);
		return rc;
	}
	for (s = s0; s <= s1; s++) {
		if (c != CL_NC && !live[s][c]) {
			/* the first cached mapping: no line of the slot is valid in L2
			 * (only NC users since the last flush; WT leaves L2 lines) */
			outer_inv_range(slot_pa(s), slot_pa(s) + slot_len(s));
			st.inv_on_open++;
		}
		live[s][c]++;
	}
	mutex_unlock(&guard_mu);
	return 0;
}

static long do_sync(struct file *f, struct dzmem_sync *s)
{
	struct mm_struct *mm = current->mm;
	struct vm_area_struct *vma;
	unsigned long addr = (unsigned long)s->addr, len = (unsigned long)s->len;
	phys_addr_t pa;
	u32 mode;
	u64 t0;
	long rc = 0;

	if (!len || s->addr + s->len < s->addr || !s->dir || s->dir > DZMEM_BIDIRECTIONAL)
		return -EINVAL;
	/* "L2 all ways" = outer_flush_all: BUG_ON(!irqs_disabled()) in
	 * l2c210_flush_all, meant for one core at suspend / kexec. Called here
	 * it oopsed (2026-11-20, .236). By range only. */
	if (s->flags & DZMEM_SYNC_L2_ALL)
		return -EOPNOTSUPP;
	mmap_read_lock(mm);
	vma = find_vma(mm, addr);
	if (!vma || vma->vm_start > addr || addr + len > vma->vm_end ||
	    !vma->vm_file || vma->vm_file->f_op != &dzmem_fops) {
		rc = -EFAULT;			/* not (all) inside one dzmem mapping */
		goto out;
	}
	mode = (u32)(uintptr_t)vma->vm_private_data;
	pa = base + ((phys_addr_t)vma->vm_pgoff << PAGE_SHIFT) + (addr - vma->vm_start);
	t0 = ktime_get_ns();
	if (mode == DZMEM_WC || mode == DZMEM_UC ||
	    (mode == DZMEM_WT && s->dir == DZMEM_TO_DEVICE)) {
		/* only the write buffer: write-through data is in DDR already
		 * (the line walk cost 12 ms per 720p frame for nothing) */
		wmb();
	} else if (s->dir == DZMEM_TO_DEVICE) {
		/* L1 first (its dirty lines go to L2), then L2 to DDR */
		__cpuc_flush_dcache_area((void *)addr, len);
		outer_clean_range(pa, pa + len);
	} else if (s->dir == DZMEM_FROM_DEVICE) {
		/* L2 first (so L1 refills from DDR), then L1 (clean + invalidate:
		 * the only by-address L1 op exported; a CPU write still in L1
		 * would go back over the DMA data - do not write a DMA target) */
		outer_inv_range(pa, pa + len);
		__cpuc_flush_dcache_area((void *)addr, len);
	} else {
		__cpuc_flush_dcache_area((void *)addr, len);
		outer_flush_range(pa, pa + len);
	}
	s->ns = ktime_get_ns() - t0;
	st.syncs++;
	st.sync_bytes += len;
	st.sync_ns += s->ns;
out:
	mmap_read_unlock(mm);
	return rc;
}

static long dzmem_ioctl(struct file *f, unsigned int cmd, unsigned long arg)
{
	struct dzfile *d = f->private_data;
	void __user *u = (void __user *)arg;

	switch (cmd) {
	case DZMEM_IOC_INFO: {
		struct dzmem_info i = { .base = base, .size = size, .page = PAGE_SIZE,
					.version = DZMEM_VERSION };

		return copy_to_user(u, &i, sizeof(i)) ? -EFAULT : 0;
	}
	case DZMEM_IOC_MODE: {
		u32 m;

		if (copy_from_user(&m, u, sizeof(m)))
			return -EFAULT;
		if (m > DZMEM_UC)
			return -EINVAL;
		d->mode = m;
		return 0;
	}
	case DZMEM_IOC_SYNC: {
		struct dzmem_sync s;
		long rc;

		if (copy_from_user(&s, u, sizeof(s)))
			return -EFAULT;
		rc = do_sync(f, &s);
		if (!rc && copy_to_user(u, &s, sizeof(s)))
			return -EFAULT;
		return rc;
	}
	}
	return -ENOTTY;
}

static ssize_t stats_show(struct device *dev, struct device_attribute *a, char *buf)
{
	return sysfs_emit(buf, "syncs %llu bytes %llu ns %llu refused %llu mixed %llu inv_on_open %llu "
			  "flush_on_close %llu flush_ns %llu guard %d\n", st.syncs, st.sync_bytes,
			  st.sync_ns, st.refused, st.mixed, st.inv_on_open, st.flush_on_close,
			  st.flush_ns, guard);
}
static DEVICE_ATTR_RO(stats);

static ssize_t slots_show(struct device *dev, struct device_attribute *a, char *buf)
{
	unsigned int s;
	int n = 0;

	mutex_lock(&guard_mu);
	for (s = 0; s < n_slots; s++)
		if (live[s][CL_WB] || live[s][CL_WT] || live[s][CL_NC])
			n += sysfs_emit_at(buf, n, "slot %u WB %u WT %u NC %u\n", s, live[s][CL_WB],
					   live[s][CL_WT], live[s][CL_NC]);
	mutex_unlock(&guard_mu);
	return n;
}
static DEVICE_ATTR_RO(slots);

static struct attribute *dzmem_attrs[] = { &dev_attr_stats.attr, &dev_attr_slots.attr, NULL };
ATTRIBUTE_GROUPS(dzmem);

static const struct file_operations dzmem_fops = {
	.owner          = THIS_MODULE,
	.open           = dzmem_open,
	.release        = dzmem_release,
	.mmap           = dzmem_mmap,
	.unlocked_ioctl = dzmem_ioctl,
};

static struct miscdevice dzmem_dev = {
	.minor = MISC_DYNAMIC_MINOR,
	.name  = "dzmem",
	.fops  = &dzmem_fops,
	.mode  = 0660,			/* udev: group video (the ebaz user) */
	.groups = dzmem_groups,
};

static int __init dzmem_init(void)
{
	int rc;

	if (!size || (base | size) & ~PAGE_MASK) {
		pr_err("dzmem: base 0x%lx / size 0x%lx not page aligned\n", base, size);
		return -EINVAL;
	}
	if (region_intersects(base, size, IORESOURCE_SYSTEM_RAM, IORES_DESC_NONE) !=
	    REGION_DISJOINT) {
		pr_err("dzmem: 0x%lx + 0x%lx overlaps System RAM: refused (is the "
		       "reserved-memory node in effect? /proc/iomem)\n", base, size);
		return -EINVAL;
	}
	if (!pitch || (pitch & ~PAGE_MASK) || DIV_ROUND_UP(size, pitch) > MAX_SLOTS) {
		pr_err("dzmem: pitch 0x%lx: not page aligned or more than %d slots\n", pitch, MAX_SLOTS);
		return -EINVAL;
	}
	n_slots = DIV_ROUND_UP(size, pitch);
	rc = misc_register(&dzmem_dev);
	if (rc)
		return rc;
	pr_info("dzmem: /dev/dzmem = 0x%lx + 0x%lx (%lu MB), %u slots of 0x%lx, "
		"guard %d (%s), nocache 0x%lx, v%d\n", base, size, size >> 20, n_slots, pitch, guard,
		guard ? "mixes refused" : "mixes allowed + logged", nocache, DZMEM_VERSION);
	return 0;
}

static void __exit dzmem_exit(void)
{
	misc_deregister(&dzmem_dev);
}

module_init(dzmem_init);
module_exit(dzmem_exit);
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("DEBAZAROS video slots mapped cached, cache sync by range (experiment)");
