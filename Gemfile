source "https://rubygems.org"
git_source(:bc) { |repo| "https://github.com/basecamp/#{repo}" }
ruby file: ".ruby-version"

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

group :development, :test do
  gem "debug"
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
end

group :development do
  gem "hotwire-spark"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
end
