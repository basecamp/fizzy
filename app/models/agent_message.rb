# AgentMessage stores individual messages in an agent conversation.
#
# This model mirrors the ActiveAgent::Providers::Common::Messages interface,
# providing a Rails-native way to persist conversation history.
#
# @example Creating messages
#   message = AgentMessage.create!(
#     agent_context: context,
#     role: "user",
#     content: "Please help me improve this text."
#   )
#
# @example Converting to ActiveAgent format
#   message.to_message_hash
#   #=> { role: "user", content: "Please help me improve this text." }
#
class AgentMessage < ApplicationRecord
  # Associations
  belongs_to :agent_context

  # Validations
  validates :role, presence: true, inclusion: { in: %w[system user assistant tool] }
  validates :content, presence: true, unless: :tool_message?

  # Scopes
  scope :system_messages, -> { where(role: "system") }
  scope :user_messages, -> { where(role: "user") }
  scope :assistant_messages, -> { where(role: "assistant") }
  scope :tool_messages, -> { where(role: "tool") }
  scope :ordered, -> { order(position: :asc) }

  # Callbacks
  before_create :set_position

  # Check if this is a tool message
  def tool_message?
    role == "tool"
  end

  # Check if this is a system message
  def system_message?
    role == "system"
  end

  # Check if this is a user message
  def user_message?
    role == "user"
  end

  # Check if this is an assistant message
  def assistant_message?
    role == "assistant"
  end

  # Converts to a hash compatible with ActiveAgent message format
  def to_message_hash
    hash = { role: role, content: content }
    hash[:name] = name if name.present?
    hash[:tool_call_id] = tool_call_id if tool_call_id.present?
    hash[:function_name] = function_name if function_name.present?

    # Include content parts if present (for multimodal messages)
    if content_parts.present? && content_parts.any?
      hash[:content_parts] = content_parts
    end

    hash
  end

  # Creates an AgentMessage from an ActiveAgent message object or hash
  def self.from_active_agent_message(message, context:, position: nil)
    attributes = case message
    when Hash
      message.symbolize_keys.slice(:role, :content, :name, :tool_call_id, :function_name, :content_parts)
    when String
      { role: "user", content: message }
    else
      # Assume it's an ActiveAgent message object
      {
        role: message.role,
        content: message.content,
        name: message.try(:name),
        tool_call_id: message.try(:tool_call_id),
        function_name: message.try(:function_name)
      }
    end

    attributes[:agent_context] = context
    attributes[:position] = position if position

    create!(attributes.compact)
  end

  # Extracts and parses JSON from assistant message content
  # (mirrors ActiveAgent::Providers::Common::Messages::Assistant#parsed_json)
  def parsed_json(symbolize_names: true, normalize_names: :underscore)
    return nil unless assistant_message? && content.present?

    start_char = [ content.index("{"), content.index("[") ].compact.min
    end_char = [ content.rindex("}"), content.rindex("]") ].compact.max
    content_stripped = content[start_char..end_char] if start_char && end_char
    return nil unless content_stripped

    parsed = JSON.parse(content_stripped)

    transform_hash = ->(hash) do
      next if hash.nil?
      hash = hash.deep_transform_keys(&normalize_names) if normalize_names
      hash = hash.deep_symbolize_keys if symbolize_names
      hash
    end

    case parsed
    when Hash then transform_hash.call(parsed)
    when Array then parsed.map { |item| item.is_a?(Hash) ? transform_hash.call(item) : item }
    else parsed
    end
  rescue JSON::ParserError
    nil
  end

  alias_method :json_object, :parsed_json

  private

  def set_position
    self.position ||= (agent_context.messages.maximum(:position) || -1) + 1
  end
end
