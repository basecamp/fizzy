source "https://rubygems.org"
git_source(:bc) { |repo| "https://github.com/basecamp/#{repo}" }

gem "rails", github: "rails/rails", branch: "main"
gem "active_record-tenanted", bc: "active_record-tenanted"

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

# Telemetry and logging
gem "sentry-ruby"
gem "sentry-rails"
gem "rails_structured_logging", bc: "rails-structured-logging"

gem "ruby_llm", git: "https://github.com/crmne/ruby_llm.git"
gem "sqlite-vec", "0.1.7.alpha.2"

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
end
