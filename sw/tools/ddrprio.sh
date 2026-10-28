#!/bin/sh
# ddrprio.sh on|off|show - DDR controller read-port priority for the display
# VDMAs (2026-10-28). axi_priority_rd_portN @ 0xF8006218 + 4N, [9:0] priority,
# LOWER = served first (UG585; re-programmable at run time). Ports: 0 = CPUs,
# 1 = other masters, 2 = HP2/HP3 (HDMI_1 display), 3 = HP0/HP1 (HDMI_0
# display + capture). Boot value: 0x3FF on all ports. Run as root.
D=/sbin/devmem
case "$1" in
on)  $D 0xF8006220 32 0x00000004; $D 0xF8006224 32 0x00000004 ;;
off) $D 0xF8006220 32 0x000003FF; $D 0xF8006224 32 0x000003FF ;;
esac
for p in 0 1 2 3; do printf "rd port %d: %s\n" $p $($D $((0xF8006218 + 4 * p)) 32); done
