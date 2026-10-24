# common.mk - shared build settings for everything under sw/.
#
# Default: cross-compile for the EBAZ4205 (Zynq-7010, PetaLinux 2022.2,
# glibc 2.34) with the toolchain that ships with Vitis 2022.2. No Vitis
# project or BSP is involved; only its gcc.
#
#   make                 cross build (ARM)
#   make NATIVE=1        host build (x86), for tests that do not touch hardware
#   make install         copy binaries to the board ($(TARGET):$(DEST))
#   make DEBUG=1         -O0 -g, for gdbserver sessions
#
# Override on the command line or in the environment, e.g.
#   make TOOLCHAIN=/opt/xilinx/.../bin TARGET=ebaz@192.168.1.20

TOOLCHAIN ?= /home/aescape/Xilinx/Vitis/2022.2/gnu/aarch32/lin/gcc-arm-linux-gnueabi/bin

ifeq ($(NATIVE),1)
CROSS_COMPILE ?=
else
CROSS_COMPILE ?= $(TOOLCHAIN)/arm-linux-gnueabihf-
endif

# make predefines CC=cc and AR=ar, so "CC ?=" would never take effect and a
# "cross" build silently produced x86 binaries. Only replace the defaults.
ifeq ($(origin CC),default)
CC := $(CROSS_COMPILE)gcc
endif
ifeq ($(origin AR),default)
AR := $(CROSS_COMPILE)ar
endif

ifeq ($(DEBUG),1)
OPT := -O0
else
OPT := -O2
endif

SWDIR   := $(dir $(lastword $(MAKEFILE_LIST)))
# The toolchain defaults to ARMv5; the board is a Cortex-A9 with NEON, hard float.
ifneq ($(NATIVE),1)
ARCHFLAGS ?= -mcpu=cortex-a9 -mfpu=neon -mfloat-abi=hard
endif
CFLAGS  ?= $(OPT) -g -std=gnu99 -Wall -Wextra -Wno-unused-parameter $(ARCHFLAGS)
CFLAGS  += -I$(SWDIR)include -I$(SWDIR)lib
LDLIBS  ?=

# Board access. The board has an empty password for user ebaz (bench setup).
TARGET  ?= ebaz@[fe80::20a:35ff:fe00:1e53%enp0s31f6]
DEST    ?= /home/ebaz/bin
SSHPASS ?= sshpass -p ''
SCP     ?= $(SSHPASS) scp -o StrictHostKeyChecking=no
SSH     ?= $(SSHPASS) ssh -o StrictHostKeyChecking=no
# ssh takes the host without the [] that scp needs for IPv6
SSH_HOST = $(subst ],,$(subst [,,$(TARGET)))
