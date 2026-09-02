# Minitest::Reporters reporter that dumps a machine-readable summary of a test run
# (counts, timings and failure details) as JSON. Used by `bin/rails test:report`
# to build a human-readable report without having to parse console output.
class TestReportJsonReporter < Minitest::Reporters::BaseReporter
  def initialize(path)
    super()
    @path = path
  end

  def report
    super
    File.write(@path, JSON.generate(summary))
  end

  private
    def summary
      {
        count: count,
        assertions: assertions,
        failures: failures,
        errors: errors,
        skips: skips,
        total_time: total_time,
        tests: tests.map { |test| test_summary(test) }
      }
    end

    def test_summary(test)
      {
        name: test.name,
        klass: test.klass,
        file: test_file(test),
        time: test.time,
        result: result(test).to_s,
        failure_message: test.failure&.message
      }
    end

    def test_file(test)
      test.klass.constantize.instance_method(test.name).source_location&.first
    rescue NameError
      nil
    end
end
