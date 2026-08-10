require "undercover/simplecov_formatter"
require "simplecov/formatter/html_formatter"
require_relative "lib/fizzy"

SimpleCov.load_profile "rails"

# Fizzy.saas? rather than a local ENV check, so that tmp/saas.txt -- the checkout-level
# switch bin/setup and AGENTS.md use -- is honoured here too. Getting this wrong is silent:
# the app boots SaaS and runs saas/ code while coverage quietly ignores every line of it.
SimpleCov.cover "{app,lib}/**/*.{rb,rake}"
SimpleCov.cover "saas/{app,lib}/**/*.{rb,rake}" if Fizzy.saas?

SimpleCov.enable_coverage :branch
SimpleCov.ignore_branches :eval_generated
SimpleCov.merge_timeout 3600
SimpleCov.command_name ENV["COVERAGE_COMMAND"] if ENV["COVERAGE_COMMAND"]
SimpleCov.formatters = [
  SimpleCov::Formatter::HTMLFormatter,
  SimpleCov::Formatter::Undercover
]
