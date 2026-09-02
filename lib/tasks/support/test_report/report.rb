require "json"
require "fileutils"
require_relative "formatting"
require_relative "markdown"
require_relative "html"

# Runs the (non-system) test suite with coverage instrumentation enabled and
# writes a dated Markdown + self-contained HTML report to the Obsidian vault.
#
# System tests are excluded here for the same reason `bin/rails test` excludes
# them by default: they need a real Chrome/chromedriver, which this task does
# not attempt to provision. Run `bin/rails test:system` separately.
class TestReport
  VAULT_DIR = File.expand_path("~/Documents/Obsidian Vault/fizzy/test-reports")
  SLOWEST_COUNT = 10

  def run
    tests_json_path = Rails.root.join("tmp/test_report_tests.json")
    coverage_json_path = Rails.root.join("tmp/test_report_coverage.json")
    FileUtils.rm_f(tests_json_path)
    FileUtils.rm_f(coverage_json_path)

    puts "Running test suite (system tests excluded, see report notes)..."
    started_at = Time.now
    success = system(
      { "COVERAGE" => "1", "TEST_REPORT_JSON" => tests_json_path.to_s, "COVERAGE_REPORT_JSON" => coverage_json_path.to_s },
      "bin/rails", "test"
    )
    wall_time = Time.now - started_at

    unless File.exist?(tests_json_path)
      abort "Test run did not produce a report — the suite likely crashed before finishing. Check the output above."
    end

    tests = JSON.parse(File.read(tests_json_path), symbolize_names: true)
    coverage = File.exist?(coverage_json_path) ? JSON.parse(File.read(coverage_json_path), symbolize_names: true) : nil
    FileUtils.rm_f(tests_json_path)
    FileUtils.rm_f(coverage_json_path)

    report = build_report(success: success, wall_time: wall_time, tests: tests, coverage: coverage)
    md_path, html_path = write_report(report)

    puts "Wrote #{md_path}"
    puts "Wrote #{html_path}"

    open_in_browser(html_path)

    exit(1) unless success
  end

  private
    def build_report(success:, wall_time:, tests:, coverage:)
      {
        generated_at: Time.now,
        git_branch: git_branch,
        git_sha: git_sha,
        ruby_version: RUBY_VERSION,
        rails_version: Rails::VERSION::STRING,
        success: success,
        wall_time: wall_time,
        tests: tests,
        pass_rate: pass_rate(tests),
        coverage: coverage,
        categories: categorize(tests[:tests]),
        slowest: tests[:tests].sort_by { |test| -test[:time] }.first(SLOWEST_COUNT),
        failures: tests[:tests].reject { |test| test[:result] == "pass" }
      }
    end

    def pass_rate(tests)
      if tests[:count].zero?
        0.0
      else
        ((tests[:count] - tests[:failures] - tests[:errors]).to_f / tests[:count] * 100).round(2)
      end
    end

    def git_branch
      `git rev-parse --abbrev-ref HEAD`.strip
    end

    def git_sha
      `git rev-parse --short HEAD`.strip
    end

    # Groups by the top-level directory under test/ (models, controllers, ...).
    def categorize(test_results)
      test_results.group_by { |test| category_for(test[:file]) }.transform_values do |group|
        {
          count: group.size,
          failures: group.count { |test| test[:result] == "fail" },
          errors: group.count { |test| test[:result] == "error" },
          skips: group.count { |test| test[:result] == "skip" },
          total_time: group.sum { |test| test[:time] }
        }
      end.sort.to_h
    end

    def category_for(file)
      if file && (match = file.match(%r{test/([^/]+)/}))
        match[1]
      else
        "other"
      end
    end

    def write_report(report)
      FileUtils.mkdir_p(VAULT_DIR)

      timestamp = report[:generated_at].strftime("%Y-%m-%d_%H%M%S")
      md_path = File.join(VAULT_DIR, "#{timestamp}.md")
      html_path = File.join(VAULT_DIR, "#{timestamp}.html")

      File.write(md_path, TestReport::Markdown.new(report).to_s)
      File.write(html_path, TestReport::Html.new(report).to_s)

      [ md_path, html_path ]
    end

    def open_in_browser(html_path)
      return unless RbConfig::CONFIG["host_os"] =~ /darwin/
      return if ENV["CI"]

      system("open", html_path)
    end
end
