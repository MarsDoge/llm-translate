APP := LLMTranslateLinux
BUILD_DIR := build
SRC := src/main.c

PKG_CONFIG ?= pkg-config
CC ?= cc
CFLAGS ?= -O2 -Wall -Wextra
GTK_CFLAGS = $(shell $(PKG_CONFIG) --cflags gtk+-3.0)
GTK_LIBS = $(shell $(PKG_CONFIG) --libs gtk+-3.0)

.PHONY: all clean run check-deps

all: $(BUILD_DIR)/$(APP)

check-deps:
	@$(PKG_CONFIG) --exists gtk+-3.0 || { \
		echo "gtk+-3.0 development files are required."; \
		echo "Debian/Ubuntu: sudo apt install build-essential pkg-config libgtk-3-dev"; \
		exit 1; \
	}

$(BUILD_DIR)/$(APP): $(SRC) | check-deps
	mkdir -p $(BUILD_DIR)
	$(CC) $(CFLAGS) $(GTK_CFLAGS) -o $@ $< $(GTK_LIBS)

run: $(BUILD_DIR)/$(APP)
	./$(BUILD_DIR)/$(APP)

clean:
	rm -rf $(BUILD_DIR)
