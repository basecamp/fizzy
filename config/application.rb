require_relative "boot"
require "rails/all"
require_relative "../lib/fizzy"
require_relative "../lib/action_pack/railtie"

Bundler.require(*Rails.groups)

module Fizzy
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Set here rather than in an initializer: Active Record copies these into filter_attributes when it
    # loads, and config/initializers/extensions.rb loads it before later initializers run.
    #
    # `code` covers the sign-in code a magic link is redeemed with, and a join code's route parameter. A
    # webhook's `url` can be a credential itself (a chat service's incoming webhook URL); it is matched
    # whole, so a parameter that merely ends in "url" keeps its value. The pattern also matches a nested
    # key's dotted path ("webhook.url"), which is what it is tested against once any dotted filter, such as
    # those `encrypts` adds, is present.
    config.filter_parameters += [
      *%i[ passw secret token _key crypt salt certificate otp ssn code ],
      /(?:\A|\.)url\z/
    ]

    # OAuth credentials the list above doesn't reach by partial match: an
    # authorization code and its PKCE verifier, client assertions and DPoP
    # proofs. `code` is matched whole, so code_challenge, which is public, stays
    # readable. This also filters the code from the logged redirect to the client.
    config.filter_parameters += [ /\Acode\z/i, :code_verifier, :device_code, :client_assertion, :dpop ]

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

    config.action_pack.passkey.draw_routes = false
    config.action_pack.passkey.challenge_url = -> { my_passkey_challenge_path(script_name: "") }

    config.mission_control.jobs.http_basic_auth_enabled = false
  end
end
