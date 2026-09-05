BUILD_DIR := build
APPS := $(basename $(notdir $(wildcard src/*.mm)))
APP ?= draw_black

.PHONY: build rebuild run $(APPS)

build:
	cmake -S . -B $(BUILD_DIR)
	cmake --build $(BUILD_DIR)

rebuild:
	cmake -E rm -rf $(BUILD_DIR)
	$(MAKE) --no-print-directory build

# Build one example by its source filename without the .mm extension.
$(APPS):
	cmake -S . -B $(BUILD_DIR)
	cmake --build $(BUILD_DIR) --target $@

run: $(APP)
	./$(BUILD_DIR)/$(APP)
