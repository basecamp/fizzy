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
      super || safe_fetch_site? || request.format.json?
    end

    SAFE_FETCH_SITES = %w[ same-origin same-site ]

    def safe_fetch_site?
      SAFE_FETCH_SITES.include?(sec_fetch_site_value)
    end

    def sec_fetch_site_value
      request.headers["Sec-Fetch-Site"].to_s.downcase
    end
end
