require_relative "boot"
require "rails/all"
require_relative "../lib/fizzy"

Bundler.require(*Rails.groups)

module Fizzy
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Include the `lib` directory in autoload paths. Use the `ignore:` option
    # to list subdirectories that don't contain `.rb` files or that shouldn't
    # be reloaded or eager loaded.
    config.autoload_lib ignore: %w[ assets tasks rails_ext ]

    # Enable debug mode for Rails event logging so we get SQL query logs.
    # This was made necessary by the change in https://github.com/rails/rails/pull/55900
    config.after_initialize do
      Rails.event.debug_mode = true
    end

    # Use UUID primary keys for all new tables
    config.generators do |g|
      g.orm :active_record, primary_key_type: :uuid
    end
  end
end
