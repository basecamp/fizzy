source "https://rubygems.org"

git_source(:bc) { |repo| "https://github.com/basecamp/#{repo}" }

gem "rails", github: "rails/rails", branch: "main"

# Assets & front end
gem "importmap-rails"
gem "propshaft"
gem "stimulus-rails"
gem "turbo-rails", github: "hotwired/turbo-rails", branch: "offline-cache"

# Deployment and drivers
gem "dotenv-rails", groups: [:development, :test]
gem "bootsnap", require: false
gem "kamal", require: false
gem "puma", ">= 5.0"
gem "solid_cable", ">= 3.0"
gem "solid_cache", "~> 1.0"
gem "solid_queue", "~> 1.3"
gem "sqlite3", ">= 2.0"
gem "thruster", require: false
gem "trilogy", "~> 2.10"

# Features
gem "bcrypt", "~> 3.1.22"
gem "geared_pagination", "~> 1.2"
gem "rqrcode"
gem "rouge"
gem "jbuilder"
gem "lexxy", "0.9.0.beta"
gem "image_processing", "~> 1.14"
gem "platform_agent"
gem "aws-sdk-s3", require: false
gem "web-push"
gem "net-http-persistent"
gem "zip_kit"
gem "mittens"
gem "useragent", bc: "useragent"

# Operations
gem "autotuner"
gem "mission_control-jobs"
gem "stackprof"
gem "benchmark" # indirect dependency, being removed from Ruby 3.5 stdlib so here to quash warnings

# Telemetry
gem "sentry-ruby"
gem "sentry-rails"
gem "sentry-yabeda", github: "getsentry/sentry-ruby", branch: "feat/sentry-yabeda", glob: "sentry-yabeda/*.gemspec"
gem "yabeda"
# gem "yabeda-rails" # Overlaps with Sentry's native request/db/view tracing — no added value
gem "yabeda-puma-plugin"               # Thread pool utilization, backlog — invisible to Sentry tracing
gem "yabeda-activejob"                 # Enqueue counts, queue latency — Sentry traces execution but not enqueue/wait
# gem "yabeda-actioncable"             # WebSocket connection counts — needs ApplicationCable::Channel (no channels in OSS Fizzy)
gem "yabeda-gc"                        # GC pause time — runtime metric invisible to request tracing
gem "yabeda-gvl_metrics"               # GVL wait/running/io_wait time — core runtime contention metric
gem "yabeda-activerecord"              # Connection pool stats — pool exhaustion invisible to Sentry tracing
gem "yabeda-http_requests"             # External HTTP call counts/duration — S3, web-push, net-http-persistent

group :development, :test do
  gem "brakeman", require: false
  gem "bundler-audit", require: false
  gem "debug"
  gem "faker"
  gem "letter_opener"
  gem "rack-mini-profiler"
  gem "rubocop-rails-omakase", require: false
end

group :development do
  gem "web-console", github: "rails/web-console"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
  gem "webmock"
  gem "vcr"
  gem "mocha"
end
