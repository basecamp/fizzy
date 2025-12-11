# AgentGeneration stores generation results/responses from AI providers.
#
# This model captures the full response data from a generation, including
# token usage, provider metadata, and raw request/response for debugging.
#
# @example Accessing generation data
#   generation = context.latest_generation
#   generation.total_tokens  #=> 250
#   generation.model         #=> "gpt-4o-mini"
#   generation.response_message.content #=> "Here's the improved text..."
#
# @example Calculating costs (example)
#   generation.input_tokens * 0.00015 + generation.output_tokens * 0.0006
#
class AgentGeneration < ApplicationRecord
  # Associations
  belongs_to :agent_context
  belongs_to :response_message, class_name: "AgentMessage", optional: true

  # Validations
  validates :status, inclusion: { in: %w[pending streaming completed failed] }

  # Scopes
  scope :completed, -> { where(status: "completed") }
  scope :failed, -> { where(status: "failed") }
  scope :recent, -> { order(created_at: :desc) }

  # Returns a Usage-like object for compatibility with ActiveAgent
  def usage
    @usage ||= AgentUsage.new(
      input_tokens: input_tokens,
      output_tokens: output_tokens,
      total_tokens: total_tokens,
      cached_tokens: cached_tokens,
      reasoning_tokens: reasoning_tokens,
      duration_ms: duration_ms,
      provider_details: provider_details
    )
  end

  # Check if generation was successful
  def success?
    status == "completed"
  end

  # Check if generation failed
  def failed?
    status == "failed"
  end

  # Returns the response content (convenience method)
  def content
    response_message&.content
  end

  # Parse JSON from response (delegates to message)
  def parsed_json(**options)
    response_message&.parsed_json(**options)
  end

  # Simple struct to hold usage data, compatible with ActiveAgent::Providers::Common::Usage
  class AgentUsage
    attr_reader :input_tokens, :output_tokens, :total_tokens,
                :cached_tokens, :reasoning_tokens, :duration_ms, :provider_details

    def initialize(input_tokens: 0, output_tokens: 0, total_tokens: 0,
                   cached_tokens: nil, reasoning_tokens: nil, duration_ms: nil,
                   provider_details: {})
      @input_tokens = input_tokens
      @output_tokens = output_tokens
      @total_tokens = total_tokens
      @cached_tokens = cached_tokens
      @reasoning_tokens = reasoning_tokens
      @duration_ms = duration_ms
      @provider_details = provider_details || {}
    end

    def to_h
      {
        input_tokens: input_tokens,
        output_tokens: output_tokens,
        total_tokens: total_tokens,
        cached_tokens: cached_tokens,
        reasoning_tokens: reasoning_tokens,
        duration_ms: duration_ms,
        provider_details: provider_details
      }.compact
    end

    # Support addition for summing multiple generations
    def +(other)
      return self unless other

      self.class.new(
        input_tokens: input_tokens + (other.input_tokens || 0),
        output_tokens: output_tokens + (other.output_tokens || 0),
        total_tokens: total_tokens + (other.total_tokens || 0),
        cached_tokens: sum_optional(cached_tokens, other.cached_tokens),
        reasoning_tokens: sum_optional(reasoning_tokens, other.reasoning_tokens)
      )
    end

    private

    def sum_optional(a, b)
      return nil if a.nil? && b.nil?
      (a || 0) + (b || 0)
    end
  end
end
