# ab2.sh - A/B of debazd paint ops, uncached (DZ_DZMEM=0) against dzmem
# (ROADMAP.md section 19 step 5). Run ON the board as ebaz, dzmem loaded,
# bench-direct.lua in /media/debaz/scripts. Restarts debazd by hand (setsid,
# as dzstart without units). Stops the bench script after each round and
# waits for an autosave: else the resume starts it again at the next start.
start() {	# start debazd with DZ_DZMEM=$1 (0 = uncached)
	P=$(pgrep -x debazd); [ -n "$P" ] && sudo kill $P; for i in 1 2 3 4 5 6; do pgrep -x debazd >/dev/null || break; sleep 0.5; done
	pgrep -x debazd >/dev/null && sudo kill -9 $(pgrep -x debazd)
	sudo sh -c "DZ_DZMEM=$1 setsid nohup /home/ebaz/bin/debazd -v > /tmp/debazd.log 2>&1 < /dev/null &"
	sleep 4
}
clean() {
	for s in 1 2 3 5 6 7 8 9 10; do dzctl /lua/$s/stop >/dev/null; dzctl /movie/$s/stop >/dev/null; dzctl /slit/$s/stop >/dev/null; dzctl /ascii/$s/run -1 >/dev/null; done
	sleep 1
}
for round in 1 2; do
	for mode in 0 1; do
		start $mode; clean
		echo "=== round $round, $( [ $mode = 0 ] && echo UNCACHED || echo DIRECT ): $(grep "slot memory" /tmp/debazd.log | sed "s/debazd: slot memory //")"
		dzctl /lua/10/start bench-direct >/dev/null; sleep 28
		grep -v "^dzlua" /tmp/dzlua.10.log | sed "s/^/  /"
		echo "  $(sudo /home/ebaz/bin/dzmemtest -s 9 ddr | tail -1)"
		dzctl /lua/10/stop >/dev/null; sleep 6
		grep -i "error\|fail\|oops" /tmp/debazd.log | grep -v arecord | head -3
	done
done
