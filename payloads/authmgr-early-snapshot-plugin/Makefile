TOOLCHAIN := $(OO_PS4_TOOLCHAIN)
PROJDIR := $(CURDIR)
BUILDDIR := $(PROJDIR)/build
DISTDIR := $(PROJDIR)/dist
TARGET := authmgr-early-snapshot

CC := clang
LD := ld.lld

CFLAGS := --target=x86_64-pc-freebsd12-elf -fPIC -funwind-tables \
	-fvisibility=hidden -fno-stack-protector -Wall -Wextra -Werror \
	-isysroot $(TOOLCHAIN) -isystem $(TOOLCHAIN)/include
LDFLAGS := -m elf_x86_64 -pie --script $(TOOLCHAIN)/link.x -e _init \
	--eh-frame-hdr -L$(TOOLCHAIN)/lib -lSceLibcInternal -lkernel \
	$(TOOLCHAIN)/lib/crtlib.o

SOURCE := $(PROJDIR)/source/plugin.c
OBJECT := $(BUILDDIR)/plugin.o
ELF := $(DISTDIR)/$(TARGET).elf
OELF := $(DISTDIR)/$(TARGET).oelf
PRX := $(DISTDIR)/$(TARGET).prx

.PHONY: all clean
.DEFAULT_GOAL := all

all: $(PRX)

$(BUILDDIR) $(DISTDIR):
	mkdir -p $@

$(OBJECT): $(SOURCE) | $(BUILDDIR)
	$(CC) $(CFLAGS) -c -o $@ $<

$(ELF): $(OBJECT) | $(DISTDIR)
	$(LD) $(OBJECT) -o $@ $(LDFLAGS)

$(PRX): $(ELF)
	$(TOOLCHAIN)/bin/linux/create-fself -in=$(ELF) -out=$(OELF) \
		--lib=$(PRX) --paid 0x3800000000000011

clean:
	rm -rf $(BUILDDIR) $(DISTDIR)
