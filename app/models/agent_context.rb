# AgentContext stores the overall context/conversation for agent generations.
#
# This model provides a "Rails way" of managing prompt context and generation
# history, mirroring ActiveAgent's ActionPrompt interface but persisted to the database.
#
# @example Creating a context for a card
#   context = AgentContext.create!(
#     contextable: card,
#     agent_name: "WritingAssistantAgent",
#     action_name: "improve",
#     instructions: "You are a helpful writing assistant."
#   )
#
# @example Adding messages to context
#   context.messages.create!(role: "user", content: "Please improve this text...")
#   context.messages.create!(role: "assistant", content: "Here's the improved version...")
#
# @example Accessing the latest generation
#   context.latest_generation.output_tokens #=> 150
#
class AgentContext < ApplicationRecord
  # Polymorphic association allows any model to have agent context
  belongs_to :contextable, polymorphic: true, optional: true

  # Messages in this conversation, ordered by position
  has_many :messages, -> { order(position: :asc) },
           class_name: "AgentMessage",
           dependent: :destroy

  # Generation results/responses
  has_many :generations,
           class_name: "AgentGeneration",
           dependent: :destroy

  # Validations
  validates :agent_name, presence: true
  validates :status, inclusion: { in: %w[pending processing completed failed] }

  # Scopes
  scope :pending, -> { where(status: "pending") }
  scope :completed, -> { where(status: "completed") }
  scope :failed, -> { where(status: "failed") }
  scope :for_agent, ->(name) { where(agent_name: name) }

  # Returns the latest generation for this context
  def latest_generation
    generations.order(created_at: :desc).first
  end

  # Returns all user messages
  def user_messages
    messages.where(role: "user")
  end

  # Returns all assistant messages
  def assistant_messages
    messages.where(role: "assistant")
  end

  # Adds a user message to the context
  def add_user_message(content, **attributes)
    messages.create!(role: "user", content: content, position: next_position, **attributes)
  end

  # Adds an assistant message to the context
  def add_assistant_message(content, **attributes)
    messages.create!(role: "assistant", content: content, position: next_position, **attributes)
  end

  # Adds a system message to the context
  def add_system_message(content, **attributes)
    messages.create!(role: "system", content: content, position: next_position, **attributes)
  end

  # Converts context to ActiveAgent-compatible prompt options hash
  def to_prompt_options
    {
      instructions: instructions,
      messages: messages.map(&:to_message_hash),
      **options.symbolize_keys
    }.compact
  end

  # Updates context from an ActiveAgent response
  def record_generation!(response)
    transaction do
      # Create the assistant message from the response
      response_message = if response.message
        add_assistant_message(
          response.message.content,
          name: response.message.try(:name)
        )
      end

      # Create the generation record
      generations.create!(
        response_message: response_message,
        provider_id: response.id,
        model: response.model,
        finish_reason: response.finish_reason,
        input_tokens: response.usage&.input_tokens || 0,
        output_tokens: response.usage&.output_tokens || 0,
        total_tokens: response.usage&.total_tokens || 0,
        cached_tokens: response.usage&.cached_tokens,
        reasoning_tokens: response.usage&.reasoning_tokens,
        duration_ms: response.usage&.duration_ms,
        raw_request: response.raw_request,
        raw_response: response.raw_response,
        provider_details: response.usage&.provider_details || {},
        status: "completed"
      )

      update!(status: "completed")
    end
  end

  # Records a failed generation
  def record_failure!(error)
    transaction do
      generations.create!(
        status: "failed",
        error_message: error.message
      )
      update!(status: "failed")
    end
  end

  private

  def next_position
    (messages.maximum(:position) || -1) + 1
  end
end
