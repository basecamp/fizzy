class TestReport; end

# Shared presentation helpers for TestReport::Markdown and TestReport::Html.
module TestReport::Formatting
  def format_duration(seconds)
    "%.2fs" % seconds
  end
end
