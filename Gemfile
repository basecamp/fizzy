source "https://rubygems.org"
git_source(:bc) { |repo| "https://github.com/basecamp/#{repo}" }

gem "rails", github: "rails/rails", branch: "main"

# Assets & front end
gem "importmap-rails"
gem "propshaft"
gem "stimulus-rails"
gem "turbo-rails"

# Deployment and drivers
gem "bootsnap", require: false
gem "kamal", require: false
gem "puma", ">= 5.0"
gem "solid_cable", ">= 3.0"
gem "solid_cache", "~> 1.0"
gem "solid_queue", "~> 1.2"
gem "sqlite3", ">= 2.0"
gem "thruster", require: false
gem "trilogy", "~> 2.9"

# Features
gem "bcrypt", "~> 3.1.7"
gem "geared_pagination", "~> 1.2"
gem "rqrcode"
gem "redcarpet"
gem "rouge"
gem "jbuilder"
gem "lexxy"
gem "image_processing", "~> 1.14"
gem "platform_agent"
gem "aws-sdk-s3", require: false
gem "web-push"
gem "net-http-persistent"
gem "mittens"
gem "useragent", bc: "useragent"

# Telemetry, logging, and operations
gem "mission_control-jobs"
gem "sentry-ruby"
gem "sentry-rails"
gem "rails_structured_logging", bc: "rails-structured-logging"
gem "yabeda"
gem "yabeda-actioncable"
gem "yabeda-activejob", github: "basecamp/yabeda-activejob", branch: "bulk-and-scheduled-jobs"
gem "yabeda-gc"
gem "yabeda-http_requests"
gem "yabeda-prometheus-mmap"
gem "yabeda-puma-plugin"
gem "yabeda-rails"
gem "webrick" # required for yabeda-prometheus metrics server
gem "prometheus-client-mmap", "~> 1.3"
gem "autotuner"
gem "benchmark" # indirect dependency, being removed from Ruby 3.5 stdlib so here to quash warnings

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
  gem "web-console"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
  gem "webmock"
  gem "vcr"
  gem "mocha"
end

group :saas do
  gem "fizzy-saas", path: "gems/fizzy-saas"
end
