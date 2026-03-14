.PHONY: build test clean distclean

build:
	zig build

test:
	zig build test

clean:
	rm -rf zig-out .zig-cache

distclean: clean
	rm -rf vendor/ghostty
