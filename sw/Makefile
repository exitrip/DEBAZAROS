# sw/Makefile - build all DEBAZAROS userspace tools. No Vitis needed.
#
#   make                cross build -> out/arm/
#   make NATIVE=1       host build  -> out/native/   (dzctl for the laptop, tests)
#   make install        copy out/arm/* + scripts to the board ($(TARGET):$(DEST))
#   make image-install DESTDIR=dir   the image layout under dir (PetaLinux
#                       recipe debaz-sw): /usr/bin, /usr/share/debaz/www,
#                       /etc/debaz, the systemd unit, the udev rules (ebaz
#                       may use I2C, SPI, GPIO, IIO, UIO, NAND)
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
WWW     ?= /home/ebaz/www

LIBSRC  := $(wildcard lib/*.c)
LIBOBJ  := $(LIBSRC:%.c=$(OBJ)/%.o)
HDRS    := $(wildcard lib/*.h include/*.h debazd/*.h)
BINS    := $(OUT)/debazd $(OUT)/dzctl $(OUT)/fbfeed $(OUT)/dzmosh $(OUT)/vsync_probe $(OUT)/dzweb $(OUT)/pcmplay $(OUT)/dzbus
SCRIPTS := tools/capstat.sh tools/plreload.sh tools/dzstart.sh tools/dzsetup.sh tools/keytest.sh tools/ddrprio.sh tools/lrtest.sh tools/evwatch.sh tools/avplay.sh tools/avswitch.sh tools/debaz-mac.sh tools/debaz-firstboot.sh
# the image: debaz-mac.sh + debaz-firstboot.sh come from recipe debaz-firstboot (/usr/sbin)
IMG_SCRIPTS := $(filter-out tools/debaz-mac.sh tools/debaz-firstboot.sh,$(SCRIPTS))

all: $(BINS) hdmi2

hdmi2:
	$(MAKE) -C hdmi2 NATIVE=$(NATIVE)

$(OBJ)/%.o: %.c $(HDRS)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c -o $@ $<

$(OUT)/libdz.a: $(LIBOBJ)
	$(AR) rcs $@ $^

DZDOBJ  := $(patsubst %.c,$(OBJ)/%.o,$(wildcard debazd/*.c))

$(OUT)/debazd: $(DZDOBJ) $(OUT)/libdz.a
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS) -lm -lpthread -ldl $(LDLIBS)

$(OUT)/dzctl: $(OBJ)/dzctl/dzctl.o $(OUT)/libdz.a
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS) -lm -lpthread -ldl $(LDLIBS)

$(OUT)/dzweb: $(OBJ)/dzweb/dzweb.o $(OUT)/libdz.a
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS) -lpthread -ldl $(LDLIBS)

$(OUT)/vsync_probe: $(OBJ)/tools/vsync_probe.o $(OUT)/libdz.a
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS) -lpthread -ldl $(LDLIBS)

$(OUT)/pcmplay: $(OBJ)/tools/pcmplay.o $(OUT)/libdz.a
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS) -lm -lpthread -ldl $(LDLIBS)

$(OUT)/dzbus: $(OBJ)/tools/dzbus.o
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

$(OUT)/dzmosh: $(OBJ)/dzmosh/dzmosh.o
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS) -lm

$(OUT)/fbfeed: $(OBJ)/fbfeed/fbfeed.o $(OUT)/libdz.a
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS) -lpthread -ldl $(LDLIBS)

# Copy, then move: overwriting a running binary in place fails (ETXTBSY).
install: all
	$(MAKE) -C hdmi2 install
	$(SSH) $(SSH_HOST) 'rm -rf /tmp/dz-install && mkdir -p /tmp/dz-install $(DEST)'
	$(SCP) $(BINS) $(SCRIPTS) $(TARGET):/tmp/dz-install/
	$(SSH) $(SSH_HOST) 'mv -f /tmp/dz-install/* $(DEST)/ && rmdir /tmp/dz-install'
	$(SSH) $(SSH_HOST) 'mkdir -p $(WWW)'
	$(SCP) dzweb/www/* $(TARGET):$(WWW)/

# the image layout (no ssh): the recipe runs it with DESTDIR=${D}
image-install: all
	install -d $(DESTDIR)/usr/bin $(DESTDIR)/usr/share/debaz/www $(DESTDIR)/etc/debaz \
		$(DESTDIR)/lib/systemd/system $(DESTDIR)/etc/udev/rules.d
	install -m 0755 $(BINS) $(OUT)/hdmi2.elf $(DESTDIR)/usr/bin/
	install -m 0755 $(IMG_SCRIPTS) $(DESTDIR)/usr/bin/
	install -m 0644 dzweb/www/* $(DESTDIR)/usr/share/debaz/www/
	install -m 0644 tools/image/dzstart.conf $(DESTDIR)/etc/debaz/
	install -m 0644 tools/image/debaz.service $(DESTDIR)/lib/systemd/system/
	install -m 0644 tools/image/99-debaz-hw.rules $(DESTDIR)/etc/udev/rules.d/

test:
	$(MAKE) NATIVE=1 $(BINS:out/arm/%=out/native/%)
	sh tools/selftest.sh out/native

hwmap:
	cp ../build/$(VARIANT)/hw_map.h include/hw_map.h

clean:
	rm -rf out

.PHONY: all hdmi2 install image-install test hwmap clean
