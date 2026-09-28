# The cell's image. Everything here is inside the blast radius, so treat this file as a budget rather
# than an inventory.

ARG RUBY_VERSION=3.4

# The bundle is built in a stage of its own, because installing it needs a compiler for the native
# extensions, which the image that runs untrusted bytes must not carry.
FROM ruby:${RUBY_VERSION}-slim AS build

RUN apt-get update && \
    apt-get install -y --no-install-recommends build-essential pkg-config && \
    rm -rf /var/lib/apt/lists/*

ENV BUNDLE_PATH=/hotcell/bundle \
    BUNDLE_WITHOUT=development \
    BUNDLE_FROZEN=true

WORKDIR /hotcell
COPY Gemfile Gemfile.lock ./

RUN bundle install && rm -rf "$BUNDLE_PATH"/ruby/*/cache


FROM ruby:${RUBY_VERSION}-slim

# The upgrade applies Debian's pending security patches. `docker build --pull` takes the newest
# `ruby:3.4-slim` tag, but that tag can sit behind an advisory already in `trixie-security` until
# docker-library/ruby rebuilds it, so a clean build can ship a fixable High no rebuild of the cell would
# clear. Upgrading here makes the patch level this image's own rather than upstream's release cadence.
#
# The tools this cell's operations run, and nothing else. No LibreOffice: Fizzy accepts office documents
# and never previews them, so its parsers would be blast radius bought for nothing.
RUN apt-get update && \
    apt-get upgrade -y --no-install-recommends && \
    apt-get install -y --no-install-recommends libvips42 mupdf-tools ffmpeg && \
    rm -rf /var/lib/apt/lists/*

# The cell's user: high and outside any host user range, with no home directory and no shell.
RUN groupadd --gid 10001 hotcell && \
    useradd --uid 10001 --gid 10001 --no-create-home --shell /usr/sbin/nologin hotcell

# The socket volume's mount point must exist here, owned by the cell's user, because a new named volume
# takes its ownership from the directory it covers.
RUN mkdir -p /run/hotcell/cell /hotcell/operations && chown -R hotcell:hotcell /run/hotcell /hotcell

# HOME is /tmp because the cell's user has no home directory, and bundler wants one. A worker replaces
# it with its slot's home before it serves a request.
ENV HOME=/tmp \
    BUNDLE_PATH=/hotcell/bundle \
    BUNDLE_WITHOUT=development \
    BUNDLE_FROZEN=true \
    HOTCELL_OPERATIONS=/hotcell/operations \
    HOTCELL_DIR=/run/hotcell/cell

# OpenMP sizes its thread team from the CPUs the process can SEE, and the accessory's `cpus: 2` is a CFS
# quota rather than an affinity mask — so an unbounded cell asks for one thread per host core, well over
# ninety on a production jobs host. Each thread's 8MB stack is private anonymous memory charged against
# RLIMIT_DATA, and the worker's RLIMIT_DATA is 1536MB: past the line where those stacks clear it,
# pthread_create returns EAGAIN, and libgomp treats a thread it cannot create as fatal — one line on
# stderr and exit(1), with no signal and no Ruby exception to report. That killed 285 workers on the same
# install in bc3 on 2026-08-31 (ref: card 10236548314); beta, whose hosts have 4 cores, saw nothing.
#
# NUM_THREADS matches the cell's CPU quota — the same number activestorage-hotcell-server already
# defaults VIPS_CONCURRENCY to, so the two thread pools agree without a second variable to keep in sync.
# THREAD_LIMIT backstops a library that raises the count itself with omp_set_num_threads.
ENV OMP_NUM_THREADS=2 \
    OMP_THREAD_LIMIT=8

WORKDIR /hotcell

COPY --from=build --chown=hotcell:hotcell /hotcell/bundle /hotcell/bundle
COPY --chown=hotcell:hotcell Gemfile Gemfile.lock ./
COPY --chown=hotcell:hotcell config.rb /hotcell/config.rb
COPY --chown=hotcell:hotcell operations/ /hotcell/operations/

# Nothing here needs to raise privilege, so nothing here should be able to. `no-new-privileges` on the
# accessory already neutralizes a setuid binary at runtime; this removes the bits from the image itself,
# so the two are independent and an image scan has nothing to report.
RUN find / -xdev -type f -perm /06000 -exec chmod a-s {} +

USER hotcell

# Probes the supervisor's control socket from inside the container, where network: none does not apply.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD ["bundle", "exec", "hotcell-health"]

CMD ["bundle", "exec", "hotcell"]
