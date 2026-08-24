# fbfeed - see fbfeed.c for what it does.
#
#   make                                        native build (x86 host, test only)
#   make CROSS_COMPILE=arm-xilinx-linux-gnueabihf-
#   . <petalinux-sdk>/environment-setup-... && make CC="$CC"
#
CROSS_COMPILE ?=
CC      ?= $(CROSS_COMPILE)gcc
CFLAGS  ?= -O2 -std=c99 -Wall -Wextra -Wno-unused-result
LDFLAGS ?=

BIN  := fbfeed
SRC  := fbfeed.c
DEST ?= /home/ebaz

all: $(BIN)

$(BIN): $(SRC)
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

# Copy to the target.  TARGET=user@host
install: $(BIN)
ifndef TARGET
	$(error set TARGET=user@host, e.g. make install TARGET=ebaz@ebaz4205)
endif
	scp $(BIN) $(TARGET):$(DEST)/

clean:
	rm -f $(BIN)

.PHONY: all install clean
