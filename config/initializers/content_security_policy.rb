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

# Trusted Types report-only pilot — XSS counteroffensive Tier C (Chromium-only).
#
# Collects telemetry on raw-string writes to DOM sinks (innerHTML, outerHTML,
# insertAdjacentHTML, document.write, ...) without enforcing anything. It rides
# a SEPARATE Content-Security-Policy-Report-Only header so it never touches the
# enforcing policy below — report-only can only report, never block, so no
# un-migrated sink throws on Chromium. Non-Chromium browsers ignore the
# directive entirely.
#
# Only `require-trusted-types-for 'script'` is emitted. We deliberately omit a
# `trusted-types` policy-name allowlist: this pilot registers no named createHTML
# policy (that is the parked enforcement phase, gated on the shared sanitize()
# chokepoint), and leaving the allowlist off keeps policy creation unrestricted
# so lexxy's isolated DOMPurify policy and any duplicates raise no policy-creation
# noise — we only want sink-write violations.
class TrustedTypesReportOnly
  DIRECTIVE = "require-trusted-types-for 'script'"
  HEADER = ActionDispatch::Constants::CONTENT_SECURITY_POLICY_REPORT_ONLY

  def initialize(app, report_uri = nil)
    @app = app
    @policy = report_uri ? "#{DIRECTIVE}; report-uri #{report_uri}" : DIRECTIVE
  end

  def call(env)
    status, headers, body = @app.call(env)

    # Only documents run script, so only they can trip a Trusted Types sink.
    # Stack as an additional report-only policy rather than overwriting: when the
    # app policy is itself report-only, both headers ride together, each
    # reporting independently.
    if headers[Rack::CONTENT_TYPE].to_s.start_with?("text/html")
      headers[HEADER] = [ headers[HEADER], @policy ].compact.join("\n")
    end

    [ status, headers, body ]
  end
end

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

  # Trusted Types telemetry rides its own report-only header. Inserted outside
  # the Rails CSP middleware so it appends after that header is written, letting
  # it stack alongside (never clobber) an app policy that is itself report-only.
  config.middleware.insert_before ActionDispatch::ContentSecurityPolicy::Middleware, TrustedTypesReportOnly, report_uri

  # Locked-down policy for the static pages served from public/ (error pages).
  # They carry no script or inline styles at all, so everything falls back to
  # default-src 'none'.
  static_policy = "default-src 'none'; img-src 'self'; style-src 'self'; " \
    "base-uri 'none'; form-action 'none'; frame-ancestors 'none'"

  # Report violations from the static pages to the same collector as the
  # app policy, so a report-only rollout sees them too.
  static_policy += "; report-uri #{report_uri}" if report_uri

  # Honor report-only mode for the static policy too, so the report_only
  # switch disables enforcement everywhere at once.
  static_policy_header = report_only ? ActionDispatch::Constants::CONTENT_SECURITY_POLICY_REPORT_ONLY \
                                     : ActionDispatch::Constants::CONTENT_SECURITY_POLICY

  # Files served straight from public/ return before the CSP middleware runs,
  # so they get the static policy stamped by the file server.
  config.public_file_server.headers = (config.public_file_server.headers || {}) \
    .merge(static_policy_header => static_policy)

  # The same public/ pages served through the error path (a real 404/500
  # renders public/404.html via the exceptions app, bypassing the static
  # file server) get it too. JSON error responses pass through untouched.
  # A deployment that configures its own exceptions_app keeps full control
  # of its responses, headers included.
  if config.exceptions_app.nil?
    public_exceptions = ActionDispatch::PublicExceptions.new(Rails.public_path)
    config.exceptions_app = ->(env) do
      public_exceptions.call(env).tap do |_status, headers, _body|
        if headers[Rack::CONTENT_TYPE].to_s.start_with?("text/html")
          headers[static_policy_header] = static_policy
        end
      end
    end
  end
end unless ENV["DISABLE_CSP"]
