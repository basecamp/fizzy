# SolidAgent provides database-backed prompt context management for agents.
#
# This concern adds the `has_context` class method which configures an agent
# to persist its prompt context, messages, and generation results to the database.
#
# @example Basic usage in an agent
#   class WritingAssistantAgent < ApplicationAgent
#     has_context
#
#     def improve
#       prompt "Please improve the following text:", message: params[:content]
#     end
#   end
#
# @example With custom model classes
#   class WritingAssistantAgent < ApplicationAgent
#     has_context context_class: "Conversation",
#                 message_class: "ConversationMessage",
#                 generation_class: "ConversationGeneration"
#   end
#
# @example Using context in an agent action
#   class ChatAgent < ApplicationAgent
#     has_context  # auto_save: true by default - automatically persists generations
#
#     def chat
#       # Load or create context
#       load_context(contextable: params[:user])
#
#       # Add the user's message
#       context.add_user_message(params[:message])
#
#       # Set up the prompt with context history
#       prompt messages: context.messages.map(&:to_message_hash)
#     end
#   end
#
# @example Accessing persisted response after generation
#   response = ChatAgent.with(user: current_user, message: "Hello").chat.generate_now
#   # The generation is automatically persisted to AgentContext/AgentGeneration
#
module SolidAgent
  extend ActiveSupport::Concern

  included do
    # Class-level configuration for context persistence
    class_attribute :context_config, default: {}

    # Instance-level context and response accessors
    attr_accessor :context, :generation_response
  end

  class_methods do
    # Configures database-backed context persistence for this agent.
    #
    # @param context_class [String, Class] The model class for storing context (default: "AgentContext")
    # @param message_class [String, Class] The model class for storing messages (default: "AgentMessage")
    # @param generation_class [String, Class] The model class for storing generations (default: "AgentGeneration")
    # @param auto_save [Boolean] Automatically save generation results (default: true)
    #
    # @example Basic configuration
    #   has_context
    #
    # @example Custom model classes
    #   has_context context_class: "Conversation",
    #               message_class: "ConversationMessage",
    #               generation_class: "ConversationGeneration"
    #
    # @example Disable auto-save
    #   has_context auto_save: false
    #
    def has_context(context_class: "AgentContext",
                    message_class: "AgentMessage",
                    generation_class: "AgentGeneration",
                    auto_save: true)
      self.context_config = {
        context_class: context_class,
        message_class: message_class,
        generation_class: generation_class,
        auto_save: auto_save
      }

      # Add callbacks to persist prompt context and generation results if auto_save is enabled
      if auto_save
        after_prompt :persist_prompt_to_context
        around_generation :capture_and_persist_generation
      end
    end
  end

  # Returns the configured context model class
  def context_class
    @context_class ||= context_config[:context_class].to_s.constantize
  end

  # Returns the configured message model class
  def message_class
    @message_class ||= context_config[:message_class].to_s.constantize
  end

  # Returns the configured generation model class
  def generation_class
    @generation_class ||= context_config[:generation_class].to_s.constantize
  end

  # Loads or creates a context for this agent.
  #
  # @param contextable [ActiveRecord::Base, nil] Optional record to associate context with
  # @param context_id [Integer, nil] Optional existing context ID to load
  # @param options [Hash] Additional options to merge into context
  # @return [AgentContext] The loaded or created context
  #
  # @example Load context for a specific record
  #   load_context(contextable: current_user)
  #
  # @example Load existing context by ID
  #   load_context(context_id: params[:context_id])
  #
  # @example Create new context with options
  #   load_context(options: { model: "gpt-4" })
  #
  def load_context(contextable: nil, context_id: nil, **options)
    @context = if context_id
      context_class.find(context_id)
    elsif contextable
      context_class.find_or_create_by!(
        contextable: contextable,
        agent_name: self.class.name,
        action_name: action_name
      ) do |ctx|
        ctx.instructions = prompt_options[:instructions]
        ctx.options = options
        ctx.trace_id = prompt_options[:trace_id]
      end
    else
      context_class.create!(
        agent_name: self.class.name,
        action_name: action_name,
        instructions: prompt_options[:instructions],
        options: options,
        trace_id: prompt_options[:trace_id]
      )
    end
  end

  # Creates a new context (always creates, never finds existing)
  #
  # @param contextable [ActiveRecord::Base, nil] Optional record to associate context with
  # @param options [Hash] Additional options to merge into context
  # @return [AgentContext] The created context
  #
  def create_context(contextable: nil, **options)
    @context = context_class.create!(
      contextable: contextable,
      agent_name: self.class.name,
      action_name: action_name,
      instructions: prompt_options[:instructions],
      options: options,
      trace_id: prompt_options[:trace_id]
    )
  end

  # Adds a message to the current context
  #
  # @param role [String] Message role (user, assistant, system, tool)
  # @param content [String] Message content
  # @param attributes [Hash] Additional message attributes
  # @return [AgentMessage] The created message
  #
  def add_message(role:, content:, **attributes)
    ensure_context!
    context.messages.create!(role: role, content: content, **attributes)
  end

  # Convenience method to add a user message
  def add_user_message(content, **attributes)
    add_message(role: "user", content: content, **attributes)
  end

  # Convenience method to add an assistant message
  def add_assistant_message(content, **attributes)
    add_message(role: "assistant", content: content, **attributes)
  end

  # Returns messages from context formatted for prompt
  #
  # @return [Array<Hash>] Messages formatted for ActiveAgent prompt
  #
  def context_messages
    return [] unless context
    context.messages.map(&:to_message_hash)
  end

  # Sets up the prompt with context messages
  #
  # This is a convenience method that loads context messages into the prompt.
  # Call this in your agent action to include conversation history.
  #
  # @example
  #   def chat
  #     load_context(contextable: params[:user])
  #     with_context_messages
  #     prompt params[:message]
  #   end
  #
  def with_context_messages
    prompt messages: context_messages if context_messages.any?
  end

  private

  # After prompt callback - persists the rendered prompt message to context
  # This captures the fully rendered action template content from prompt_options[:messages]
  def persist_prompt_to_context
    return unless context

    # The prompt_options[:messages] contains the rendered action template content
    if prompt_options[:messages].present?
      rendered_message = prompt_options[:messages].last
      content = rendered_message.is_a?(Hash) ? rendered_message[:content] : rendered_message.to_s
      add_user_message(content) if content.present?
    end
  end

  # Around callback to capture the response and persist to context
  # This is necessary because after_generation doesn't have access to the response
  def capture_and_persist_generation
    self.generation_response = yield
    persist_generation_to_context
    generation_response
  end

  # Persists the generation response to context
  def persist_generation_to_context
    return unless context && generation_response

    begin
      # For streaming responses, raw_response may be nil but we still have the message
      # Check if we have a valid response with content
      if generation_response.respond_to?(:message) && generation_response.message&.content.present?
        context.record_generation!(generation_response)
        Rails.logger.info "[SolidAgent] Persisted generation to context #{context.id}"
      else
        Rails.logger.warn "[SolidAgent] Skipping persistence - no message content in response"
      end
    rescue => e
      Rails.logger.error "[SolidAgent] Failed to persist generation: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
    end
  end

  # Ensures a context exists, raising an error if not
  def ensure_context!
    raise "No context loaded. Call load_context or create_context first." unless context
  end
end
