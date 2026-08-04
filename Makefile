.PHONY: build format lint release test

build:
	swift build

test:
	swift test

format:
	swift format --in-place --recursive Package.swift Sources Tests

lint:
	swift format lint --strict --recursive Package.swift Sources Tests

release:
	./scripts/build-universal.sh
