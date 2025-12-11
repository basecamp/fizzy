module AI
  class ResearchController < BaseController
    def research
      stream_id = "research_#{SecureRandom.hex(8)}"

      agent = ResearchAgent.with(
        query: params[:query],
        topic: params[:topic],
        context: params[:context],
        depth: params[:depth] || "standard",
        stream_id: stream_id
      ).research

      if params[:stream]
        render_streaming(agent, stream_id: stream_id)
      else
        render_generation(agent)
      end
    end

    def suggest_topics
      stream_id = "research_#{SecureRandom.hex(8)}"

      agent = ResearchAgent.with(
        topic: params[:topic],
        context: params[:context],
        stream_id: stream_id
      ).suggest_topics

      if params[:stream]
        render_streaming(agent, stream_id: stream_id)
      else
        render_generation(agent)
      end
    end

    def break_down_task
      stream_id = "research_#{SecureRandom.hex(8)}"

      agent = ResearchAgent.with(
        task: params[:task],
        context: params[:context],
        stream_id: stream_id
      ).break_down_task

      if params[:stream]
        render_streaming(agent, stream_id: stream_id)
      else
        render_generation(agent)
      end
    end
  end
end
