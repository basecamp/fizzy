module AI
  class WritingController < BaseController
    def improve
      stream_id = "writing_assistant_#{SecureRandom.hex(8)}"

      agent = WritingAssistantAgent.with(
        content: params[:content] || params[:text],
        selection: params[:selection],
        full_content: params[:full_content],
        context: params[:context],
        stream_id: stream_id
      ).improve

      if params[:stream]
        render_streaming(agent, stream_id: stream_id)
      else
        render_generation(agent)
      end
    end

    def summarize
      stream_id = "writing_assistant_#{SecureRandom.hex(8)}"

      agent = WritingAssistantAgent.with(
        content: params[:content] || params[:text],
        max_words: params[:max_words] || 150,
        stream_id: stream_id
      ).summarize

      if params[:stream]
        render_streaming(agent, stream_id: stream_id)
      else
        render_generation(agent)
      end
    end

    def expand
      stream_id = "writing_assistant_#{SecureRandom.hex(8)}"

      agent = WritingAssistantAgent.with(
        content: params[:content] || params[:text],
        target_length: params[:target_length],
        areas_to_expand: params[:areas_to_expand],
        stream_id: stream_id
      ).expand

      if params[:stream]
        render_streaming(agent, stream_id: stream_id)
      else
        render_generation(agent)
      end
    end

    def adjust_tone
      stream_id = "writing_assistant_#{SecureRandom.hex(8)}"

      agent = WritingAssistantAgent.with(
        content: params[:content] || params[:text],
        tone: params[:tone],
        stream_id: stream_id
      ).adjust_tone

      if params[:stream]
        render_streaming(agent, stream_id: stream_id)
      else
        render_generation(agent)
      end
    end

    # Unified streaming endpoint for all writing actions
    def stream
      action = params[:action_type]
      stream_id = "writing_assistant_#{SecureRandom.hex(8)}"

      selection = params[:selection]
      full_content = params[:full_content]
      content = selection.present? ? selection : (params[:content] || full_content)

      agent = WritingAssistantAgent.with(
        content: content,
        selection: selection,
        full_content: full_content,
        context: params[:context],
        tone: params[:tone],
        max_words: params[:max_words] || 150,
        target_length: params[:target_length],
        areas_to_expand: params[:areas_to_expand],
        stream_id: stream_id
      )

      case action
      when "improve"
        agent.improve.generate_later
      when "summarize"
        agent.summarize.generate_later
      when "expand"
        agent.expand.generate_later
      when "adjust_tone"
        agent.adjust_tone.generate_later
      else
        return render json: { error: "Unknown action: #{action}" }, status: :unprocessable_entity
      end

      render json: { stream_id: stream_id }
    rescue => e
      Rails.logger.error "[WritingController] Stream error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end
end
