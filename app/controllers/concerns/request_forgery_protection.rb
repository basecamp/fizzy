module RequestForgeryProtection
  extend ActiveSupport::Concern

  included do
    after_action :append_sec_fetch_site_to_vary_header
  end

  private
    def append_sec_fetch_site_to_vary_header
      vary_header = response.headers["Vary"].to_s.split(",").map(&:strip).reject(&:blank?)
      response.headers["Vary"] = (vary_header + [ "Sec-Fetch-Site" ]).join(",")
    end

    def verified_request?
      return true if request.get? || request.head? || !protect_against_forgery?

      origin = valid_request_origin?
      token = any_authenticity_token_valid?
      sec_fetch_site = safe_fetch_site?
      report_on_forgery_protection_results(origin:, token:, sec_fetch_site:)

      origin && token
    end

    SAFE_FETCH_SITES = %w[ same-origin same-site ]

    def safe_fetch_site?
      SAFE_FETCH_SITES.include?(sec_fetch_site_value)
    end

    def sec_fetch_site_value
      request.headers["Sec-Fetch-Site"].to_s.downcase
    end

    def report_on_forgery_protection_results(origin:, token:, sec_fetch_site:)
      results = { origin:, token:, sec_fetch_site: }

      unless results.values.all?
        info = results.transform_values { it ? "pass" : "fail" }
        info[:origin] += " (#{request.origin})"
        info[:sec_fetch_site] += " (#{sec_fetch_site_value})"

        Rails.logger.info "CSRF protection check: " + info.map { it.join(" ") }.join(", ")

        if (origin && token) != sec_fetch_site
          Sentry.capture_message "CSRF protection mismatch", level: :info, extra: { info: info }
        end
      end
    end
end
