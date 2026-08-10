SHELL := /bin/bash

SH_FILES  := $(wildcard install.sh uninstall.sh tests/docker/run.sh tests/integration/*.sh)
ZSH_FILES := $(wildcard .zshrc *.zsh)

.PHONY: lint unit integration test docker-build docker-test

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
