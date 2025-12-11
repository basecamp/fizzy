class ResearchAgent < ApplicationAgent
  # Enable context persistence for tracking prompts and generations
  has_context

  generate_with :openai,
    model: "gpt-4o",
    stream: true,
    instructions: "You are a research assistant helping users explore topics, gather information, and break down complex tasks."

  on_stream :broadcast_chunk
  on_stream_close :broadcast_complete

  # Research a topic and provide context
  def research
    @query = params[:query]
    @topic = params[:topic]
    @context = params[:context]
    @depth = params[:depth] || "standard"

    create_context(
      contextable: params[:contextable],
      input_params: { query: @query, topic: @topic, context: @context, depth: @depth }
    )

    prompt
  end

  # Generate related topics or questions
  def suggest_topics
    @topic = params[:topic]
    @context = params[:context]

    create_context(
      contextable: params[:contextable],
      input_params: { topic: @topic, context: @context }
    )

    prompt
  end

  # Break down a task into subtasks
  def break_down_task
    @task = params[:task]
    @context = params[:context]

    create_context(
      contextable: params[:contextable],
      input_params: { task: @task, context: @context }
    )

    prompt
  end

  private

  def broadcast_chunk(chunk)
    return unless chunk.delta
    return unless params[:stream_id]

    Rails.logger.info "[ResearchAgent] Broadcasting chunk to stream_id: #{params[:stream_id]}"
    ActionCable.server.broadcast(params[:stream_id], { content: chunk.delta })
  end

  def broadcast_complete(chunk)
    return unless params[:stream_id]

    Rails.logger.info "[ResearchAgent] Broadcasting completion to stream_id: #{params[:stream_id]}"
    ActionCable.server.broadcast(params[:stream_id], { done: true })
  end
end
