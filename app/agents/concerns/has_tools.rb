# frozen_string_literal: true

# HasTools provides a DSL for defining and loading tool schemas in ActiveAgent agents.
#
# This concern enables declarative tool registration with automatic schema loading
# from JSON view templates or inline definitions.
#
# @example Auto-discover tools from views
#   class MyAgent < ApplicationAgent
#     include HasTools
#     has_tools  # Discovers all tools from app/views/my_agent/tools/*.json.erb
#   end
#
# @example Explicit tool list
#   class MyAgent < ApplicationAgent
#     include HasTools
#     has_tools :search, :fetch, :analyze
#   end
#
# @example Inline tool definition
#   class MyAgent < ApplicationAgent
#     include HasTools
#     tool :get_weather do
#       description "Get current weather for a location"
#       parameter :location, type: :string, required: true, description: "City name"
#       parameter :units, type: :string, enum: %w[celsius fahrenheit], default: "celsius"
#     end
#   end
#
# @example Mixed approach
#   class MyAgent < ApplicationAgent
#     include HasTools
#     has_tools :navigate, :click  # Load from templates
#     tool :custom_action do       # Define inline
#       description "A custom action"
#       parameter :input, type: :string, required: true
#     end
#   end
module HasTools
  extend ActiveSupport::Concern

  included do
    class_attribute :_tool_names, default: []
    class_attribute :_inline_tools, default: {}
    class_attribute :_tools_auto_discover, default: false
  end

  class_methods do
    # Declares which tools this agent uses.
    #
    # Without arguments, enables auto-discovery of tools from view templates.
    # With arguments, explicitly lists tools to load from templates.
    #
    # @param tool_names [Array<Symbol, String>] explicit list of tools to load
    # @return [void]
    #
    # @example Auto-discover
    #   has_tools
    #
    # @example Explicit list
    #   has_tools :navigate, :click, :fill_form
    def has_tools(*tool_names)
      if tool_names.empty?
        self._tools_auto_discover = true
      else
        self._tool_names = tool_names.map(&:to_sym)
      end
    end

    # Defines a tool inline using a DSL block.
    #
    # The tool name should match a method in the agent class that will be
    # called when the LLM invokes this tool.
    #
    # @param name [Symbol, String] tool name (must match an instance method)
    # @yield block for defining tool schema using ToolBuilder DSL
    # @return [void]
    #
    # @example
    #   tool :search do
    #     description "Search for documents"
    #     parameter :query, type: :string, required: true
    #     parameter :limit, type: :integer, default: 10
    #   end
    def tool(name, &block)
      builder = ToolBuilder.new(name)
      builder.instance_eval(&block) if block_given?
      self._inline_tools = _inline_tools.merge(name.to_sym => builder.to_schema)
    end
  end

  # Returns all tool schemas for this agent.
  #
  # Combines tools from:
  # 1. Auto-discovered JSON templates (if has_tools called without args)
  # 2. Explicitly listed tools (if has_tools called with args)
  # 3. Inline tool definitions (from tool blocks)
  #
  # @return [Array<Hash>] array of tool schemas in OpenAI format
  def tools
    @_tools_cache ||= begin
      schemas = []

      # Load from templates
      if _tools_auto_discover
        schemas.concat(discover_tool_templates)
      elsif _tool_names.any?
        schemas.concat(_tool_names.map { |name| load_tool_schema(name) })
      end

      # Add inline tools
      schemas.concat(_inline_tools.values)

      schemas
    end
  end

  # Reloads tools, clearing any cached schemas.
  #
  # Useful when tool templates may have changed during development.
  #
  # @return [Array<Hash>] freshly loaded tool schemas
  def reload_tools!
    @_tools_cache = nil
    tools
  end

  private

  # Discovers tool templates from the agent's views directory.
  #
  # Looks for JSON templates in:
  # - app/views/{agent_name}/tools/*.json.erb
  # - app/views/agents/{agent_without_suffix}/tools/*.json.erb
  #
  # @return [Array<Hash>] discovered tool schemas
  def discover_tool_templates
    tool_schemas = []
    tools_path = Rails.root.join("app", "views", agent_name, "tools")

    if tools_path.exist?
      tools_path.glob("*.json.erb").each do |template_path|
        tool_name = template_path.basename(".json.erb").to_s
        tool_schemas << load_tool_schema(tool_name)
      end
    end

    # Also check nested structure: app/views/agents/{name}/tools/
    nested_path = Rails.root.join("app", "views", "agents", agent_name.delete_suffix("_agent"), "tools")
    if nested_path.exist?
      nested_path.glob("*.json.erb").each do |template_path|
        tool_name = template_path.basename(".json.erb").to_s
        # Avoid duplicates
        next if tool_schemas.any? { |t| t[:name] == tool_name }
        tool_schemas << load_tool_schema(tool_name)
      end
    end

    tool_schemas
  end

  # Loads a single tool schema from its JSON view template.
  #
  # @param tool_name [Symbol, String] name of the tool
  # @return [Hash] tool schema with symbolized keys
  # @raise [ActionView::MissingTemplate] if template not found
  # @raise [JSON::ParserError] if template produces invalid JSON
  def load_tool_schema(tool_name)
    template_path = "tools/#{tool_name}"

    json_content = render_to_string(
      template: "#{agent_name}/#{template_path}",
      formats: [:json],
      layout: false
    )

    JSON.parse(json_content, symbolize_names: true)
  rescue ActionView::MissingTemplate => e
    Rails.logger.error "[#{self.class.name}] Missing tool template: #{template_path}"
    raise e
  rescue JSON::ParserError => e
    Rails.logger.error "[#{self.class.name}] Invalid JSON in tool template: #{template_path}"
    raise e
  end

  # DSL builder for inline tool definitions.
  #
  # Provides a clean API for defining tool schemas programmatically:
  #
  #   tool :my_tool do
  #     description "Does something useful"
  #     parameter :input, type: :string, required: true
  #   end
  class ToolBuilder
    def initialize(name)
      @name = name.to_s
      @description = ""
      @parameters = {}
      @required = []
    end

    # Sets the tool description.
    #
    # @param text [String] human-readable description of what the tool does
    # @return [void]
    def description(text)
      @description = text
    end

    # Defines a parameter for the tool.
    #
    # @param name [Symbol, String] parameter name
    # @param type [Symbol, String] JSON Schema type (:string, :integer, :boolean, :array, :object)
    # @param required [Boolean] whether this parameter is required (default: false)
    # @param description [String] parameter description
    # @param enum [Array] allowed values (for string type)
    # @param items [Hash] item schema (for array type)
    # @param properties [Hash] nested properties (for object type)
    # @param default [Object] default value
    # @return [void]
    #
    # @example Simple string parameter
    #   parameter :query, type: :string, required: true
    #
    # @example Enum parameter
    #   parameter :format, type: :string, enum: %w[json xml csv]
    #
    # @example Array parameter
    #   parameter :tags, type: :array, items: { type: :string }
    def parameter(name, type:, required: false, description: nil, enum: nil, items: nil, properties: nil, default: nil)
      param_schema = { type: type.to_s }
      param_schema[:description] = description if description
      param_schema[:enum] = enum if enum
      param_schema[:items] = items if items
      param_schema[:properties] = properties if properties
      param_schema[:default] = default if default

      @parameters[name.to_s] = param_schema
      @required << name.to_s if required
    end

    # Converts the builder state to an OpenAI-compatible tool schema.
    #
    # @return [Hash] tool schema
    def to_schema
      {
        type: "function",
        name: @name,
        description: @description,
        parameters: {
          type: "object",
          properties: @parameters,
          required: @required
        }.compact
      }
    end
  end
end
