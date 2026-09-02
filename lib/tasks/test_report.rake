namespace :test do
  desc "Run the test suite and write a dated report (Markdown + self-contained HTML) to the Obsidian vault"
  task :report do
    require_relative "support/test_report/report"

    TestReport.new.run
  end
end
