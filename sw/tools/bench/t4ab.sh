#!/bin/bash
# t4ab.sh - SLOTMEM.md T4 A/B from the laptop (2026-11-21): R rounds of
# A = uncached (DZ_DZMEM=0), B = cached (dzmem v2), alternating A B A B ...,
# debazd restarted in bench mode before each run (benchmode.sh), then a
# table: per op the median of each run and the spread between runs.
#
#   bash t4ab.sh [-u ebaz@host] [-r rounds] [-n calls] [-o out.txt]
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
BOARD=${DZ_BOARD:-ebaz@10.42.0.236}
R=3; N=30; OUT=t4ab-$(date +%Y%m%d-%H%M).txt
while getopts "u:r:n:o:h" o; do
	case $o in u) BOARD=$OPTARG ;; r) R=$OPTARG ;; n) N=$OPTARG ;; o) OUT=$OPTARG ;;
	*) sed -n '2,8p' "$0"; exit 2 ;; esac
done
O=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR)
sshpass -p '' scp -q "${O[@]}" "$HERE/t4.sh" "$BOARD:/tmp/t4.sh"
DZ_BOARD=$BOARD bash "$HERE/benchmode.sh" record | tee "$OUT"
for r in $(seq 1 "$R"); do
	for mode in uncached cached; do
		echo "== round $r $mode" | tee -a "$OUT"
		DZ_BOARD=$BOARD bash "$HERE/benchmode.sh" start "$mode" | grep "slot memory" | tee -a "$OUT"
		sshpass -p '' ssh "${O[@]}" "$BOARD" "sh /tmp/t4.sh 9 $N" | tee -a "$OUT"
	done
done
echo "== summary (median ms of each run; spread = max - min of the medians of one mode)" | tee -a "$OUT"
awk '
/^== round/ { mode = $4; next }
/^first / { v[mode, "first"] = v[mode, "first"] " " $2; ops["first"] = 1; next }
/^[a-z_]+ op / { v[mode, $1] = v[mode, $1] " " $5; ops[$1] = 1 }
END {
	printf "%-12s %-28s %-28s\n", "op", "uncached runs", "cached runs"
	for (o in ops) printf "%-12s %-28s %-28s\n", o, v["uncached", o], v["cached", o]
}' "$OUT" | tee -a "$OUT"
grep "^mem " "$OUT" | tail -2
echo "t4ab: $OUT"
