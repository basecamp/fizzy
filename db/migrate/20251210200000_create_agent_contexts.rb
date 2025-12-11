class CreateAgentContexts < ActiveRecord::Migration[8.0]
  def change
    # AgentContext - stores the overall context/conversation for agent generations
    create_table :agent_contexts do |t|
      # Polymorphic association to allow any record to have agent context
      t.references :contextable, polymorphic: true, index: true

      # Agent configuration
      t.string :agent_name, null: false
      t.string :action_name

      # System instructions for this context
      t.text :instructions

      # Generation options (model, temperature, etc.) stored as JSON
      t.json :options, default: {}

      # Status tracking
      t.string :status, default: "pending"

      # Trace ID for debugging/logging
      t.string :trace_id, index: true

      t.timestamps
    end

    # AgentMessage - stores individual messages in a conversation
    create_table :agent_messages do |t|
      t.references :agent_context, null: false, foreign_key: true, index: true

      # Message role: system, user, assistant, tool
      t.string :role, null: false

      # Message content
      t.text :content

      # Optional name for the message sender
      t.string :name

      # For tool messages: tool call ID and function name
      t.string :tool_call_id
      t.string :function_name

      # Additional content parts (images, documents) stored as JSON
      t.json :content_parts, default: []

      # Position in conversation
      t.integer :position, default: 0

      t.timestamps
    end

    add_index :agent_messages, [ :agent_context_id, :position ]

    # AgentGeneration - stores generation results/responses
    create_table :agent_generations do |t|
      t.references :agent_context, null: false, foreign_key: true, index: true

      # The generated message (assistant response)
      t.references :response_message, foreign_key: { to_table: :agent_messages }

      # Provider response metadata
      t.string :provider_id        # Response ID from provider
      t.string :model              # Actual model used
      t.string :finish_reason      # stop, length, tool_calls, etc.

      # Token usage
      t.integer :input_tokens, default: 0
      t.integer :output_tokens, default: 0
      t.integer :total_tokens, default: 0
      t.integer :cached_tokens
      t.integer :reasoning_tokens

      # Duration in milliseconds
      t.integer :duration_ms

      # Raw request/response for debugging (stored as JSON)
      t.json :raw_request
      t.json :raw_response

      # Provider-specific details
      t.json :provider_details, default: {}

      # Status
      t.string :status, default: "completed"
      t.text :error_message

      t.timestamps
    end
  end
end
