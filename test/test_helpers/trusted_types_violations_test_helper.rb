# Inventories the Trusted Types violations system tests trip, without failing
# any test over them.
#
# The test environment serves the report-only Trusted Types policy (see
# config/initializers/content_security_policy.rb). Before any page script runs,
# a listener injected over CDP records each `securitypolicyviolation` for that
# policy into sessionStorage, which survives full page loads. Teardown drains it
# into tmp/trusted_types_violations.jsonl, one line per violation, and the run
# ends by grouping those by sink and source location into
# tmp/trusted_types_violations.json.
#
# What it can't see, so read the inventory as a floor: windows other than the
# one a test starts in, named Capybara sessions, cross-origin frames, records
# left on another origin's sessionStorage, and writes after the final drain.
module TrustedTypesViolationsTestHelper
  extend ActiveSupport::Concern

  LOG = Rails.root.join("tmp/trusted_types_violations.jsonl")
  INVENTORY = Rails.root.join("tmp/trusted_types_violations.json")
  STORAGE_KEY = "trusted-types-violations"

  LISTENER = <<~JS
    window.addEventListener("securitypolicyviolation", (event) => {
      if (!/trusted-types/.test(event.effectiveDirective)) return

      try {
        const violations = JSON.parse(sessionStorage.getItem("#{STORAGE_KEY}") || "[]")
        violations.push({
          directive: event.effectiveDirective,
          sample: event.sample,
          source: event.sourceFile,
          line: event.lineNumber,
          column: event.columnNumber,
          page: location.pathname
        })
        sessionStorage.setItem("#{STORAGE_KEY}", JSON.stringify(violations))
      } catch {}
    }, true)
  JS

  DRAIN = <<~JS
    try {
      const violations = sessionStorage.getItem("#{STORAGE_KEY}") || "[]"
      sessionStorage.removeItem("#{STORAGE_KEY}")
      return violations
    } catch {
      return "[]"
    }
  JS

  class << self
    def reset
      FileUtils.rm_f [ LOG, INVENTORY ]
    end

    def record(test, violations)
      if violations.any?
        lines = violations.map { |violation| violation.merge("test" => test).to_json + "\n" }
        File.open(LOG, "a") { |file| file.write(lines.join) }
      end
    end

    def write_inventory
      violations = LOG.exist? ? LOG.each_line.map { |line| JSON.parse(line) } : []
      INVENTORY.write JSON.pretty_generate(inventory_of(violations))
    end

    private
      def inventory_of(violations)
        groups = violations.group_by { |violation| [ sink_of(violation), location_of(violation) ] }

        { "violations" => violations.size,
          "by_sink" => violations.group_by { |violation| sink_of(violation) }.transform_values(&:size).sort_by { -it.last }.to_h,
          "sites" => groups.map { |(sink, location), group| site(sink, location, group) }.sort_by { -it["count"] } }
      end

      def site(sink, location, violations)
        { "sink" => sink,
          "source" => location,
          "count" => violations.size,
          "pages" => violations.map { it["page"] }.uniq.sort,
          "tests" => violations.map { it["test"] }.uniq.sort,
          "example" => violations.first["sample"] }
      end

      # Chromium samples read "<sink>|<first 40 characters written>".
      def sink_of(violation)
        violation["sample"].to_s.split("|", 2).first.presence || violation["directive"]
      end

      def location_of(violation)
        [ script_of(violation["source"]), violation["line"], violation["column"] ].join(":")
      end

      # Drop the origin, which changes with the test server's port, and the
      # asset digest, which changes with every build.
      def script_of(source)
        path = URI.parse(source.to_s).path.presence || source.presence || "(inline)"
        path.sub(/-\h{8,}(?=\.js\z)/, "")
      rescue URI::InvalidURIError
        source
      end
  end

  included do
    TrustedTypesViolationsTestHelper.reset
    Minitest.after_run { TrustedTypesViolationsTestHelper.write_inventory }

    setup do
      @trusted_types_window = page.current_window
      @trusted_types_listener = page.driver.browser.execute_cdp("Page.addScriptToEvaluateOnNewDocument", source: LISTENER)["identifier"]
    end
  end

  # Teardown callbacks run after Capybara has reset the session to a blank
  # page, so drain before then.
  def before_teardown
    collect_trusted_types_violations
  ensure
    super
  end

  private
    # The listener lives in the window the test started in, which the test
    # may have switched away from or closed.
    def collect_trusted_types_violations
      within_window @trusted_types_window do
        drain_trusted_types_violations
      ensure
        remove_trusted_types_listener
      end
    rescue Selenium::WebDriver::Error::WebDriverError, Capybara::WindowError => error
      warn "Trusted Types inventory lost #{name}'s violations: #{error.class}"
    end

    def drain_trusted_types_violations
      TrustedTypesViolationsTestHelper.record "#{self.class.name}##{name}", JSON.parse(page.execute_script(DRAIN))
    rescue Selenium::WebDriver::Error::WebDriverError => error
      warn "Trusted Types inventory lost #{name}'s violations: #{error.class}"
    end

    # A listener left registered survives Capybara's reset and would record
    # every later test's violations twice.
    def remove_trusted_types_listener
      page.driver.browser.execute_cdp("Page.removeScriptToEvaluateOnNewDocument", identifier: @trusted_types_listener)
    end
end
