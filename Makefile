SHELL := /bin/bash

SH_FILES  := $(wildcard install.sh uninstall.sh bin/ftazsh bin/ftazsh-pager tests/docker/run.sh tests/integration/*.sh tests/macos/*.sh)
ZSH_FILES := $(wildcard .zshrc *.zsh tests/lib/*.zsh)

.PHONY: lint unit integration test docker-build docker-test mac-test

lint:
	shellcheck $(SH_FILES)
	@set -e; for f in $(ZSH_FILES); do zsh -n "$$f"; echo "zsh -n OK: $$f"; done

unit:
	bats tests/unit

integration:
	bash tests/integration/zsh_boot.sh

test: lint unit integration

docker-build:
	docker build -f tests/docker/Dockerfile -t ftazsh-test .

docker-test: docker-build
	docker run --rm ftazsh-test

# Run this on your Mac: a real end-to-end install in a throwaway HOME, with
# cleanup. See tests/macos/smoke.sh --help.
mac-test:
	bash tests/macos/smoke.sh $(MAC_TEST_ARGS)
