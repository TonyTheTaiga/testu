.PHONY: rebuild

build:
	cmake -S . -B build

.PHONY: build

rebuild: 
	cmake -E rm -rf build
	cmake -S . -B build
	cmake --build build
