module AccountSlug
  PATTERN = /(\d{7,})/
  FORMAT = "%07d"
  PATH_INFO_MATCH = /\A(\/#{AccountSlug::PATTERN})/

  class Extractor
    def initialize(app)
      @app = app
    end

    # We're using account id prefixes in the URL path. Rather than namespace
    # all our routes, we're "mounting" the Rails app at this URL prefix.
    def call(env)
      request = ActionDispatch::Request.new(env)

      # $1, $2, $' == script_name, slug, path_info
      if request.script_name && request.script_name =~ PATH_INFO_MATCH
        # Likely due to restarting the action cable connection after upgrade
        env["fizzy.external_account_id"] = AccountSlug.decode($2)
      elsif request.path_info =~ PATH_INFO_MATCH
        # Yanks the prefix off PATH_INFO and move it to SCRIPT_NAME
        request.engine_script_name = request.script_name = $1
        request.path_info   = $'.empty? ? "/" : $'

        # Stash the account's Queenbee ID.
        env["fizzy.external_account_id"] = AccountSlug.decode($2)
        Current.account = Account.find_by(external_account_id: env["fizzy.external_account_id"])
      end

      @app.call env
    end
  end

  def self.decode(slug) slug.to_i end
  def self.encode(id) FORMAT % id end
end

Rails.application.config.middleware.tap do |stack|
  stack.insert_before Rails::Rack::Logger, AccountSlug::Extractor
end
