# The cell's image. HotCell installed this file once; it is yours to customize, and nothing inherits
# from a published base image — this is the whole recipe.
#
# A cell carries a Ruby runtime and every gem in its loaded graph, all inside the blast radius, so treat
# this file as a budget rather than an inventory. Which tools it holds is what decides its blast radius.

ARG RUBY_VERSION=3.4

# The bundle is built in a stage of its own, because installing it needs things the cell must not carry:
# git, for the private git source the gems come from, and a compiler for the native extensions. Neither
# reaches the image that runs untrusted bytes, and neither does the credential.
FROM ruby:${RUBY_VERSION}-slim AS build

RUN apt-get update && \
    apt-get install -y --no-install-recommends build-essential git pkg-config && \
    rm -rf /var/lib/apt/lists/*

ENV BUNDLE_PATH=/hotcell/bundle \
    BUNDLE_WITHOUT=development \
    BUNDLE_FROZEN=true

WORKDIR /hotcell
COPY Gemfile Gemfile.lock ./

# Bundler rewrites each git remote to carry the token, so the checkouts and the bare mirror it clones them
# from would otherwise keep a credential — and this stage is copied from, so a file deleted in a later
# layer would still be there to read.
#
# The mirror is under $BUNDLE_PATH/ruby/<abi>/cache/bundler/git, not $BUNDLE_PATH/cache. Removing the
# latter removes nothing and leaves `url = https://<token>@github.com/...` in the image. saas/hotcell/bin/build
# scans the result for the token rather than trusting this line.
RUN --mount=type=secret,id=GITHUB_TOKEN \
    BUNDLE_GITHUB__COM="$(cat /run/secrets/GITHUB_TOKEN):x-oauth-basic" bundle install && \
    rm -rf "$BUNDLE_PATH"/ruby/*/bundler/gems/*/.git "$BUNDLE_PATH"/ruby/*/cache


FROM ruby:${RUBY_VERSION}-slim

# The tools this cell's operations run, and nothing else. No LibreOffice: Fizzy accepts office documents
# and never previews them, so its parsers would be blast radius bought for nothing.
RUN apt-get update && \
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

WORKDIR /hotcell

COPY --from=build --chown=hotcell:hotcell /hotcell/bundle /hotcell/bundle
COPY --chown=hotcell:hotcell Gemfile Gemfile.lock ./
COPY --chown=hotcell:hotcell config.rb /hotcell/config.rb
COPY --chown=hotcell:hotcell operations/ /hotcell/operations/

USER hotcell

# Probes the supervisor's control socket from inside the container, where network: none does not apply.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD ["bundle", "exec", "hotcell-health"]

CMD ["bundle", "exec", "hotcell"]
