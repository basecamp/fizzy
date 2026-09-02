require "cgi"
require_relative "formatting"

# Renders a TestReport as a self-contained HTML document (inline CSS, no
# external assets) so it can be opened and shared standalone.
class TestReport::Html
  include TestReport::Formatting

  def initialize(report)
    @report = report
  end

  def to_s
    <<~HTML
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="utf-8">
        <title>Test report — #{escape(@report[:generated_at].strftime("%Y-%m-%d %H:%M:%S"))}</title>
        <style>
          body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; margin: 2rem; color: #1a1a1a; }
          h1 { font-size: 1.5rem; }
          h2 { font-size: 1.15rem; margin-top: 2rem; border-bottom: 1px solid #ddd; padding-bottom: 0.25rem; }
          h3 { font-size: 1rem; margin-top: 1.5rem; }
          table { border-collapse: collapse; width: 100%; margin: 0.75rem 0; }
          th, td { border: 1px solid #ddd; padding: 0.4rem 0.6rem; text-align: left; }
          th { background: #f5f5f5; }
          td.num, th.num { text-align: right; }
          .meta { color: #555; }
          .pass { color: #1a7f37; }
          .fail { color: #c0392b; }
          pre { background: #f5f5f5; padding: 0.75rem; overflow-x: auto; white-space: pre-wrap; }
          code { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; }
        </style>
      </head>
      <body>
        <h1>Test report — #{escape(@report[:generated_at].strftime("%Y-%m-%d %H:%M:%S"))}</h1>
        <p class="meta">
          Branch <code>#{escape(@report[:git_branch])}</code> (<code>#{escape(@report[:git_sha])}</code>) &middot;
          Ruby #{escape(@report[:ruby_version])} &middot; Rails #{escape(@report[:rails_version])} &middot;
          Wall time #{format_duration(@report[:wall_time])} &middot;
          Scope: <code>bin/rails test</code> (system tests excluded, see notes)
        </p>

        <h2>Summary</h2>
        #{summary_table}

        #{coverage_section}

        <h2>By category</h2>
        #{category_table}

        <h2>Slowest tests</h2>
        #{slowest_table}

        #{failures_section}

        <h2>Notes</h2>
        <p>System tests (<code>test/system</code>) are not included in this report. They
        require a real Chrome/chromedriver, which this environment does not provide.
        Run <code>bin/rails test:system</code> separately to exercise them.</p>
      </body>
      </html>
    HTML
  end

  private
    def summary_table
      t = @report[:tests]
      status_class = @report[:success] ? "pass" : "fail"

      <<~HTML
        <table>
          <tr><th class="num">Runs</th><th class="num">Assertions</th><th class="num">Failures</th><th class="num">Errors</th><th class="num">Skips</th><th class="num">Pass rate</th></tr>
          <tr class="#{status_class}">
            <td class="num">#{t[:count]}</td>
            <td class="num">#{t[:assertions]}</td>
            <td class="num">#{t[:failures]}</td>
            <td class="num">#{t[:errors]}</td>
            <td class="num">#{t[:skips]}</td>
            <td class="num">#{@report[:pass_rate]}%</td>
          </tr>
        </table>
      HTML
    end

    def coverage_section
      return "" unless @report[:coverage]

      c = @report[:coverage]
      rows = c[:groups].map do |name, group|
        "<tr><td>#{escape(name.to_s)}</td><td class=\"num\">#{group[:covered_percent].round(2)}%</td><td class=\"num\">#{group[:covered_lines]}/#{group[:total_lines]}</td></tr>"
      end.join

      <<~HTML
        <h2>Coverage</h2>
        <p>Overall: <strong>#{c[:covered_percent].round(2)}%</strong> (#{c[:covered_lines]}/#{c[:total_lines]} lines)</p>
        <table>
          <tr><th>Group</th><th class="num">Coverage</th><th class="num">Lines</th></tr>
          #{rows}
        </table>
      HTML
    end

    def category_table
      rows = @report[:categories].map do |name, stats|
        "<tr><td>#{escape(name)}</td><td class=\"num\">#{stats[:count]}</td><td class=\"num\">#{stats[:failures]}</td><td class=\"num\">#{stats[:errors]}</td><td class=\"num\">#{stats[:skips]}</td><td class=\"num\">#{format_duration(stats[:total_time])}</td></tr>"
      end.join

      <<~HTML
        <table>
          <tr><th>Category</th><th class="num">Runs</th><th class="num">Failures</th><th class="num">Errors</th><th class="num">Skips</th><th class="num">Time</th></tr>
          #{rows}
        </table>
      HTML
    end

    def slowest_table
      rows = @report[:slowest].map do |test|
        "<tr><td>#{escape(test[:klass])}##{escape(test[:name])}</td><td class=\"num\">#{format_duration(test[:time])}</td></tr>"
      end.join

      <<~HTML
        <table>
          <tr><th>Test</th><th class="num">Time</th></tr>
          #{rows}
        </table>
      HTML
    end

    def failures_section
      return "" if @report[:failures].empty?

      details = @report[:failures].map do |test|
        <<~HTML
          <h3>#{escape(test[:klass])}##{escape(test[:name])} (#{escape(test[:result])})</h3>
          <pre><code>#{escape(test[:failure_message].to_s)}</code></pre>
        HTML
      end.join

      "<h2>Failures and errors</h2>#{details}"
    end

    def escape(string)
      CGI.escapeHTML(string.to_s)
    end
end
