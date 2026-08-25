# GSubprocess-stdin reference experiment build.

CC      ?= cc
CFLAGS   = -Wall -Wextra -O2
PKG      = gio-2.0

TARGET   = gprocess_stdin

.PHONY: all run clean

all: $(TARGET)

$(TARGET): gprocess_stdin.c
	$(CC) $(CFLAGS) $(shell pkg-config --cflags $(PKG)) \
	    gprocess_stdin.c -o $(TARGET) $(shell pkg-config --libs $(PKG))

# On MSYS2/Windows set PKG_CONFIG_PATH so gio-2.0 from the clang64 environment
# is found, and MSYS2's `pkg-config` shell wrapper is used.
run: $(TARGET)
	./$(TARGET)
	@echo '[make] done'

clean:
	rm -f $(TARGET)
