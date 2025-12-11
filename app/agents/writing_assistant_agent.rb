class WritingAssistantAgent < ApplicationAgent
  # Enable context persistence for tracking prompts and generations
  has_context

  generate_with :openai,
    model: "gpt-4o",
    stream: true,
    instructions: "You are an expert writing assistant helping users create and improve their content for cards, comments, and other text in Fizzy."

  on_stream :broadcast_chunk
  on_stream_close :broadcast_complete

  def improve
    setup_content_params
    @task = "improve the writing quality, clarity, and engagement"
    setup_context_and_prompt
  end

  def summarize
    setup_content_params
    @max_words = params[:max_words]
    @task = "create a concise summary"
    setup_context_and_prompt
  end

  def expand
    setup_content_params
    @target_length = params[:target_length]
    @areas_to_expand = params[:areas_to_expand]
    @task = "expand and elaborate on the content"
    setup_context_and_prompt
  end

  def adjust_tone
    setup_content_params
    @tone = params[:tone]
    @task = "adjust the tone to be #{@tone || 'more professional'}"
    setup_context_and_prompt
  end

  private

  def setup_content_params
    @content = params[:content]
    @selection = params[:selection]
    @full_content = params[:full_content]
    @context = params[:context]
    @has_selection = @selection.present?
  end

  # Sets up context persistence and triggers prompt rendering
  def setup_context_and_prompt
    # Create a new context, optionally associated with a contextable record (Card, Comment, etc.)
    # Store the input parameters in context options for full audit trail
    create_context(
      contextable: params[:contextable],
      input_params: context_input_params
    )

    # The prompt method will render the action template (e.g., improve.text.erb)
    # which contains the full user message. The after_prompt callback will
    # capture the rendered content for persistence.
    prompt
  end

  # Captures the relevant input parameters for context storage
  # These params are used to rehydrate the view when rendering the context as a prompt
  def context_input_params
    {
      task: @task,
      content: @content,
      selection: @selection,
      full_content: @full_content,
      context: @context,
      has_selection: @has_selection,
      tone: @tone,
      max_words: @max_words,
      target_length: @target_length,
      areas_to_expand: @areas_to_expand
    }.compact
  end

  def broadcast_chunk(chunk)
    return unless chunk.delta
    return unless params[:stream_id]

    Rails.logger.info "[Agent] Broadcasting chunk to stream_id: #{params[:stream_id]}, chunk length: #{chunk.delta.length}"
    ActionCable.server.broadcast(params[:stream_id], { content: chunk.delta })
  end

  def broadcast_complete(chunk)
    return unless params[:stream_id]

    Rails.logger.info "[Agent] Broadcasting completion to stream_id: #{params[:stream_id]}"
    ActionCable.server.broadcast(params[:stream_id], { done: true })
  end
end
