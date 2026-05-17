.PHONY: help build release test coverage lint format docs install uninstall clean

help:
	@echo "swift-cmaf-kit — make targets"
	@echo "  build      — swift build (debug)"
	@echo "  release    — swift build -c release"
	@echo "  test       — swift test"
	@echo "  coverage   — swift test --enable-code-coverage + report"
	@echo "  lint       — swiftlint + swift-format lint"
	@echo "  format     — swift-format format --in-place"
	@echo "  docs       — generate merged DocC archive (CMAFKit + CMAFKitCLI)"
	@echo "  install    — install cmafkit-cli to /usr/local/bin"
	@echo "  uninstall  — remove cmafkit-cli from /usr/local/bin"
	@echo "  clean      — remove .build / docs"

build:
	swift build

release:
	swift build -c release

test:
	swift test

coverage:
	swift test --enable-code-coverage

lint:
	swiftlint lint --strict
	swift-format lint --recursive Sources/ Tests/

format:
	swift-format format --in-place --recursive Sources/ Tests/

docs:
	./Scripts/generate-docs.sh

install:
	./Scripts/install.sh

uninstall:
	./Scripts/uninstall.sh

clean:
	rm -rf .build docs
