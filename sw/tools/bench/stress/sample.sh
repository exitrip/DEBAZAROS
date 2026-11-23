#!/bin/sh
# sample.sh - one line of board health for stress.sh (2026-11-22). Runs on
# the board: key=value pairs, "-" when a thing is not there.
D=$(pidof debazd) A=$(pidof dzaudio)
rss() { [ -n "$1" ] && awk '/VmRSS/ {print $2}' /proc/$1/status 2>/dev/null || echo -; }
tck() { [ -n "$1" ] && awk '{print $14 + $15}' /proc/$1/stat 2>/dev/null || echo -; }
# /stats: debazd_cpu cpu_total tick_hz tick_max osc_max load mem temp pix_max pix_queue
st=$(dzctl -t 800 /stats 2>/dev/null | awk '{print $2 "," $3 "," $5 "," $6 "," $10 "," $11}')
ev=$(journalctl -u debazd --since -32s -o cat 2>/dev/null | grep -c "VIDEO ")
err=$(journalctl -u debazd --since -32s -o cat 2>/dev/null | grep -v "Broken pipe" | grep -ciE "error|fail|refused|busy|wedge")
mix=-; [ -n "$A" ] && mix=$(dzctl -p 9002 -t 800 /mix/status 2>/dev/null | grep -o "xruns [0-9]*" | awk '{s += $2} END {print s + 0}')
str=-; [ -n "$A" ] && str=$(dzctl -p 9002 -t 800 /mix/streams 2>/dev/null | cut -d'"' -f2 | tr ' ' ';')
# CPU from /proc (the /stats CPU covers the time since ANY client's last
# /stats: a web page polling it makes the window a few ticks long)
cpu=$(awk '/^cpu / {print $2 + $3 + $4 + $7 + $8 "," $2 + $3 + $4 + $5 + $6 + $7 + $8 + $9}' /proc/stat)
echo "t=$(date +%s) cpu_busy_all=$cpu up=$(cut -d. -f1 /proc/uptime) avail_kb=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)" \
     "dzd_pid=${D:--} dzd_rss=$(rss "$D") dzd_ticks=$(tck "$D") aud_rss=$(rss "$A") aud_ticks=$(tck "$A")" \
     "load=$(cut -d' ' -f1 /proc/loadavg) stats=${st:--} video_ev=$ev log_err=$err" \
     "xruns=$mix streams=${str:--} ffmpeg=$(pidof ffmpeg | wc -w) dzlua=$(pidof dzlua | wc -w)" \
     "restarts=$(systemctl show debazd -p NRestarts --value 2>/dev/null) active=$(systemctl is-active debazd)" \
     "taint=$(cat /proc/sys/kernel/tainted) dmesg=$(dmesg 2>/dev/null | wc -l)" \
     "cap=$(dzctl -t 500 /capture/status 2>/dev/null | cut -d' ' -f2-4 | tr ' ' ,)"
