# frozen_string_literal: true

# StreamsToolUpdates provides real-time UI feedback during tool execution.
#
# When an agent is processing and calls tools (which may take time), this concern
# broadcasts status updates to the client so users see what's happening rather than
# a frozen UI. This is especially important for long-running tools like web browsing.
#
# @example Basic usage
#   class MyAgent < ApplicationAgent
#     include HasTools
#     include StreamsToolUpdates
#
#     has_tools :search, :navigate
#
#     def research
#       prompt(tools: tools)
#     end
#   end
#
# @example With custom descriptions
#   class MyAgent < ApplicationAgent
#     include HasTools
#     include StreamsToolUpdates
#
#     tool_description :navigate, ->(args) { "Visiting #{args[:url]}..." }
#     tool_description :search, ->(args) { "Searching for '#{args[:query]}'..." }
#     tool_description :extract_text, "Reading page content..."
#   end
module StreamsToolUpdates
  extend ActiveSupport::Concern

  included do
    class_attribute :_tool_descriptions, default: {}
    class_attribute :_wrapped_tools, default: Set.new
  end

  class_methods do
    # Defines a human-readable description for a tool that will be shown in the UI.
    #
    # @param tool_name [Symbol, String] the tool method name
    # @param description [String, Proc] static string or proc that receives args
    #
    # @example Static description
    #   tool_description :extract_text, "Reading page content..."
    #
    # @example Dynamic description with args
    #   tool_description :navigate, ->(args) { "Visiting #{args[:url]}..." }
    def tool_description(tool_name, description)
      self._tool_descriptions = _tool_descriptions.merge(tool_name.to_sym => description)
      wrap_tool_method(tool_name)
    end

    # Wraps a tool method to broadcast status before execution
    #
    # @param tool_name [Symbol, String] the tool method name
    def wrap_tool_method(tool_name)
      tool_sym = tool_name.to_sym
      return if _wrapped_tools.include?(tool_sym)

      self._wrapped_tools = _wrapped_tools.dup.add(tool_sym)

      # Use prepend to wrap the method
      wrapper_module = Module.new do
        define_method(tool_sym) do |**kwargs|
          broadcast_tool_status(tool_sym, kwargs) if should_broadcast_tools?
          super(**kwargs)
        end
      end

      prepend wrapper_module
    end
  end

  private

  def should_broadcast_tools?
    params[:stream_id].present?
  end

  # Broadcasts a tool status update to the client
  #
  # @param tool_name [String, Symbol] the tool being executed
  # @param args [Hash] the arguments passed to the tool
  def broadcast_tool_status(tool_name, args = {})
    return unless params[:stream_id]

    description = tool_description_for(tool_name, args)

    Rails.logger.info "[#{self.class.name}] Tool status: #{description}"

    ActionCable.server.broadcast(
      params[:stream_id],
      {
        tool_status: {
          name: tool_name.to_s,
          description: description,
          timestamp: Time.current.iso8601
        }
      }
    )
  end

  # Gets the human-readable description for a tool
  #
  # @param tool_name [String, Symbol] the tool name
  # @param args [Hash] the arguments passed to the tool
  # @return [String] description to show in UI
  def tool_description_for(tool_name, args = {})
    custom = _tool_descriptions[tool_name.to_sym]

    if custom.is_a?(Proc)
      custom.call(args)
    elsif custom.is_a?(String)
      custom
    else
      default_tool_description(tool_name, args)
    end
  end

  # Generates a default description for common tool types
  #
  # @param tool_name [String, Symbol] the tool name
  # @param args [Hash] the arguments passed to the tool
  # @return [String] default description
  def default_tool_description(tool_name, args = {})
    case tool_name.to_s
    when "navigate"
      args[:url] ? "Visiting #{truncate_url(args[:url])}..." : "Navigating to page..."
    when "click"
      args[:text] ? "Clicking '#{args[:text]}'..." : "Clicking element..."
    when "fill_form"
      args[:field] ? "Filling in #{args[:field]}..." : "Filling form..."
    when "extract_text", "extract_main_content"
      "Reading page content..."
    when "extract_links"
      "Extracting links..."
    when "page_info"
      "Getting page info..."
    when "go_back"
      "Going back..."
    when "search", "web_search"
      args[:query] ? "Searching for '#{args[:query]}'..." : "Searching..."
    when "read", "read_file"
      args[:path] ? "Reading #{File.basename(args[:path])}..." : "Reading file..."
    when "write", "write_file"
      args[:path] ? "Writing #{File.basename(args[:path])}..." : "Writing file..."
    else
      "Performing #{tool_name.to_s.humanize.downcase}..."
    end
  end

  # Truncates a URL for display
  #
  # @param url [String] the URL to truncate
  # @param max_length [Integer] maximum length
  # @return [String] truncated URL
  def truncate_url(url, max_length: 50)
    return url if url.length <= max_length

    uri = URI.parse(url)
    host = uri.host || url[0..max_length]
    path = uri.path || ""

    if host.length > max_length
      "#{host[0..max_length]}..."
    elsif (host.length + path.length) > max_length
      remaining = max_length - host.length - 3
      "#{host}#{path[0..remaining]}..."
    else
      "#{host}#{path}"
    end
  rescue URI::InvalidURIError
    url.length > max_length ? "#{url[0..max_length]}..." : url
  end
end
