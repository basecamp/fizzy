module AccountSlug
  PATTERN = /(\d{7,})/
  FORMAT = "%07d"
  PATH_INFO_MATCH = /\A(\/#{AccountSlug::PATTERN})/

  # We're using account id prefixes in the URL path. Rather than namespace
  # all our routes, we're "mounting" the Rails app at this URL prefix.
  def self.extract(request)
    # $1, $2, $' == script_name, slug, path_info
    if request.script_name && request.script_name =~ PATH_INFO_MATCH
      # Likely due to restarting the action cable connection after upgrade
      AccountSlug.decode($2)
    elsif request.path_info =~ PATH_INFO_MATCH
      # Yanks the prefix off PATH_INFO and move it to SCRIPT_NAME
      request.engine_script_name = request.script_name = $1
      request.path_info   = $'.empty? ? "/" : $'

      # Return the account id for tenanting.
      AccountSlug.decode($2)
    end
  end

  def self.decode(slug) slug.to_i end
  def self.encode(id) FORMAT % id end

  def self.creation_request?(request)
    if defined?(Fizzy::Saas) && request.post?
      path = Fizzy::Saas::Engine.routes.url_helpers.signup_completion_path
      request.path_info =~ /\A\/#{PATTERN}#{Regexp.escape(path)}\Z/
    else
      false
    end
  end
end

Rails.application.config.after_initialize do
  Rails.application.config.active_record_tenanted.tenant_resolver = ->(request) do
    if AccountSlug.creation_request?(request)
      AccountSlug.extract(request)
      nil
    else
      AccountSlug.extract(request)
    end
  end
end
