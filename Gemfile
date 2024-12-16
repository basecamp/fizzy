source "https://rubygems.org"
git_source(:bc) { |repo| "https://github.com/basecamp/#{repo}" }
ruby file: ".ruby-version"

gem "rails", github: "rails/rails", branch: "main"

# Assets & front end
gem "importmap-rails"
gem "propshaft"
gem "stimulus-rails"
gem "turbo-rails"
gem "hotwire_combobox", github: "josefarias/hotwire_combobox", branch: :main

# Deployment and drivers
gem "bootsnap", require: false
gem "puma", ">= 5.0"
gem "solid_cable", ">= 3.0"
gem "solid_cache", "~> 1.0"
gem "solid_queue", "~> 1.1"
gem "sqlite3", ">= 2.0"
gem "thruster", require: false

# Features
gem "bcrypt", "~> 3.1.7"
gem "rqrcode"
gem "redcarpet"
gem "rouge"
gem "jbuilder"
gem "active_record-tenanted", github: "basecamp/active_record-tenanted", branch: "main"

# Telemetry
gem "sentry-ruby"
gem "sentry-rails"

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
