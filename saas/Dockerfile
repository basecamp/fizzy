# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=3.4.7
FROM registry.docker.com/library/ruby:$RUBY_VERSION-slim AS base

# Rails app lives here
WORKDIR /rails

# Set production environment
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    SAAS="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_GEMFILE="Gemfile.saas" \
    BUNDLE_WITHOUT="development"


# Throw-away build stage to reduce size of final image
FROM base AS build

# Install packages needed to build gems
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends -y build-essential pkg-config git libvips libyaml-dev libssl-dev && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install application gems
COPY Gemfile Gemfile.lock Gemfile.saas Gemfile.saas.lock .ruby-version ./
COPY lib/fizzy.rb ./lib/fizzy.rb
COPY saas/fizzy-saas.gemspec ./saas/
COPY saas/lib/fizzy/saas/version.rb ./saas/lib/fizzy/saas/
RUN --mount=type=secret,id=GITHUB_TOKEN --mount=type=cache,id=fizzy-permabundle-${RUBY_VERSION},sharing=locked,target=/permabundle \
    gem install bundler && \
    BUNDLE_PATH=/permabundle BUNDLE_GITHUB__COM="$(cat /run/secrets/GITHUB_TOKEN):x-oauth-basic" bundle install && \
    cp -a /permabundle/. "$BUNDLE_PATH"/ && \
    bundle clean --force && \
    rm -rf "$BUNDLE_PATH"/ruby/*/bundler/gems/*/.git && \
    find "$BUNDLE_PATH" -type f \( -name '*.gem' -o -iname '*.a' -o -iname '*.o' -o -iname '*.h' -o -iname '*.c' -o -iname '*.hpp' -o -iname '*.cpp' \) -delete && \
    bundle exec bootsnap precompile --gemfile

# Copy application code
COPY . .

# Precompile bootsnap code for faster boot times
RUN bundle exec bootsnap precompile app/ lib/

# Precompiling assets for production
RUN SECRET_KEY_BASE_DUMMY=1 \
    ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=1 \
    ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=1 \
    ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=1 \
    ./bin/rails assets:precompile

# Final stage for app image
FROM base

# Install packages needed for deployment
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libsqlite3-0 libvips build-essential ffmpeg groff libreoffice-writer libreoffice-impress libreoffice-calc mupdf-tools sqlite3 libjemalloc-dev && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Copy built artifacts: gems, application
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /rails /rails

# Run and own only the runtime files as a non-root user for security
RUN useradd rails --create-home --shell /bin/bash && \
    chown -R rails:rails db log storage tmp
USER rails:rails

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Ruby GC tuning values pulled from Autotuner recommendations
ENV RUBY_GC_HEAP_0_INIT_SLOTS=692636 \
    RUBY_GC_HEAP_1_INIT_SLOTS=175943 \
    RUBY_GC_HEAP_2_INIT_SLOTS=148807 \
    RUBY_GC_HEAP_3_INIT_SLOTS=9169 \
    RUBY_GC_HEAP_4_INIT_SLOTS=3054 \
    RUBY_GC_MALLOC_LIMIT=67108864 \
    RUBY_GC_MALLOC_LIMIT_MAX=134217728 \
    LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so.2

# Start the server by default, this can be overwritten at runtime
EXPOSE 80 443 9394
CMD ["./bin/thrust", "./bin/rails", "server"]
