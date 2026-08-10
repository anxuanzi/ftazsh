# Linux test image for ftazsh: runs lint, unit and integration tests.
# Deliberately includes fzf/zoxide/eza but NOT bat/fd, so the config's
# graceful-degradation guards are exercised (and old apt fzf lacks --zsh).
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
        zsh git curl ca-certificates locales make shellcheck bats \
        fzf zoxide eza zip unzip \
    && rm -rf /var/lib/apt/lists/* \
    && locale-gen en_US.UTF-8

ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

RUN useradd -m -s /bin/zsh tester
USER tester
WORKDIR /home/tester/ftazsh
COPY --chown=tester:tester . .

CMD ["bash", "tests/docker/run.sh"]
