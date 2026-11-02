#!/bin/sh
# remote_build.sh - run hw/build.tcl on the PetaLinux build machine (2026-11-02),
# for a second build at the same time as a local one (other sources, or other
# directives: at 100 % slices the placer result is partly luck).
#
#   sh hw/remote_build.sh start <out> [<srcdir>] [VAR=value ...]
#        copy hw/ ip_repo/ IP_* of <srcdir> (default: this repo) to
#        $HOST:$RDIR and start the build there in the background;
#        VAR=value = build.tcl settings (DZ_PLACE_DIRECTIVE=..., DZ_JOBS=...)
#   sh hw/remote_build.sh status <out>   the PID (if running) + last log lines
#   sh hw/remote_build.sh fetch <out>    copy the results (.bit .bit.bin .xsa
#        hw_map.h, reports) to build/<out>/ here
#   sh hw/remote_build.sh stop <out>     kill that build by its PID
#
# The remote tree is a copy, not a git clone: the build machine's own repo
# clone (PetaLinux) is not touched. Each start overwrites the copy, so run
# one remote build at a time. Its IP cache is ~/dz-ipcache there.
set -e
HOST=${DZ_BUILD_HOST:-aescape@192.168.1.239}
RDIR=${DZ_BUILD_DIR:-dz-hwbuild}
VARIANT=${DZ_VARIANT:-ebaz4205_2out1in}
SSH="ssh -o IdentitiesOnly=yes -i $HOME/.ssh/id_ed25519"
REPO=$(cd "$(dirname "$0")/.." && pwd)

cmd=$1; out=$2
[ -n "$cmd" ] && [ -n "$out" ] || { sed -n '2,20p' "$0"; exit 1; }
shift 2

case $cmd in
start)
	src=$REPO
	if [ -n "$1" ] && [ -d "$1" ]; then src=$(cd "$1" && pwd); shift; fi
	envs=""
	for kv in "$@"; do
		case $kv in DZ_*=*) envs="$envs $kv" ;; *) echo "not a DZ_ setting: $kv"; exit 1 ;; esac
	done
	$SSH $HOST "pgrep -f '[u]nwrapped.*build.tcl' > /dev/null" &&
		{ echo "a build runs on $HOST already: sh hw/remote_build.sh status <out>"; exit 1; }
	$SSH $HOST "mkdir -p $RDIR/build"
	rsync -a --delete -e "$SSH" "$src/hw" "$src/ip_repo" "$src/IP_dvi2rgb" "$src/IP_rgb2dvi" \
		"$src/IP_axi_dynclk" "$HOST:$RDIR/"
	# -n + every descriptor of the build away from the session: else ssh
	# waits for the build to end
	$SSH -n $HOST "cd $RDIR && (env $envs setsid nohup \$HOME/Xilinx/Vivado/2022.2/bin/vivado -mode batch \
		-nojournal -source hw/build.tcl -tclargs $VARIANT build $out > build/${out}_build.log 2>&1 < /dev/null &) \
		> /dev/null 2>&1 < /dev/null"
	sleep 5
	$SSH -n $HOST "cd $RDIR && pgrep -f '[u]nwrapped.*build $out' | head -1 > build/${out}.pid; echo PID \$(cat build/${out}.pid)"
	echo "log: $HOST:$RDIR/build/${out}_build.log"
	echo "watch: sh hw/remote_build.sh status $out   stop: sh hw/remote_build.sh stop $out"
	;;
status)
	$SSH $HOST "cd $RDIR/build; p=\$(cat ${out}.pid 2>/dev/null); \
		if [ -n \"\$p\" ] && kill -0 \$p 2>/dev/null; then echo running PID \$p; else echo not running; fi; \
		grep -E '^ERROR|impl_1 finished|write_bitstream|Placer could not' ${out}_build.log | grep -v send_gid | tail -4; \
		tail -2 ${out}_build.log"
	;;
fetch)
	mkdir -p "$REPO/build/$out"
	rsync -a -e "$SSH" --include='*.bit' --include='*.bit.bin' --include='*.xsa' --include='hw_map.h' \
		--include='*.rpt' --exclude='*/' --exclude='*' "$HOST:$RDIR/build/$out/" "$REPO/build/$out/"
	rsync -a -e "$SSH" "$HOST:$RDIR/build/${out}_build.log" "$REPO/build/" || true
	ls -la "$REPO/build/$out"
	;;
stop)
	$SSH $HOST "p=\$(cat $RDIR/build/${out}.pid); kill \$p && echo stopped \$p"
	;;
*)
	sed -n '2,20p' "$0"; exit 1 ;;
esac
