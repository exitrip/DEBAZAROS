#!/bin/bash
# usage: bash sw/tools/dryrun-start.sh <repo>/sw   (needs: make -C sw NATIVE=1)
# dry run of debaz-start.sh against a simulated debazd (host only)
SW=$1; T=$(mktemp -d)
cp $SW/out/native/dzctl $T/
printf '#!/bin/sh\necho "devmem $*" >> %s/calls\n' $T > $T/devmem
printf '#!/bin/sh\nsleep 0.1\n' > $T/hdmi2.elf
printf '#!/bin/sh\necho "ffmpeg $*" >> %s/calls\n' $T > $T/ffmpeg
chmod +x $T/*
$SW/out/native/debazd -n -p 9000 2>$T/dlog & DP=$!
sleep 0.3
# hdmi2 does not run in simulation, so /disp/0 stays -1: the wait loop times out (10 s)
PATH=$T:$PATH BIN=$T LOAD_PL=0 LOOP=0 timeout 60 bash $SW/tools/debaz-start.sh; echo "script rc=$?"
cut -c1-100 $T/calls
for f in /mixer/1/mode /mixer/1/k /mixer/1/hi /mixer/1/lo /mixer/0/mode /mixer/0/k /mixer/7/k /dds/0/pinc /dds/0/enable /dds/1/pinc /hdmi/1/osc/phase/offset /hdmi/1/osc/phase/div /mixer/8/gain/1 /mixer/3/gain/0; do $T/dzctl $f; done
kill $DP; rm -rf $T
