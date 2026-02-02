# Be sure to restart your server when you modify this file.

# Define an application-wide Content Security Policy.
# https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy
#
# Directives are configurable via environment variables with fallback to config.x
# settings. This allows fizzy-saas (or other deployments) to extend the base policy
# without duplicating it.
#
# ENV vars (space-separated sources):
#   CSP_DEFAULT_SRC, CSP_SCRIPT_SRC, CSP_STYLE_SRC, CSP_CONNECT_SRC, CSP_FRAME_SRC,
#   CSP_IMG_SRC, CSP_FONT_SRC, CSP_MEDIA_SRC, CSP_WORKER_SRC, CSP_FRAME_ANCESTORS,
#   CSP_FORM_ACTION, CSP_REPORT_URI, CSP_REPORT_ONLY, DISABLE_CSP
#
# config.x.content_security_policy.* (string, space-separated string, or array):
#   script_src, style_src, connect_src, frame_src, img_src, font_src, media_src,
#   worker_src, frame_ancestors, form_action, report_uri, report_only

Rails.application.configure do
  # Helper to get additional CSP sources from ENV or config.x.
  # Supports: nil, string, space-separated string, or array.
  sources = ->(directive) do
    env_key = "CSP_#{directive.to_s.upcase}"
    value = if ENV.key?(env_key)
      ENV[env_key]
    else
      config.x.content_security_policy.send(directive)
    end

    case value
    when nil then []
    when Array then value
    when String then value.split
    else []
    end
  end

  # Report URI and report-only mode
  report_uri = ENV.fetch("CSP_REPORT_URI") { config.x.content_security_policy.report_uri }
  report_only =
    if ENV.key?("CSP_REPORT_ONLY")
      ENV["CSP_REPORT_ONLY"] == "true"
    else
      config.x.content_security_policy.report_only
    end

  # Generate nonces for importmap and inline scripts
  config.content_security_policy_nonce_generator = ->(request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[ script-src ]

  config.content_security_policy do |policy|
    policy.default_src :self, *sources.(:default_src)
    policy.script_src :self, *sources.(:script_src)
    policy.connect_src :self, *sources.(:connect_src)
    policy.frame_src :self, *sources.(:frame_src)

    # Don't fight user tools: permit inline styles, data:/https: sources, and
    # blob: workers for accessibility extensions, privacy tools, and custom fonts.
    policy.style_src :self, :unsafe_inline, *sources.(:style_src)
    policy.img_src :self, "blob:", "data:", "https:", *sources.(:img_src)
    policy.font_src :self, "data:", "https:", *sources.(:font_src)
    policy.media_src :self, "blob:", "data:", "https:", *sources.(:media_src)
    policy.worker_src :self, "blob:", *sources.(:worker_src)

    # Security-critical defaults (not configurable)
    policy.object_src :none
    policy.base_uri :none

    policy.form_action :self, *sources.(:form_action)
    policy.frame_ancestors :self, *sources.(:frame_ancestors)

    # Specify URI for violation reports (e.g., Sentry CSP endpoint)
    policy.report_uri report_uri if report_uri
  end

  # Report violations without enforcing the policy.
  config.content_security_policy_report_only = report_only
end unless ENV["DISABLE_CSP"]
