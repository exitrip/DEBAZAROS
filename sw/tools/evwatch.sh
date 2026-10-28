#!/bin/sh
# evwatch.sh [secs] - log falling edges of the user I/O lines (buttons,
# event bits 7:2 = lines 0-5) from the event block, with timestamps. Root.
D=/sbin/devmem
$D 0x43C61014 32 0xFC; $D 0x43C61010 32 0; $D 0x43C61008 32 0x1FF
end=$(( $(date +%s) + ${1:-60} ))
while [ $(date +%s) -lt $end ]; do
  p=$(( $($D 0x43C61008 32) ))
  if [ $((p & 0xFC)) -ne 0 ]; then
    echo "$(date +%T) lines=$(( (p >> 2) & 63 )) ts=$($D 0x43C61028 32) level=$($D 0x43C61018 32)"
    $D 0x43C61008 32 $p
  fi
  usleep 20000
done
$D 0x43C61014 32 0
echo END
