# Slot memory: problem, target architecture, test plan (2026-11-20)

This file replaces the test plan for the cached slots (ROADMAP.md section
19 step 5, test backlog "dzmem part 2"). It records what we know, the
error in the first design, the target architecture and the tests that
give measurements we can trust.

## 1. The problem

A slot is 8.3 MB of reserved DDR (1920 x 1080 x 4, pitch 0x7E9000). The
display VDMAs read slots. The capture VDMA writes slot 4. Several CPU
writers put pictures into the same slots:

| Writer | Process | Pattern |
|---|---|---|
| debazd paint (draw ops, text, sprites, image load, fade, transforms) | debazd, pixel thread | small rectangles, sometimes the full slot, read-modify-write |
| movie | fbfeed | full movie rectangle, every frame |
| image sequence | debazd (anim.c) | full frame per flip (JPEG decode) |
| script | dzlua | dirty rectangle or full frame per script frame |
| ASCII, slit, grab, save, splat | debazd | READ one slot (often a live one), write another |
| capture | PL (VDMA S2MM) | full input frame |

The problem to solve is NOT "make reads and writes faster". It is:

**Let several writers (CPU processes and DMAs) share the slots so that
the pixels are always correct, with less RAM and lower latency than the
private copies, and without taking CPU time or DDR bandwidth away from
movie decode.**

Movie decode is the limit of the system (decoder ~130 % CPU, fbfeed ~30 %
for one 720p movie). Each private copy costs 8.3 MB of RAM. A first draw
costs a full uncached read of the slot (88 ms).

The private copies (debazd shadows, transform buffers, the dzlua canvas)
exist only because the slots are mapped uncached, and uncached reads are
slow (105-127 MB/s). A cached mapping removes that reason. But it adds
a duty that the uncached design did not have: **coherence**. Every cached
copy of a slot byte must agree with:

1. the VDMAs, which do not snoop the caches (they read and write DDR);
2. every other CPU mapping of the same byte, in any process, on either
   core.

Correctness comes first, then speed. A fast path that can lose a write
once an hour is not acceptable in an installation that runs for days.

## 2. What we know

### Facts measured on .236 (trusted: repeatable, simple setup)

dzmemtest, no other slot writer running, slot 10 (8.3 MB):

| Mapping | Write MB/s | Read MB/s | Fade 1280x720 in place |
|---|---|---|---|
| /dev/mem (strongly ordered) | 296 | 127 | 106 ms |
| dzmem WB (write-back) | 209 | 238 | 19.5 ms |
| dzmem WT (write-through) | 327 | 132 | 74 ms |
| dzmem WC (non-cacheable, bufferable) | 329 | 153 | 91 ms |
| dzmem UC | 76 | 53 | 206 ms |

- A clean by range costs ~3 us per KB (the PL310 does one operation per
  32-byte line, dirty or not): full slot 16.5-18.5 ms, invalidate 17.6
  ms, a 100 px rectangle row by row 0.3 ms.
- `dzmemtest check`: clean and invalidate work (0 stale words after the
  sync). WT writes reach DDR without a clean.
- Capture: a WB read of slot 4 without an invalidate is stale; with
  FROM_DEVICE before the read it is correct.
- In-process WB buffer = malloc speed (fade 720p 21.7 ms against 22.6).

### Facts from the A/B runs (less trusted: see section 3)

- Part 1 (WT writes, WB reads): grab -18 %, sprite grab -28 %, rect
  splat 2.5-3x, the rest equal. Movies, scripts, brush, text: equal.
- Part 2 (paint buffer = WB slot): RAM in paint buffers 24.3 MB -> 0,
  first draw 88 -> 0.7 ms, grab of the own slot 90 -> 0.2 ms, fade 62 ->
  53 ms, rect 0.5 -> 1.0 ms and brush 0.34 -> 0.47 ms (the clean ioctl).
- The board HUNG in the first test that mixed part 2 with a live slot.

### The fact the first design got wrong

**The Cortex-A9 L1 data cache treats every write-through page as
non-cacheable** (Cortex-A9 TRM r4p1, section 7.4.3). Only the PL310 L2
caches WT data. The first design assumed that "a write-through store
updates any cached copy". In the L1 that is false:

- A WT store goes around the L1. A line of the same address that sits in
  the L1 (loaded through the WB mapping) keeps the OLD data. A later WB
  read returns the old pixels.
- If that L1 line is dirty (part 2: debazd wrote through WB), its
  eviction later writes the old bytes over the newer WT data in DDR: a
  LOST WRITE.
- Part 2's fade read each row through WB (the line goes into the L1) and
  stored it through WT (around the L1): the L1 kept the pre-fade line.
  The next WB write to that line made it dirty with stale bytes.
- The WT read numbers agree: WT reads 132 MB/s = barely more than
  uncached, because the L1 does not cache them.

So part 1 could give stale reads (splat, grab, ASCII from a movie slot),
and part 2 could lose writes. The ARM forum thread "L1 cache eviction
corrupting DDR on A9" shows the same failure on other boards. A
mismatch like this corrupts pixels. By itself it does not explain a
kernel hang. The cause of the hang is still OPEN (section 5, T2).

## 3. Why the tests so far were not trustworthy

1. **Wrong model.** The design depended on CPU coherence between WB and
   WT mappings, and the A9 does not give it. No test checked that
   assumption by itself.
2. **The production stack ran during the benchmarks.** debazd resume
   restarted scripts after each restart, autosave changed the state
   between rounds, LFOs and effects ran, and movies decoded on both
   cores. The results had a large spread (flower over a movie 99-134 ms)
   and the A/B pairs did not start from the same state.
3. **Testing continued on a tainted kernel.** The `outer_flush_all` oops
   happened first. Then the board was not rebooted, so we cannot say
   which event caused the hang.
4. **No crash evidence.** There is no serial console log,
   `CONFIG_PANIC_TIMEOUT=0`, no lockup detector, no netconsole. The hang
   left nothing to examine.
5. **Weak correctness oracle.** `dzmemtest ddr` compares the cached view
   with DDR once, after the work stops. It cannot see a write that a
   stale line evicted earlier: both views then hold the same wrong
   pixels. Visual checks on the USB capture cannot see a few lost pixels.
   No test was ever shown to FAIL on a known-bad setup. A test that
   cannot fail proves nothing.
6. **Small samples, OSC in the loop.** The scripts timed 1-20 calls
   through OSC round trips with fences, ran 2 rounds, and gave a mean
   with no spread. First-call costs were mixed into the averages.
7. **Too many changes at once.** Part 2 changed the paint buffer,
   splat, fade, ASCII, transforms and /img/file together. After the hang
   no single change could be blamed.

## 4. Target architecture

### 4.1 One rule

**At any time, all CPU mappings of a slot that are in use have the SAME
memory type.** If they are all WB, the SCU keeps the two L1s coherent and
the L2 is shared: CPU users in all processes see each other's writes with
no maintenance. If they are all non-cacheable (WC), the caches play no
part. The only maintenance left is the DMA boundary, at known points.

WT is dropped. On this CPU it is the worst choice: non-cacheable in L1,
cacheable in L2, so it mismatches with both WB and WC.

### 4.2 Slot states

| State | Who writes | CPU memory type (all mappings) | DMA maintenance |
|---|---|---|---|
| STILL | debazd paint, a dzlua script that draws into the slot | WB | writer cleans its dirty rectangle before it is shown (= present) |
| STREAM | fbfeed, anim decode, dzlua layer mode over a movie, slit target | WC | none (writes reach DDR; wmb) |
| CAPTURE | the capture VDMA | WC or UC, read only | none (reads come from DDR) |

- STILL gets all the gains: no 8 MB copy, cached reads (2x) and
  read-modify-write (5x), a first draw with no read.
- STREAM and CAPTURE stay as fast as today (WC write 329 MB/s, read
  153 MB/s: about the old /dev/mem path). Splat, ASCII, slit and grab
  that read a live slot read WC: correct, and no slower than today.
- Expected net gain (from the measurements, to confirm in T4): RAM -8.3
  MB per painted slot, first draw 88 -> ~1 ms, 2x reads from STILL slots
  (grab, save, ASCII and slit sources, sprite grab). No gain for movie
  playback. That is not the goal.

### 4.3 Transitions (debazd is the authority: it starts every writer)

- **STILL -> STREAM** (a movie, sequence or layer script starts on a
  painted slot): debazd stops its WB use of the slot, cleans and
  invalidates the whole slot (BIDIRECTIONAL, ~18 ms), unmaps its WB
  mapping, THEN starts the writer.
- **STREAM -> STILL** (the writer stopped and debazd paints there):
  debazd waits until the writer process has exited (waitpid, already
  done by dz_kill_group), maps WB, invalidates the slot (~18 ms), then
  paints.
- Transitions happen at human time (a cue, a button). 18 ms each is
  acceptable. They never happen per frame.

### 4.4 The module enforces the rule (dzmem v2)

Discipline in user space is not enough: the hang showed what happens
when one path forgets. dzmem v2 makes a mismatch impossible:

1. **Per-slot type guard.** The module counts the live VMAs per slot and
   per type (vm_operations open/close, so fork and munmap count). An
   mmap whose type differs from a live mapping of the same slot fails
   with -EBUSY and a kernel log line (process, slot, both types). A
   forgotten transition then becomes a loud start failure, not silent
   corruption. Slots are page aligned (0x7E9000 = 2025 pages).
2. **The module owns the transitions.** When the LAST WB VMA of a slot
   closes (munmap, exit, or a debazd crash), the module flushes the L1
   on each CPU (`on_each_cpu`, full L1 clean + invalidate, 32 KB, a few
   us) and then the L2 by physical range (~18 ms). When the FIRST WB VMA
   of a slot opens, it invalidates the slot in the L2 (no dirty lines
   can exist: the guard allowed no other cacheable mapping). User space
   then never needs to get the transition maintenance right, and a crash
   cannot leave dirty lines behind.
3. **No-cache slots.** Module parameter `nocache=<mask>` (default: slot
   4): a WB mmap of those slots is refused.
4. **WT refused** unless a test parameter enables it (`allow_wt=1`, for
   dzmemtest only).
5. **Counters** in sysfs: cleans, bytes, ns, refused mmaps, transition
   flushes. The tests read them before and after.

The guard does not see /dev/mem and /dev/fb0. Rules for them:
`hdmi2` writes test patterns into the display slots only in its menu
mode, so debazd must start it without patterns (check this). capstat
and other diagnostics only READ (a stale read is harmless). Nothing
writes /dev/fb0 when dzmem is loaded. The kernel has no cacheable alias
of the slots: the region is no-map, and simplefb's mapping is WC with no
writes.

### 4.5 libdz and the writers

- `dz_slot(n)` returns the mapping of the slot's CURRENT state: WB while
  STILL (debazd and dzlua), WC otherwise. `dz_slot_rd()` and
  `dz_slot_wb()` go away (one pointer per slot and state, no aliases).
- debazd keeps a slot-state table (STILL / STREAM / CAPTURE) and shows
  it in `/surface/<s>/status` and `/stats`.
- present on a STILL slot = clean of the dirty rectangle (row by row
  when that is much less than the bounding box), as in part 2.
- fade on a STILL slot = WB in place + one clean. The WT-store trick
  goes. If T4 shows it slower than the RAM path (old 62 ms), fade only
  the visible window (crop x mode size, 44 % of the slot at 720p), or
  run fade-heavy surfaces in RAM. The data decides.
- transforms: as part 2 (move to RAM, back to the slot when idle), or WB
  in place. The data decides.
- fbfeed and anim: WC (`-d /dev/dzmem`, mode WC).
- dzlua: a canvas in the slot (WB) when the slot is STILL, WC layer
  mode when the slot is STREAM. That is the next step after debazd, not
  in the first round.

## 5. Test plan

### 5.0 Rules for every test

1. **Fresh boot** for each session and after any oops, taint or hang.
   Record `uname -a`, `cat /proc/sys/kernel/tainted`, the dzmem version,
   the git hash of sw/, the bitstream and the output mode. tainted must
   be 0 or 4096 (bit 12 = an out-of-tree module, set at every boot of
   .236 by our own modules; measured 2026-11-21); stop the session on any
   other bit (an oops sets 128 / 512 / 4).
   Reboots and power cycles: `sw/tools/boardpower.sh reboot [-S|-H]`
   (ssh, else the serial console, else a USB-C power cycle of the
   laptop port that powers .236; ~23-33 s to ssh).
2. **Serial console** on ttyPS0 (115200) logged on the laptop for every
   test (READY 2026-11-21: .236's console is a CH340 on the laptop,
   `sw/tools/boardpower.sh log start` writes it with time stamps to
   `~/debaz-serial/10.42.0.236.log` and survives power cycles). Optional for the first tests: an image
   with `CONFIG_SOFTLOCKUP_DETECTOR`, `CONFIG_DETECT_HUNG_TASK`,
   `CONFIG_PANIC_TIMEOUT=10` and `CONFIG_NETCONSOLE=m`, so that a hang
   becomes a panic with a log. The hardware watchdog stays off unless
   the user is present.
3. **Bench mode** (script `sw/tools/bench/benchmode.sh`, to write):
   - stop debazd and dzweb (systemd units, or by PID), and stop every
     movie, fbfeed, dzlua, arecord and ffmpeg (check with `ps`);
   - keep hdmi2 running (the VDMAs scan), and record its PID;
   - output mode fixed at 1280x720@60 for all tests (one mode for every
     number);
   - no HDMI_2 source connected, except in T2c and T6;
   - start debazd with `DZ_NO_RESUME=1` (no resume, no autosave) and a
     fixed start state: `/state/recall bench` (LFOs off, effects off,
     xfade 0, osc gains 0);
   - before each run, `top -bn1` shows no other process above 2 % CPU.
4. **A test must fail before its pass counts.** Each correctness test
   also runs on a known-bad setup and must detect it.
5. **Statistics.** At least 30 timed iterations per operation after 3
   warm-up iterations (warm-up reported separately). Report median,
   p95 and min. A/B as A B A B A B (3 rounds each, a debazd restart per
   round). A difference counts only if it is more than 2x the spread
   between rounds of the same mode.
6. **Time inside the process.** debazd times each OSC message itself
   (`/stats/op` = name, count, median, p95; to write) with
   clock_gettime around the handler. OSC round trips only for latency
   tests, and named as such.
7. **One change per step.** Each architecture step (section 6) is
   built, tested and committed alone before the next.

### T0 Instruments (once per session, 5 min)

- tainted = 0; the serial log shows the boot; dzmem loaded, its sysfs
  counters are 0.
- `dzmemtest info`: base 0x0800_0000, 96 MB, version 2.

### T1 Primitives (no debazd, 15 min)

`dzmemtest bench` per type, 30 runs each, slot 10: write, read, fade in
place, clean of 8.3 MB / 768 KB / 100 rows. Also an **L1 test**: read
the same 16 KB 1000 times through WB, WT and WC. WB = L1 speed (GB/s);
WT and WC much slower. This confirms the A9 TRM fact on this silicon.
Pass = the numbers repeat within 10 % of section 2.

### T2 Coherence (the core of the plan; serial console required)

Tool: `dzmemtest coh` (to write). Two processes pinned to CPU 0 and
CPU 1 (`taskset`) share one slot. Each owns alternate 16-byte halves of
every 32-byte cache line (false sharing on purpose), writes a sequence
number per word in a loop, and checks its own words. A third checker
reads DDR through UC every 100 ms and counts lost writes (a word whose
sequence number went BACKWARDS).

| Case | Mappings | Expected |
|---|---|---|
| T2a bad: WB + WT | P0 WB, P1 WT | FAILS (lost or stale words). This proves the test works. If it does not fail in 10 min, the test is not good enough: make it harder before going on. |
| T2b bad: WB + WC | P0 WB, P1 WC | FAILS |
| T2c design: WB + WB | both WB, + clean before the checker reads | 0 errors in 30 min |
| T2d design: WC + WC | both WC | 0 errors in 30 min |
| T2e guard | v2 module: the second mmap of T2a / T2b | refused with -EBUSY, log line |
| T2f crash | P0 WB writes, SIGKILL; then UC read | DDR = the last values (the module flushed at close) |

**Hang search** (with the user present, serial console on): run T2a for
30 min on the v1 module.
- If the board hangs, the hardware attribute mismatch alone hangs it.
  The guard (T2e) is then a safety requirement, not an option.
- If it does not hang, the hang was elsewhere (part 2 code, ioctl
  concurrency, the taint). Then run the old bench-mem on part 2 once
  more with the serial console, to get the kernel's last words.

### T3 Transitions (debazd with the v2 module, 20 min)

Script with an oracle: paint a known pattern (a numbered grid) into slot
9 (STILL). Start a movie on 9 (-> STREAM), stop it, paint the grid
again (-> STILL). After each step, compare a UC read of DDR with the
expected image (`dzmemtest ddr -s 9 -e expected.raw`: to write; the host
self test renders the same grid through `peek` to make expected.raw).
Repeat 200 times, then once with SIGKILL of debazd in the middle of a
STILL paint.
Pass = 0 mismatches. The transition counters equal the number of steps.
Each transition takes < 25 ms.

### T4 Operation timing A/B (bench mode, 45 min)

A = uncached (`DZ_DZMEM=0`), B = target. Slot 9 STILL. Use the same op
list as bench-direct.lua, plus fade on the visible window. Use the
in-process times (rule 6), 30 iterations, 3 rounds per mode, A B A B A B.
Also record RAM (`/surface/mem`) and the dzmem clean counters (ms of
clean per op). Separately, with OSC round trips: first draw after a
restart, 10 restarts per mode.
Decision table per op: keep the slot path, or use RAM for this op
(fade, transforms), from the medians.

### T5 Scenario (bench mode + one 720p movie, 30 min, serial console)

Run the same OSC script for A and B, twice each. The script does: a
movie on slot 6 (STREAM); paint, fades and text on slot 9 (STILL),
shown on display 1; ASCII from 6 into 8; slit from 6 into 7; grab of 6
into 9 every 10 s; one transition per minute (a movie starts on 9 and
stops again). Measure movie fps (`/movie/6/stats`), CPU per process
(`pidstat 5`), `/event/video` count, paint-op medians. Oracle: at the
end, paint the grid on 9 and compare it with DDR (T3 tool).
Pass = B fps >= A fps - 1, video events B <= A, 0 mismatches, no hang.

### T6 Soak (2 h, with the user's approval, serial console, USB capture)

Run T5 with a loop over a show (cues with fades, a script in layer mode,
an image sequence) and the HDMI_2 capture shown on a display. Every 10
min: grid check on a STILL slot, tainted = 0, RAM free, dzmem counters.
Record the USB capture at 1 fps for a later look.
Pass = no hang, no oops, 0 mismatches, RAM stable (+-2 MB), and no
visual fault in the record.

### Report

One table per test: date, git hash, tainted, mode, N, median / p95 /
min, pass / fail. Results go into ROADMAP.md section 19 and replace the
earlier A/B numbers when they disagree.

## 6. Order of work

1. Fix the documentation of the WT error (done 2026-11-20: dz_map.h,
   sw/README.md, CLAUDE.md, ROADMAP.md).
2. dzmemtest: `coh`, the L1 test, `ddr -e`. Run T0-T2 on the v1 module
   (T2a/T2b must fail; the hang search). No debazd change needed.
3. dzmem v2: guard, transitions in the module, nocache, counters; T2e /
   T2f.
4. libdz + debazd: slot states, one mapping per state, WT gone, fade
   trick gone, `/stats/op`, benchmode.sh; T3, T4.
5. fbfeed and anim on WC; T5.
6. T6 soak with the user. Then dzmem goes into the image (loaded at boot).
7. Later: the dzlua canvas in a STILL slot (WB).

Until step 4 passes, run the boards WITHOUT dzmem loaded (the old
uncached path). The code that is not committed (part 1 + part 2) is
only safe with the module unloaded.

Sources: Cortex-A9 TRM r4p1 section 7.4.3 (write-through treated as
non-cacheable), quoted in community.arm.com thread 10580; "L1 Cache
Eviction Corrupting DDR on A9", community.arm.com embedded forum 6965.

## 7. Results

### 2026-11-21, .236, dzmem v1, fresh boot, bench mode (debazd stopped)

tainted 4096 (debaz_audio, out of tree). Serial log running.

**T1** (`dzmemtest l1`, `bench -n 3`): the same 16 KB read 2000 times:
WB 1293 MB/s, WT 213, WC 95, UC 28. WB hits the L1, WT only the L2: the
A9 TRM fact holds on this silicon. bench = section 2 within 5-10 % (WB
215 / 238 MB/s, WT 333 / 127, WC 330 / 144, UC 81 / 50; full-slot clean
16.1 ms, invalidate 15.2 ms).

**T2** (`dzmemtest -t 30 coh A B`, 256 KB of slot 10, two processes on
CPU 0 / CPU 1, each owns half of every 32-byte line):

| A | B | Lost writes A | Lost writes B | DDR wrong at the end | Result |
|---|---|---|---|---|---|
| WB | WB | 0 | 0 | 0 | PASS |
| WC | WC | 0 | 0 | 0 | PASS |
| WT | WT | 0 | 0 | 0 | PASS |
| UC | UC | 0 | 0 | 0 | PASS |
| WB | WT | 0 | 30,633,995 (5.4 % of all) | 0 * | FAIL |
| WB | WC | 7,492 | 536,349 | 15,122 words of B | FAIL |
| WT | WC | 431,407 | 0 | 0 * | FAIL |

\* the test writes a lost word again, so the end state hides most losses;
WB + WC is wrong even then (A's final clean put stale halves of B into
DDR). Every mix of two types loses writes, also WT + WC (L2 cacheable
next to non-cacheable). One type per slot is a measured rule.

**T2f on v1** (`crash`, a child writes through WB and SIGKILLs itself):
16 KB: 2000 of 4096 words not in DDR, 64 KB: 8960 of 16384: FAIL, as
expected (v1 leaves a dead writer's dirty lines in the caches).
**T2e on v1** (`guard`): every mix mapped: FAIL, as expected.

**Hang search**: all bad mixes for 30 s each: no hang. WB + WT for
30 min (dzmem v1): 1,612,350,064 lost writes (5 % again), NO hang, no
kernel message, taint unchanged. A type mix corrupts data but does not
hang the kernel by itself: the Nov 20 hang had another cause (still
open: the part 2 debazd code, the ioctl under load, or the earlier oops).

### 2026-11-21, dzmem v2 on .236

- guard (with guard=1): PASS (mixes EBUSY, WT EPERM, slot 4 WB EBUSY, WC
  after the WB unmap mapped). crash: 16 / 64 KB: 0 words lost: PASS
  (flush on the last close, ~5 ms per slot). coh WB+WB, WC+WC: PASS.
- User decision (2026-11-21): do NOT forbid mixes that corrupt but stay
  stable before the corruption has been judged on a monitor. So `guard`
  is a runtime parameter, default 0 = mixes allowed, logged ("MIXED")
  and counted (`mixed` in /sys/class/misc/dzmem/stats); 1 = refused.
  The flush on the last close stays (it only prevents corruption). libdz
  itself still keeps one type per slot.
- Visual (`dzmemtest mixshow A B`, slot 10 on both displays, effects off:
  LFOs off, /fx/xfade 0, osc gains 0, /fx/identity; USB capture of
  HDMI_1): WB+WB clean, 0 lost. Mixes, 15 s each, lost pixels in the
  sampled rows: WB+WT 4148 (WB) + 19751 (WT); WB+WC 0 + 376478; WT+WC
  1624 + 0; WB+WC with no clean 8 + 831667. On screen with this content
  (slow ramps) a lost write is a value from a few frames before: nearly
  invisible inside a ramp, small bright specks at its edges (the wrap
  lines). Content with hard edges or still paint would keep a stale
  8-pixel block until the next write there.

### 2026-11-21, T3 (libdz v2 + debazd, dzmem v2 guard=0), .236

Reference = the T3 pattern (rect grid, text, brush, stroke, fade, ellipse
on slot 9) painted by debazd UNCACHED (DZ_DZMEM=0), saved from DDR
(`dzmemtest dump`), repeatable bit for bit. Oracle check: the cached
paint of the same pattern = the reference (2,073,600 pixels); one extra
1-pixel rect is found (x 700, y 700). `t3.sh run 9 30`: 30 rounds of
pattern -> check -> movie on slot 9 for 1 s -> stop -> pattern -> check:
60 checks, 0 mismatches: PASS. Slot 9 went WB -> WC (movie) -> WB 30
times (module counters), no MIXED, debazd log clean (one harmless ffmpeg
"Broken pipe" per movie stop). 1530 s: dzctl waits 400 ms for replies
after each message; the scripts now use `dzctl -t 0` (T3 ~3x faster).

### 2026-11-21, T4 (paint-op timing in debazd, /stats/op), .236

`t4ab.sh -r 3 -n 30`: A = uncached (DZ_DZMEM=0), B = dzmem v2 + libdz v2
(direct WB paint surface on still slot 9), A B A B A B, debazd restarted
in bench mode (no resume) before each run, 1280x720@60, nothing else
running. Median ms of each run (handler time inside debazd):

| Op | Uncached runs | Cached runs | Verdict (diff > 2x spread) |
|---|---|---|---|
| first draw (fresh debazd) | 36.7 37.9 37.2 | 6.8 10.6 12.9 | cached 3-5x faster |
| grab own slot | 82.6 86.5 84.7 | 0.06 0.06 0.06 | cached (no copy) |
| grab another slot | 115 106 109 | 81 78 75 | cached -28 % |
| clear (full slot) | 50.1 45.6 48.0 | 39.9 41.1 40.0 | cached -17 % (borderline) |
| fade 0.1 (full slot) | 55.4 53.7 54.7 | 62.8 63.6 65.2 | UNCACHED better (+17 %: the 16 ms clean) |
| rect 200x150 | 0.47 0.67 0.60 | 1.29 1.08 1.28 | uncached better (+0.6 ms) |
| brush r20 | 0.42 0.42 0.41 | 0.54 0.55 0.54 | uncached better (+0.13 ms) |
| text x4 | 0.42 0.42 0.41 | 0.56 0.55 0.55 | uncached better (+0.13 ms) |
| stroke 8 pts | 34.0 37.0 34.2 | 33.6 32.8 32.8 | equal |
| scroll (transform) | 48.5 46.9 48.8 | 46.7 48.7 47.3 | equal |
| rotozoom (transform) | 63.7 65.5 63.6 | 61.7 63.6 61.9 | equal |
| img/file | - | - | INVALID: the same image twice = no-op (alternate two images) |

RAM in paint buffers: uncached 8.1 MB per painted slot, cached 0 (8.1 MB
after a transform, for 60 s). p95 follows the medians (fade cached 87-94
vs 69-72; grab another 105-112 vs 149-157).

Reading: the gains are latency (first draw), reads of still slots (grab,
and so save / ASCII / slit sources) and RAM. Small ops lose ~0.1-0.6 ms:
each present is a SYNC ioctl (row by row for a rect). Fade loses the
full-slot clean (16 ms). Candidates (measure each): (1) present cleans at
the frame tick instead of per op (one ioctl per frame for all changes,
up to one frame later on screen: autoflush is "soon", not "now"); (2)
fade and clear touch only the window a display shows, or fade-heavy
surfaces use the RAM path (one flag); (3) clean by line only for the
dirty rows (already) and merge adjacent rects.

### 2026-11-21, improvement 1: the clean at the frame tick

present() on a direct surface only records the rectangle (up to 8 per
surface, overlapping ones merged, all merged when full);
`dz_draw_flush_cleans()` in the pixel thread's frame_work cleans them
once per frame (unshadow / takeover clean first). Autoflush = on screen
within one frame. Quick check (one run each, 10 calls, op time in
debazd; the deferred clean is NOT in the op time, it runs at the tick):

| Op | Uncached | Cached, clean per op | Cached, clean per frame |
|---|---|---|---|
| rect | 0.67 | 1.1-1.3 | 0.28 |
| brush | 0.41 | 0.54 | 0.39 |
| text | 0.39 | 0.55 | 0.29 |
| clear (full) | 48 | 40 | 13.5 + ~16 at the tick |
| fade (full) | 55 | 64 | 48 + ~16 at the tick |
| grab another slot | 109 | 78 | 63 |
| first draw | 38 | 7-13 | 11 |
| img/file (alternating 2 PNGs, 6 calls) | 255 | - | 228 |

T3 after the change (5 rounds, a 0.1 s wait before each DDR check for
the tick): 10 checks, 0 mismatches. Small ops now cost less than the
uncached copy; full-slot fade and clear are about even once the tick's
clean is counted (improvement 2: fade / clear only the shown window).

### 2026-11-21, T5 (show-like load, 15 min per mode), .236

`t5.sh 15`: movie on slot 6 (loops), live HDMI_2 capture (laptop
1280x1024, animated window, GNOME idle inhibited) on display 0, paint on
slot 9 on display 1 (rect + brush + text every second, fade every 5 s,
grab of the movie every 10 s, a movie transition on slot 9 every
minute), ASCII 6 -> 8, slit 6 -> 7; serial log on the laptop. Cached =
dzmem v2 (guard 0) + libdz v2 with the clean at the frame tick;
uncached = dzmem UNLOADED, DZ_DZMEM=0. One run each.

| | Cached | Uncached |
|---|---|---|
| hang / oops / taint change | none | none |
| video events (underflow, lock) | 0 | 0 |
| movie fps per minute | mean 19.1, sd 1.6 (16.6-21.1) | mean 20.1, sd 1.7 (17.7-22.3) |
| MB available (debazd paint buffers) | 69-71 | 54-60 |
| rect median / p95 ms | 0.34 / 0.65 | 0.71 / 2.36 |
| brush | 0.67 / 1.37 | 0.73 / 5.27 |
| text | 0.30 / 0.42 | 0.38 / 1.01 |
| fade (full slot) | 94 / 148 | 115 / 176 |
| clear (full slot) | 57 / 108 | 355 / 419 |
| grab of the movie slot | 180 / 256 | 243 / 329 |
| T3 check at the end | PASS | PASS (after a dzmemtest fix: dump and ddr -e no longer need /dev/dzmem) |

Reading: under load the cached path is faster for every paint op and
keeps ~12 MB more RAM free; the movie may lose ~1 fps (the difference is
1.6 standard errors with one run each: not proven; the cleans and the
WB traffic compete with the decoder for DDR). Repeat T5 twice per mode
before deciding on that point.

Hang (Nov 20): NOT reproduced: movie + live capture + paint + ASCII +
slit + transitions for 15 min, with and without dzmem, plus the 30 min
WB + WT mix earlier. What Nov 20 had and today did not: the part 2 code
(dirty WB lines in a LIVE slot written by fbfeed WT on the other core,
ASCII writing through both types: impossible in libdz v2) on a kernel
already tainted by the outer_flush_all oops. Remaining suspects: that
combination, or a capture wedge by chance. If it comes back, the serial
log now has the kernel's last words.
