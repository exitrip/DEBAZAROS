# oscreg + oscdraw - OSC control surface for the PL registers and frame slots.
#
#   make                                        native build (host test: ./oscreg -n)
#   make CROSS_COMPILE=arm-xilinx-linux-gnueabihf-
#   make install TARGET=ebaz@ebaz4205
#
CROSS_COMPILE ?=
CC      ?= $(CROSS_COMPILE)gcc
CFLAGS  ?= -O2 -std=c99 -Wall -Wextra
LDFLAGS ?= -lm

BIN  := oscreg
SRC  := oscreg.c oscdraw.c
HDR  := oscreg.h oscdraw.h
DEST ?= /home/ebaz

all: $(BIN)

$(BIN): $(SRC) $(HDR)
	$(CC) $(CFLAGS) -DOSCREG_MAIN -DOSCREG_WITH_DRAW -o $@ $(SRC) $(LDFLAGS)

install: $(BIN)
ifndef TARGET
	$(error set TARGET=user@host, e.g. make install TARGET=ebaz@ebaz4205)
endif
	scp $(BIN) $(TARGET):$(DEST)/

clean:
	rm -f $(BIN)

.PHONY: all install clean
