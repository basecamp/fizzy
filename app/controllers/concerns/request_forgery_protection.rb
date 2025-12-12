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
      request.get? || request.head? || !protect_against_forgery? ||
        (valid_request_origin? && safe_fetch_site?)
    end

    SAFE_FETCH_SITES = %w[ same-origin same-site ]

    def safe_fetch_site?
      SAFE_FETCH_SITES.include?(sec_fetch_site_value) || (sec_fetch_site_value.nil? && api_request?)
    end

    def api_request?
      request.format.json?
    end

    def sec_fetch_site_value
      request.headers["Sec-Fetch-Site"].to_s.downcase.presence
    end
end
