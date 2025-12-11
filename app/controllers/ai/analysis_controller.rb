module AI
  class AnalysisController < BaseController
    def analyze
      stream_id = "file_analysis_#{SecureRandom.hex(8)}"

      agent = FileAnalysisAgent.with(
        message: params[:message],
        file: params[:file],
        image_url: params[:image_url],
        output_schema: params[:output_schema],
        stream_id: stream_id
      ).analyze

      if params[:stream]
        render_streaming(agent, stream_id: stream_id)
      else
        render_generation(agent)
      end
    end

    def extract_text
      stream_id = "file_analysis_#{SecureRandom.hex(8)}"

      agent = FileAnalysisAgent.with(
        file: params[:file],
        image_url: params[:image_url],
        stream_id: stream_id
      ).extract_text

      if params[:stream]
        render_streaming(agent, stream_id: stream_id)
      else
        render_generation(agent)
      end
    end

    def describe_image
      stream_id = "file_analysis_#{SecureRandom.hex(8)}"

      agent = FileAnalysisAgent.with(
        file: params[:file],
        image_url: params[:image_url],
        stream_id: stream_id
      ).describe_image

      if params[:stream]
        render_streaming(agent, stream_id: stream_id)
      else
        render_generation(agent)
      end
    end
  end
end
