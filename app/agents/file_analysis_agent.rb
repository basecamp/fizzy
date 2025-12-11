class FileAnalysisAgent < ApplicationAgent
  # Enable context persistence for tracking prompts and generations
  has_context

  # Use GPT-4o for vision capabilities
  generate_with :openai,
    model: "gpt-4o",
    stream: true,
    instructions: "You are an expert file and image analyzer. Provide detailed, accurate analysis of the content provided."

  on_stream :broadcast_chunk
  on_stream_close :broadcast_complete

  before_action :set_multimodal_content

  # Analyze images or documents
  def analyze
    @message = params[:message] || "Analyze this content and describe what you see"
    @output_schema = params[:output_schema]

    create_context(
      contextable: params[:contextable],
      input_params: { message: @message, has_image: @image_data.present?, has_file: @file_data.present? }
    )

    prompt(
      message: @message,
      image_data: @image_data,
      file_data: @file_data,
      output_schema: @output_schema
    )
  end

  # Extract text from an image (OCR)
  def extract_text
    @message = "Extract all text from this image. Return only the extracted text, maintaining the original formatting as much as possible."

    create_context(
      contextable: params[:contextable],
      input_params: { action: "extract_text", has_image: @image_data.present? }
    )

    prompt(
      message: @message,
      image_data: @image_data
    )
  end

  # Describe an image in detail
  def describe_image
    @message = "Describe this image in detail. Include relevant information about the content, context, and any text visible."

    create_context(
      contextable: params[:contextable],
      input_params: { action: "describe_image", has_image: @image_data.present? }
    )

    prompt(
      message: @message,
      image_data: @image_data
    )
  end

  private

  def set_multimodal_content
    if params[:file].present?
      blob = params[:file]
      content_type = blob.content_type
      data = blob.download

      if content_type.start_with?("image/")
        @image_data = "data:#{content_type};base64,#{Base64.strict_encode64(data)}"
      else
        @file_data = "data:#{content_type};base64,#{Base64.strict_encode64(data)}"
      end
    elsif params[:image_url].present?
      @image_data = params[:image_url]
    end
  end

  def broadcast_chunk(chunk)
    return unless chunk.delta
    return unless params[:stream_id]

    Rails.logger.info "[FileAnalysisAgent] Broadcasting chunk to stream_id: #{params[:stream_id]}"
    ActionCable.server.broadcast(params[:stream_id], { content: chunk.delta })
  end

  def broadcast_complete(chunk)
    return unless params[:stream_id]

    Rails.logger.info "[FileAnalysisAgent] Broadcasting completion to stream_id: #{params[:stream_id]}"
    ActionCable.server.broadcast(params[:stream_id], { done: true })
  end
end
