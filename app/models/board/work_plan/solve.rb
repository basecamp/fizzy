require "json"
require "open3"
require "timeout"

module Board::WorkPlan
  class Solve
    class Error < StandardError; end
    class ExecutionError < Error; end
    class ParseError < Error; end

    DEFAULT_BINARY_PATH = Rails.root.join("vendor/bin/solverforge-board-planner").to_s

    Result = Struct.new(:status, :score, :elapsed_ms, :proposed_assignments, keyword_init: true) do
      def feasible?
        status == "feasible"
      end
    end

    def initialize(request:, planner_binary_path: DEFAULT_BINARY_PATH)
      @request = request
      @planner_binary_path = planner_binary_path.to_s
    end

    def call
      payload = request.respond_to?(:to_h) ? request.to_h : request
      output = run_solver(payload)
      parse_output(output)
    end

    private
      attr_reader :request, :planner_binary_path

      def run_solver(payload)
        command = [ planner_binary_path, "solve" ]
        stdin_data = JSON.generate(payload)
        timeout = request.respond_to?(:time_limit_seconds) ? request.time_limit_seconds : 30

        Timeout.timeout(timeout + 1) do
          stdout, stderr, status = Open3.capture3(*command, stdin_data: stdin_data)
          raise ExecutionError, stderr.presence || "Planner command failed" unless status.success?

          stdout
        end
      rescue Errno::ENOENT
        raise ExecutionError, "Solver binary is unavailable"
      rescue Timeout::Error
        raise ExecutionError, "Planner command timed out"
      end

      def parse_output(output)
        payload = JSON.parse(output, symbolize_names: true)
      rescue JSON::ParserError => error
        raise ParseError, error.message
      else
        Result.new(
          status: payload[:status].to_s,
          score: payload[:score].to_s,
          elapsed_ms: payload[:elapsed_ms].to_i,
          proposed_assignments: parse_assignments(payload[:proposed_assignments])
        )
      end

      def parse_assignments(raw_assignments)
        Array(raw_assignments).map do |assignment|
          {
            card_id: assignment[:card_id].to_s,
            assignee_id: assignment[:assignee_id].to_s
          }
        end
      end
  end
end
