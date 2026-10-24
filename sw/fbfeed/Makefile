# fbfeed is built by the sw/ top-level Makefile (out/arm/fbfeed).
# The old standalone Makefile here built an x86 binary even with
# CROSS_COMPILE set (make predefines CC). Kept as a forwarder.
all:
	$(MAKE) -C .. out/arm/fbfeed
install:
	$(MAKE) -C .. install
.PHONY: all install
