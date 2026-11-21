obj-m := dzmem.o
# the user interface header lives in the repo's sw/include (recipe: file://sw/include/dzmem.h)
ccflags-y := -I$(src)/sw/include

SRC := $(shell pwd)

all:
	$(MAKE) -C $(KERNEL_SRC) M=$(SRC)

modules_install:
	$(MAKE) -C $(KERNEL_SRC) M=$(SRC) modules_install

clean:
	rm -f *.o *~ core .depend .*.cmd *.ko *.mod.c *.mod
	rm -f Module.markers Module.symvers modules.order
