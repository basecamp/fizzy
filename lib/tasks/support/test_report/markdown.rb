require_relative "formatting"

# Renders a TestReport as Markdown.
class TestReport::Markdown
  include TestReport::Formatting

  def initialize(report)
    @report = report
  end

  def to_s
    <<~MARKDOWN
      # Test report — #{@report[:generated_at].strftime("%Y-%m-%d %H:%M:%S")}

      - Branch: `#{@report[:git_branch]}` (`#{@report[:git_sha]}`)
      - Ruby #{@report[:ruby_version]}, Rails #{@report[:rails_version]}
      - Wall time: #{format_duration(@report[:wall_time])}
      - Scope: `bin/rails test` (non-system suite — system tests excluded, see note below)

      ## Summary

      #{summary_table}

      #{coverage_section}
      ## By category

      #{category_table}

      ## Slowest tests

      #{slowest_table}

      #{failures_section}
      ## Notes

      System tests (`test/system`) are not included in this report. They require a
      real Chrome/chromedriver, which this environment does not provide. Run
      `bin/rails test:system` separately to exercise them.
    MARKDOWN
  end

  private
    def summary_table
      t = @report[:tests]

      <<~TABLE
        | Runs | Assertions | Failures | Errors | Skips | Pass rate |
        | ---: | ---------: | -------: | -----: | ----: | --------: |
        | #{t[:count]} | #{t[:assertions]} | #{t[:failures]} | #{t[:errors]} | #{t[:skips]} | #{@report[:pass_rate]}% |
      TABLE
    end

    def coverage_section
      return "" unless @report[:coverage]

      c = @report[:coverage]
      rows = c[:groups].map do |name, group|
        "| #{cell(name)} | #{group[:covered_percent].round(2)}% | #{group[:covered_lines]}/#{group[:total_lines]} |"
      end.join("\n")

      <<~MARKDOWN
        ## Coverage

        Overall: **#{c[:covered_percent].round(2)}%** (#{c[:covered_lines]}/#{c[:total_lines]} lines)

        | Group | Coverage | Lines |
        | --- | ---: | ---: |
        #{rows}

      MARKDOWN
    end

    def category_table
      rows = @report[:categories].map do |name, stats|
        "| #{cell(name)} | #{stats[:count]} | #{stats[:failures]} | #{stats[:errors]} | #{stats[:skips]} | #{format_duration(stats[:total_time])} |"
      end.join("\n")

      <<~TABLE
        | Category | Runs | Failures | Errors | Skips | Time |
        | --- | ---: | -------: | -----: | ----: | ---: |
        #{rows}
      TABLE
    end

    def slowest_table
      rows = @report[:slowest].map do |test|
        "| #{cell(test[:klass])}##{cell(test[:name])} | #{format_duration(test[:time])} |"
      end.join("\n")

      <<~TABLE
        | Test | Time |
        | --- | ---: |
        #{rows}
      TABLE
    end

    def failures_section
      return "" if @report[:failures].empty?

      details = @report[:failures].map do |test|
        <<~DETAIL
          ### #{cell(test[:klass])}##{cell(test[:name])} (#{test[:result]})

          #{fenced(test[:failure_message])}
        DETAIL
      end.join("\n")

      "## Failures and errors\n\n#{details}\n"
    end

    # Escapes `|` so dynamic content (test/class/category names) can't break a
    # Markdown table row.
    def cell(value)
      value.to_s.gsub("|", "\\|")
    end

    # Picks a fence at least as long as the longest run of backticks already
    # present in the content, so a failure message containing ``` (or longer)
    # can't prematurely close the code block.
    def fenced(content)
      content = content.to_s
      longest_run = content.scan(/`+/).map(&:length).max || 0
      fence = "`" * [ 3, longest_run + 1 ].max

      "#{fence}\n#{content}\n#{fence}"
    end
end
