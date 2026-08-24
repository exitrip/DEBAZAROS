
Source is in sw/fbfeed/fbfeed.c with a Makefile. It builds clean with -Wall -Wextra and I verified the write path on the host against a file:

offset path: two frames written at byte 16588800, content matched the input exactly, and nothing was written before the offset;
fill mode: -c 00FF00 produced 00 ff 00 ff = 0xFF00FF00 in a8r8g8b8, which is green;
non-page-aligned start (offset 4100): handled by the page-align + shift logic, correct bytes at the correct place.
What it does
It reads raw BGRA frames from stdin and copies each one into a scanout slot. It mmaps either /dev/mem at a physical address, or /dev/fbN at a byte offset. Defaults are display 1's parked slot: /dev/mem, 0x08FD2000, 1280×720, stride 5120.

Options: -d device, -a physical address, -o byte offset, -w/-h geometry, -s destination stride, -c RRGGBB one-shot fill, -v throughput report.

Use on the target
Cross-compile:


make CROSS_COMPILE=arm-xilinx-linux-gnueabihf-
make install TARGET=ebaz@ebaz4205
Identify the ports first. This writes one solid frame and exits:


./fbfeed -a 0x08FD2000 -c FF0000      # display 1 goes red
./fbfeed -a 0x08000000 -c 0000FF      # display 0 goes blue
Then feed the second stream. Add this next to the existing ffmpeg line in debazarosit.sh:


ffmpeg -stream_loop -1 -re -i /home/ebaz/clip2.mp4 -vf scale=1280:720 \
       -pix_fmt bgra -f rawvideo pipe:1 | /home/ebaz/fbfeed -a 0x08FD2000 -v &
Display 0 keeps its current -f fbdev /dev/fb0 line. No DTS change and no kernel change are needed.

Two cautions
Speed. The reserved region is no-map, so ARM maps it through /dev/mem as uncached. Uncached writes on this A9 run at tens of MB/s, and one 720p30 stream needs 111 MB/s. Run with -v and read the MB/s line. hdmi2.elf uses the same mapping, but it does not push full frames at 30 fps, so this is untested at video rate.

If it is too slow, switch to the write-combined path: grow the fb node to 1280×3960 (row 3240 is exactly 0x08FD2000), keep display 0 on -f fbdev /dev/fb0, and run fbfeed -d /dev/fb0 -o 16588800 for display 1. That stays inside one simplefb instance, so the driver check does not apply.

Tearing. There is no vsync signal available to userspace yet, and the VDMA is parked on one frame. Frames can tear. A VTC interrupt through UIO would fix that later.



Added a per-frame barrier to fbfeed.c while I was in there — it matters for exactly the reason below. Rebuilt and re-verified.

The two mappings are not the same kind of memory
The speed difference is not in the copy loop. It is in the page-table attribute the kernel gives the mapping. That attribute tells the CPU how it may treat stores.

/dev/mem path. drivers/char/mem.c decides:


	if (file->f_flags & O_DSYNC)
		return 1;
	return addr >= __pa(high_memory);
	...
	if (uncached_access(file, offset))
		return pgprot_noncached(vma_prot);
fbfeed opens with O_SYNC, so you get pgprot_noncached. On ARM that is:


#define pgprot_noncached(prot) \
	__pgprot_modify(prot, L_PTE_MT_MASK, L_PTE_MT_UNCACHED)
L_PTE_MT_UNCACHED is the strictest ARMv7 attribute. Stores are not buffered and not merged. Each 32-bit store becomes its own bus transaction, and the core waits for it.

/dev/fbN path. simplefb maps the memory kernel-side with ioremap_wc, and ARM's fb_pgprotect sets the user mapping:


static inline void fb_pgprotect(struct file *file, struct vm_area_struct *vma,
				unsigned long off)
{
	vma->vm_page_prot = pgprot_writecombine(vma->vm_page_prot);
}
pgprot_writecombine selects L_PTE_MT_BUFFERABLE. Stores are bufferable. The store retires into the write buffer, and the core continues immediately.

What that changes at the bus
Three effects, in order of size:

The core stops waiting. With the uncached attribute, a long memcpy is a chain of blocking stores. Each one pays the full latency to the DDR controller through the L2 and the interconnect. With the bufferable attribute, the write buffer absorbs the stores and drains behind the program.
Transactions get longer. A frame is 3.69 MB. As single 4-byte writes that is about 921,600 bus transactions. When the write buffer can drain in cache-line-sized bursts, it becomes about 115,200. The address and arbitration overhead per transaction disappears.
DDR3 stops wasting bursts. The DDR3 minimum burst is 8 beats. On the 32-bit PS bus that is 32 bytes. A 4-byte write uses the data mask and throws away the rest of the burst. Payload efficiency is near 12%. Full-burst writes reach near 100%.
Expect roughly ten times more throughput. Uncached writes on this A9 usually land in the tens of MB/s. Write-combined writes usually land in the hundreds. One 720p30 stream needs 111 MB/s, and two need 221 MB/s, so the difference decides whether this works at all.

Why it also protects the picture
This is the part that touches your stability problem. DDR bus time, not payload, is the shared resource. The two VDMAs read 221 MB/s at 720p30. If the CPU writes the same payload with 12% burst efficiency, it can occupy several times that much DDR time. The DDR controller then delays the VDMA read ports. A late VDMA read starves the stream, the v_axi4s_vid_out drops out of lock, and the output formatter zeroes sync and DE — the "no signal" behavior already documented for this design. So an inefficient write path can look like a gateware fault.

Write-combining removes most of that bus time.

The barrier
Bufferable memory needs one guarantee that uncached memory gives for free. A store can still sit in the write buffer after memcpy returns. The VDMA reads DDR directly and does not snoop the CPU. So fbfeed now runs __sync_synchronize() once per frame to drain the buffer. The cost is one barrier per frame, which is nothing.

How to switch to it
Change the framebuffer node to cover both slots. Display 1 sits 16,588,800 bytes above display 0, and 16,588,800 / 5120 = row 3240. So the node needs 3240 + 720 = 3960 rows:


   hdmi_fb0: framebuffer@8000000 {
          compatible = "simple-framebuffer";
          reg = <0x08000000 (1280 * 3960 * 4)>;   /* 20,275,200 bytes */
          width = <1280>;
          height = <3960>;
          stride = <(1280 * 4)>;
          format = "a8r8g8b8";
          status = "okay";
   };
That is one simplefb instance, so the num_registered_fb check does not apply. The region ends at 0x09356000, inside the 128 MB reservation.

Then drive both displays through the same device, so both writes are write-combined:


ffmpeg ... -pix_fmt bgra -f rawvideo pipe:1 | fbfeed -d /dev/fb0 -o 0        -v &
ffmpeg ... -pix_fmt bgra -f rawvideo pipe:1 | fbfeed -d /dev/fb0 -o 16588800 -v &
I suggest you use fbfeed for both, and not ffmpeg -f fbdev for display 0. The fbdev muxer would see a 1280×3960 display and may not place a 720-line frame where you expect.

Do not try to fix it by dropping O_SYNC
It looks tempting, because without O_SYNC the same uncached_access() test returns 0 for this address, and you get a normal cached mapping. That is the fastest of all for the CPU. It is also wrong here. Dirty lines would sit in L1 and L2, and the VDMA would scan out stale DDR. Userspace has no reliable way to clean those caches on ARM. Write-combining is the correct compromise: no cache maintenance, and no per-store stall.

Measure it before you commit
Run both targets and compare the -v line:


cat /dev/zero | ./fbfeed -a 0x08FD2000 -v            # uncached path
cat /dev/zero | ./fbfeed -d /dev/fb0 -o 16588800 -v  # write-combined path
/dev/zero removes the decoder from the measurement, so you see the write path alone. If the uncached number is already above about 150 MB/s, keep the simple /dev/mem setup and skip the DTS change.