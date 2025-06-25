source "https://rubygems.org"
git_source(:bc) { |repo| "https://github.com/basecamp/#{repo}" }

gem "rails", github: "rails/rails", branch: "main"

# Assets & front end
gem "importmap-rails"
gem "propshaft"
gem "stimulus-rails"
gem "turbo-rails"

# Deployment and drivers
gem "active_record-tenanted", bc: "active_record-tenanted"
gem "bootsnap", require: false
gem "kamal", bc: "kamal", ref: "344e2d79", require: false
gem "puma", ">= 5.0"
gem "solid_cable", ">= 3.0"
gem "solid_cache", "~> 1.0"
gem "solid_queue", "~> 1.1"
gem "sqlite3", ">= 2.0"
gem "thruster", require: false

# Features
gem "bcrypt", "~> 3.1.7"
gem "geared_pagination", "~> 1.2"
gem "rqrcode"
gem "redcarpet"
gem "rouge"
gem "jbuilder"
gem "actiontext-lexical", bc: "actiontext-lexical"
gem "image_processing", "~> 1.14"
gem "platform_agent"
gem "aws-sdk-s3", require: false

# 37id and Queenbee integration
gem "signal_id", bc: "signal_id", branch: "rails4"
gem "mysql2" # needed by signal_id
gem "queuety", bc: "queuety", branch: "rails4" # needed by signal_id
gem "service_concurrency_prevention", bc: "service_concurrency_prevention" # needed by queuety
gem "portfolio", ">= 4.6", bc: "portfolio" # needed by signal_id
gem "file_repository", "~> 1.4.5", bc: "file_repository" # needed by portfolio
gem "queenbee", bc: "queenbee-plugin"
gem "activeresource", require: "active_resource" # needed by queenbee

# Telemetry, logging, and operations
gem "mission_control-jobs"
gem "sentry-ruby"
gem "sentry-rails"
gem "rails_structured_logging", bc: "rails-structured-logging"

# AI
gem "ruby_llm", git: "https://github.com/crmne/ruby_llm.git"
gem "sqlite-vec", "0.1.7.alpha.2"
gem "tiktoken_ruby"

group :development, :test do
  gem "debug"
  gem "bundler-audit", require: false
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
  gem "webmock"
  gem "vcr"
  gem "mocha"
end
