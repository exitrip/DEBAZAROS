# hdmi2 - display bring-up (video mode, VDMAs, VTC, dynclk, capture).
# Plain make replacement for the Vitis "hdmi2" Linux application project.
#
#   make                cross build -> ../out/arm/hdmi2.elf
#   make DEBUG=0        optimised build (default is -O0 -g3, as in Vitis)
#   make install        copy to the board (../common.mk TARGET/DEST)
#
# Same sources and flags as the Vitis Debug build (jerkspace/hdmi2/Debug):
# src/clk_wiz_v1_5 and src/selftest are not built there either.
# The Xilinx baremetal drivers here are a modified copy that runs on Linux
# through /dev/mem (src/IP_Driver.c); see CLAUDE.md before you change them.

DEBUG ?= 1
include ../common.mk

ARCH   := $(if $(filter 1,$(NATIVE)),native,arm)
OUT    := ../out/$(ARCH)
OBJ    := $(OUT)/obj/hdmi2

SRCDIRS := src src/axivdma_v6_10/src src/colorbars src/display_ctrl src/dynclk \
	   src/inc src/mixer_v1_0/src src/scutimer_v2_3/src src/timer_ps \
	   src/vtc_v8_4/src
SRC    := $(foreach d,$(SRCDIRS),$(wildcard $(d)/*.c))
OBJS   := $(SRC:%.c=$(OBJ)/%.o)

# Vitis flags were: -Wall -O0 -g3 -I src/inc. Keep the warnings quiet that
# the vendor driver code triggers by design; our own code builds with -Wextra.
HFLAGS := $(OPT) -g3 -Wall -Isrc/inc -Wno-unused-variable -Wno-unused-but-set-variable \
	  -Wno-unused-function -Wno-pointer-to-int-cast -Wno-int-to-pointer-cast

all: $(OUT)/hdmi2.elf

$(OBJ)/%.o: %.c
	@mkdir -p $(dir $@)
	$(CC) $(HFLAGS) -MMD -MP -c -o $@ $<

$(OUT)/hdmi2.elf: $(OBJS)
	$(CC) -o $@ $^ -lm

-include $(OBJS:.o=.d)

install: all
	$(SSH) $(SSH_HOST) 'mkdir -p /tmp/dz-install $(DEST)'
	$(SCP) $(OUT)/hdmi2.elf $(TARGET):/tmp/dz-install/
	$(SSH) $(SSH_HOST) 'mv -f /tmp/dz-install/hdmi2.elf $(DEST)/ && rmdir /tmp/dz-install'

clean:
	rm -rf $(OBJ) $(OUT)/hdmi2.elf

.PHONY: all install clean
