# One Trusted Types violation, cut down from the browser's CSP report.
#
# Browsers put a sample in every Trusted Types report: the sink and the first 40
# characters of the string written to it, which can be a user's own content. No
# CSP keyword turns that off, and Sentry can't scrub it, so reports come here
# and keep only the sink name, the script location, and the page's route. The
# sampled content, the page's full URL and everything else are dropped.
class TrustedTypesViolation
  DIRECTIVE = "require-trusted-types-for"

  # Beyond any real script's line or column, and short enough that a report
  # can't make the log line long with a 16 KB integer.
  MAX_POSITION = 10_000_000

  class << self
    def parse(json)
      report = JSON.parse(json.to_s)
      report = report["csp-report"] if report.is_a?(Hash)

      if report.is_a?(Hash) && report["effective-directive"] == DIRECTIVE
        new(report)
      end
    rescue JSON::ParserError
      nil
    end
  end

  def initialize(report)
    @report = report
  end

  # "Element innerHTML|<p>what someone typed</p>" keeps "Element innerHTML".
  def sink
    @report["script-sample"].to_s.split("|", 2).first.to_s.gsub(/[^\w ]/, "").first(64)
  end

  def source
    [ path_of(@report["source-file"]).presence || "(inline)", number(@report["line-number"]), number(@report["column-number"]) ].join(":")
  end

  def route
    path = path_of(@report["document-uri"]).sub(AccountSlug::PATH_INFO_MATCH, "")
    recognized = Rails.application.routes.recognize_path(path.presence || "/")
    "#{recognized[:controller]}##{recognized[:action]}"
  rescue ActionController::RoutingError
    "unknown"
  end

  def to_s
    "Trusted Types violation: sink=#{sink} source=#{source} route=#{route}"
  end

  private
    # Reports come from anyone, so a field may be any JSON type.
    def number(value)
      value.is_a?(Integer) && value.between?(0, MAX_POSITION) ? value : 0
    end

    def path_of(url)
      URI.parse(url.to_s).path.to_s.gsub(/[^\w\/.\-]/, "").first(256)
    rescue URI::InvalidURIError
      ""
    end
end
