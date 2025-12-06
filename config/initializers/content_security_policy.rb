# Be sure to restart your server when you modify this file.

# Define an application-wide Content Security Policy.
# https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy

Rails.application.configure do
  # Configure from environment variables (fizzy-saas can override by setting config.x values first)
  config.x.content_security_policy.report_uri ||= ENV["CSP_REPORT_URI"]
  config.x.content_security_policy.report_only ||= ENV["CSP_REPORT_ONLY"] == "true"

  # Generate nonces for importmap and inline scripts
  config.content_security_policy_nonce_generator = ->(request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[ script-src ]

  config.content_security_policy do |policy|
    policy.default_src :self
    policy.script_src :self, "https://challenges.cloudflare.com"
    policy.connect_src :self, "https://storage.basecamp.com"
    policy.frame_src :self, "https://challenges.cloudflare.com"

    # Don't fight user tools: permit inline styles, data:/https: sources, and
    # blob: workers for accessibility extensions, privacy tools, and custom fonts.
    policy.style_src :self, :unsafe_inline
    policy.img_src :self, "blob:", "data:", "https:"
    policy.font_src :self, "data:", "https:"
    policy.media_src :self, "blob:", "data:", "https:"
    policy.worker_src :self, "blob:"

    policy.object_src :none
    policy.base_uri :none
    policy.form_action :self
    policy.frame_ancestors :self

    # Specify URI for violation reports (e.g., Sentry CSP endpoint)
    if report_uri = config.x.content_security_policy.report_uri
      policy.report_uri report_uri
    end
  end

  # Report violations without enforcing the policy.
  config.content_security_policy_report_only = config.x.content_security_policy.report_only
end unless ENV["DISABLE_CSP"]
