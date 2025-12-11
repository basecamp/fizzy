class AssistantStreamChannel < ApplicationCable::Channel
  def subscribed
    Rails.logger.info "[Channel] Client subscribed to stream_id: #{params[:stream_id]}"
    stream_from params[:stream_id] if params[:stream_id]
  end

  def unsubscribed
    Rails.logger.info "[Channel] Client unsubscribed from stream"
    stop_all_streams
  end
end
