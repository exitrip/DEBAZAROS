# sw/Makefile - build all DEBAZAROS userspace tools. No Vitis needed.
#
#   make                cross build -> out/arm/
#   make NATIVE=1       host build  -> out/native/   (dzctl for the laptop, tests)
#   make install        copy out/arm/* + scripts to the board ($(TARGET):$(DEST))
#   make test           host self test (simulated hardware)
#   make hwmap          refresh include/hw_map.h from build/$(VARIANT)/
#   make DEBUG=1        -O0 -g (gdbserver sessions)
#
# See common.mk for TOOLCHAIN, TARGET, DEST.

include common.mk

ARCH    := $(if $(filter 1,$(NATIVE)),native,arm)
OUT     := out/$(ARCH)
OBJ     := $(OUT)/obj
VARIANT ?= ebaz4205_2out1in

LIBSRC  := $(wildcard lib/*.c)
LIBOBJ  := $(LIBSRC:%.c=$(OBJ)/%.o)
HDRS    := $(wildcard lib/*.h include/*.h)
BINS    := $(OUT)/debazd $(OUT)/dzctl $(OUT)/fbfeed $(OUT)/vsync_probe
SCRIPTS := tools/capstat.sh

all: $(BINS) hdmi2

hdmi2:
	$(MAKE) -C hdmi2 NATIVE=$(NATIVE)

$(OBJ)/%.o: %.c $(HDRS)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c -o $@ $<

$(OUT)/libdz.a: $(LIBOBJ)
	$(AR) rcs $@ $^

DZDOBJ  := $(patsubst %.c,$(OBJ)/%.o,$(wildcard debazd/*.c))
HDRS    += $(wildcard debazd/*.h)

$(OUT)/debazd: $(DZDOBJ) $(OUT)/libdz.a
	$(CC) $(CFLAGS) -o $@ $^ -lm -lpthread $(LDLIBS)

$(OUT)/dzctl: $(OBJ)/dzctl/dzctl.o $(OUT)/libdz.a
	$(CC) $(CFLAGS) -o $@ $^ -lm $(LDLIBS)

$(OUT)/vsync_probe: $(OBJ)/tools/vsync_probe.o $(OUT)/libdz.a
	$(CC) $(CFLAGS) -o $@ $^ $(LDLIBS)

$(OUT)/fbfeed: $(OBJ)/fbfeed/fbfeed.o $(OUT)/libdz.a
	$(CC) $(CFLAGS) -o $@ $^ $(LDLIBS)

# Copy, then move: overwriting a running binary in place fails (ETXTBSY).
install: all
	$(MAKE) -C hdmi2 install
	$(SSH) $(SSH_HOST) 'rm -rf /tmp/dz-install && mkdir -p /tmp/dz-install $(DEST)'
	$(SCP) $(BINS) $(SCRIPTS) $(TARGET):/tmp/dz-install/
	$(SSH) $(SSH_HOST) 'mv -f /tmp/dz-install/* $(DEST)/ && rmdir /tmp/dz-install'

test:
	$(MAKE) NATIVE=1 $(BINS:out/arm/%=out/native/%)
	sh tools/selftest.sh out/native

hwmap:
	cp ../build/$(VARIANT)/hw_map.h include/hw_map.h

clean:
	rm -rf out

.PHONY: all hdmi2 install test hwmap clean
