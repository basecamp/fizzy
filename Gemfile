source "https://rubygems.org"
ruby file: ".ruby-version"

gem "rails", github: "rails/rails", branch: "main"

# Assets & front end
gem "importmap-rails"
gem "propshaft"
gem "stimulus-rails"
gem "turbo-rails"

# Deployment and drivers
gem "bootsnap", require: false
gem "puma", ">= 5.0"
gem "sqlite3", ">= 2.0"
gem "thruster"

# Features
gem "bcrypt", "~> 3.1.7"

# Needed until Ruby 3.3.4 is released https://github.com/ruby/ruby/pull/11006
gem "net-pop", github: "ruby/net-pop"

group :development, :test do
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
end
