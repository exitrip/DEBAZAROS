# DEPRECATED - do not build or deploy oscreg.
# Its address table uses blocks that are no longer in the bitstream
# (0x4122_0000, 0x4124_0000, 0x43D1_0000, 0x44D1_0000): any access is a bus
# error (SIGBUS). Its colour lanes for G/B were also swapped.
# Replaced by sw/debazd (daemon) + sw/lib (dz_fields, dz_draw). See sw/README.md.
all install:
	@echo "oscreg is deprecated: use 'make -C ..' (debazd + dzctl), see sw/README.md"; exit 1
.PHONY: all install
