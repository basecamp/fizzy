require_relative "boot"

require "rails/all"
require "sqlite_vec" # Referenced in database.yml

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Fizzy
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Include the `lib` directory in autoload paths. Use the `ignore:` option
    # to list subdirectories that don't contain `.rb` files or that shouldn't
    # be reloaded or eager loaded.
    config.autoload_lib ignore: %w[ assets tasks rails_ext ]

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # enable load_async
    config.active_record.async_query_executor = :global_thread_pool
  end
end
